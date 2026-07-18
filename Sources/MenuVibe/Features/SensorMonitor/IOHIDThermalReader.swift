import Foundation
import IOKit

/// Reads temperature sensors on Apple Silicon via `IOHIDEventSystemClient`.
///
/// Newer Apple Silicon Macs don't surface CPU temperature through the SMC `Tp**` keys
/// that Intel/M1 used — the sensors live behind the HID thermal service instead. Those
/// functions aren't in the public SDK, so we resolve them at runtime with `dlsym`
/// (no private headers, no linking against unexported symbols). If any symbol or the
/// service is missing, every method returns `nil` and the caller degrades honestly.
final class IOHIDThermalReader {

    // Runtime-resolved private IOKit symbols.
    private typealias ClientCreateFn = @convention(c) (CFAllocator?) -> UnsafeMutableRawPointer?
    private typealias SetMatchingFn  = @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?) -> Void
    private typealias CopyServicesFn = @convention(c) (UnsafeMutableRawPointer?) -> UnsafeRawPointer?
    private typealias CopyEventFn    = @convention(c) (UnsafeRawPointer?, Int64, UInt32, Int64) -> UnsafeMutableRawPointer?
    private typealias CopyPropertyFn = @convention(c) (UnsafeRawPointer?, CFString) -> UnsafeRawPointer?
    private typealias GetFloatFn     = @convention(c) (UnsafeMutableRawPointer?, Int32) -> Double

    private let clientCreate: ClientCreateFn
    private let setMatching: SetMatchingFn
    private let copyServices: CopyServicesFn
    private let copyEvent: CopyEventFn
    private let copyProperty: CopyPropertyFn
    private let getFloat: GetFloatFn

    private var client: UnsafeMutableRawPointer?

    // kIOHIDEventTypeTemperature and its float field.
    private let temperatureEventType: Int64 = 15
    private var temperatureField: Int32 { Int32(15 << 16) }
    // AppleVendor HID page + temperature-sensor usage.
    private let kHIDPage_AppleVendor = 0xff00
    private let kHIDUsage_AppleVendor_TemperatureSensor = 0x0005

    /// CPU/SoC-relevant sensor name fragments. Apple's sensor product names vary by
    /// chip; these cover the common performance/efficiency-core and SoC labels.
    private static let cpuNameHints = ["CPU", "SOC", "PACC", "EACC", "PMGR", "TDIE", "GPU"]

    init?() {
        // The symbols are already loaded in-process (IOKit); resolve from the global scope.
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY) else {
            return nil
        }
        func sym<T>(_ name: String, as type: T.Type) -> T? {
            guard let ptr = dlsym(handle, name) else { return nil }
            return unsafeBitCast(ptr, to: T.self)
        }
        guard let create = sym("IOHIDEventSystemClientCreate", as: ClientCreateFn.self),
              let match  = sym("IOHIDEventSystemClientSetMatching", as: SetMatchingFn.self),
              let copy   = sym("IOHIDEventSystemClientCopyServices", as: CopyServicesFn.self),
              let event  = sym("IOHIDServiceClientCopyEvent", as: CopyEventFn.self),
              let prop   = sym("IOHIDServiceClientCopyProperty", as: CopyPropertyFn.self),
              let flt    = sym("IOHIDEventGetFloatValue", as: GetFloatFn.self)
        else { return nil }

        clientCreate = create
        setMatching = match
        copyServices = copy
        copyEvent = event
        copyProperty = prop
        getFloat = flt

        guard let c = clientCreate(kCFAllocatorDefault) else { return nil }
        client = c
        let matching: CFDictionary = [
            "PrimaryUsagePage": kHIDPage_AppleVendor,
            "PrimaryUsage": kHIDUsage_AppleVendor_TemperatureSensor
        ] as CFDictionary
        setMatching(client, Unmanaged.passUnretained(matching).toOpaque())
    }

    /// Average of the CPU/SoC-relevant temperature sensors in °C (falls back to the
    /// average of all temperature sensors if none match by name), or `nil`.
    func averageCPUTemperature() -> Double? {
        guard let client, let servicesPtr = copyServices(client) else { return nil }
        let services = unsafeBitCast(servicesPtr, to: CFArray.self)
        defer { Unmanaged<AnyObject>.fromOpaque(servicesPtr).release() }

        let count = CFArrayGetCount(services)
        guard count > 0 else { return nil }

        var cpuTemps: [Double] = []
        var allTemps: [Double] = []

        for i in 0..<count {
            guard let service = CFArrayGetValueAtIndex(services, i) else { continue }
            guard let eventPtr = copyEvent(service, temperatureEventType, 0, 0) else { continue }
            let value = getFloat(eventPtr, temperatureField)
            Unmanaged<AnyObject>.fromOpaque(eventPtr).release()
            guard value > 5, value < 130 else { continue }
            allTemps.append(value)

            if let namePtr = copyProperty(service, "Product" as CFString) {
                let name = (unsafeBitCast(namePtr, to: CFString.self) as String).uppercased()
                Unmanaged<AnyObject>.fromOpaque(namePtr).release()
                if Self.cpuNameHints.contains(where: name.contains) {
                    cpuTemps.append(value)
                }
            }
        }

        let pick = cpuTemps.isEmpty ? allTemps : cpuTemps
        guard !pick.isEmpty else { return nil }
        return pick.reduce(0, +) / Double(pick.count)
    }
}
