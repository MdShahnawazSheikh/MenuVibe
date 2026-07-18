import Foundation
import IOKit

/// A small, self-contained Apple SMC (System Management Controller) client.
///
/// Talks to the `AppleSMC` IOService directly via `IOConnectCallStructMethod` — no
/// private frameworks, no third-party dependency. This is the public IOKit surface the
/// SMC-reader projects (SMCKit, stats, iStat Menus-likes) all use.
///
/// Works on Intel and Apple Silicon. On Apple Silicon, CPU die temperature is exposed
/// through the per-core `Tp**` keys, which we read and average; fan RPM comes from
/// `F0Ac` on Macs that have fans (MacBook Air has none, so it degrades to `nil`).
/// Every failure path returns `nil` rather than a fabricated number.
final class SMCReader {

    // MARK: SMC data structures (must match the kernel's layout exactly)

    private typealias SMCBytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    private struct SMCVersion {
        var major: UInt8 = 0
        var minor: UInt8 = 0
        var build: UInt8 = 0
        var reserved: UInt8 = 0
        var release: UInt16 = 0
    }

    private struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    private struct SMCKeyInfoData {
        var dataSize: UInt32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    private struct SMCParamStruct {
        var key: UInt32 = 0
        var vers = SMCVersion()
        var pLimitData = SMCPLimitData()
        var keyInfo = SMCKeyInfoData()
        var padding: UInt16 = 0
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: SMCBytes = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                               0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private enum Selector: UInt8 {
        case readKey = 5
        case getKeyInfo = 9
    }
    private let kernelIndex: UInt32 = 2 // kSMCHandleYPCEvent

    private var connection: io_connect_t = 0

    // MARK: Lifecycle

    @discardableResult
    func open() -> Bool {
        guard connection == 0 else { return true }
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }
        return IOServiceOpen(service, mach_task_self_, 0, &connection) == kIOReturnSuccess
    }

    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    deinit { close() }

    // MARK: Public reads

    /// Average CPU temperature in °C across whatever per-core sensors are readable, or
    /// `nil` if none are (e.g. a Mac that doesn't surface them).
    func averageCPUTemperature() -> Double? {
        var sum = 0.0
        var count = 0
        for key in Self.cpuTempKeys {
            if let value = readTemperature(key), value > 5, value < 130 {
                sum += value
                count += 1
            }
        }
        return count > 0 ? sum / Double(count) : nil
    }

    /// Actual RPM of the primary fan, or `nil` on fanless Macs / when unavailable.
    func primaryFanRPM() -> Double? {
        guard let count = readUInt("FNum"), count > 0 else { return nil }
        return readFloatValue("F0Ac")
    }

    // MARK: Key decoding

    /// Read a temperature key, decoding whichever fixed-point/float type it advertises.
    private func readTemperature(_ key: String) -> Double? {
        guard let (type, data) = readKey(key) else { return nil }
        switch type {
        case "sp78": // signed 8.8 fixed point
            guard data.count >= 2 else { return nil }
            let raw = Int16(bitPattern: (UInt16(data[0]) << 8) | UInt16(data[1]))
            return Double(raw) / 256.0
        case "flt ":
            return Double(decodeFloat(data))
        default:
            return nil
        }
    }

    private func readFloatValue(_ key: String) -> Double? {
        guard let (type, data) = readKey(key) else { return nil }
        switch type {
        case "flt ":
            return Double(decodeFloat(data))
        case "fpe2": // unsigned 14.2 fixed point
            guard data.count >= 2 else { return nil }
            let raw = (UInt16(data[0]) << 8) | UInt16(data[1])
            return Double(raw) / 4.0
        default:
            return nil
        }
    }

    private func readUInt(_ key: String) -> Int? {
        guard let (_, data) = readKey(key), !data.isEmpty else { return nil }
        var value = 0
        for byte in data { value = (value << 8) | Int(byte) }
        return value
    }

    private func decodeFloat(_ data: [UInt8]) -> Float {
        guard data.count >= 4 else { return 0 }
        let bits = UInt32(data[0]) | (UInt32(data[1]) << 8) | (UInt32(data[2]) << 16) | (UInt32(data[3]) << 24)
        return Float(bitPattern: bits)
    }

    // MARK: Low-level SMC call

    /// Returns the four-char data type and the raw bytes for a key, or `nil`.
    private func readKey(_ key: String) -> (type: String, data: [UInt8])? {
        guard connection != 0, let fourCC = Self.fourCharCode(key) else { return nil }

        // 1. Key info (data size + type).
        var infoInput = SMCParamStruct()
        infoInput.key = fourCC
        infoInput.data8 = Selector.getKeyInfo.rawValue
        guard let infoOutput = call(infoInput) else { return nil }
        let size = infoOutput.keyInfo.dataSize
        guard size > 0, size <= 32 else { return nil }

        // 2. Read the value.
        var readInput = SMCParamStruct()
        readInput.key = fourCC
        readInput.keyInfo.dataSize = size
        readInput.data8 = Selector.readKey.rawValue
        guard let readOutput = call(readInput), readOutput.result == 0 else { return nil }

        let bytes = Self.bytesArray(readOutput.bytes, count: Int(size))
        let typeString = Self.typeString(readOutput.keyInfo.dataType)
        return (typeString, bytes)
    }

    private func call(_ input: SMCParamStruct) -> SMCParamStruct? {
        var input = input
        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection, kernelIndex,
            &input, MemoryLayout<SMCParamStruct>.stride,
            &output, &outputSize
        )
        guard result == kIOReturnSuccess else { return nil }
        return output
    }

    // MARK: Helpers

    private static func fourCharCode(_ string: String) -> UInt32? {
        let chars = Array(string.utf8)
        guard chars.count == 4 else { return nil }
        return (UInt32(chars[0]) << 24) | (UInt32(chars[1]) << 16) | (UInt32(chars[2]) << 8) | UInt32(chars[3])
    }

    private static func typeString(_ code: UInt32) -> String {
        let bytes = [UInt8((code >> 24) & 0xFF), UInt8((code >> 16) & 0xFF),
                     UInt8((code >> 8) & 0xFF), UInt8(code & 0xFF)]
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func bytesArray(_ tuple: SMCBytes, count: Int) -> [UInt8] {
        withUnsafeBytes(of: tuple) { raw in
            Array(raw.prefix(count)).map { $0 }
        }
    }

    /// Per-core CPU temperature keys. Intel uses `TC0*`; Apple Silicon exposes the
    /// `Tp**` performance/efficiency-core sensors. We read every one that exists and
    /// average the plausible readings, so it works across chip generations.
    private static let cpuTempKeys: [String] = [
        // Intel
        "TC0P", "TC0D", "TC0E", "TC0F", "TCAD",
        // Apple Silicon performance cores (M1/M2/M3 families)
        "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j",
        "Tp0n", "Tp0r", "Tp0v", "Tp0z",
        // Apple Silicon efficiency cores
        "Tp1h", "Tp1t", "Tp1p", "Tp1l",
        // Apple Silicon SoC / cluster
        "Tc0a", "Tc0b", "Tc0x", "Tc0z", "Ts0S"
    ]
}
