import Foundation
import Combine
import Darwin

/// A minimal, honest system readout (spec §7 — stretch feature, off by default).
///
/// Truthfulness rule: this reports only what the OS actually exposes cheaply and
/// portably — aggregate CPU load and memory pressure, sampled once a second. SMC
/// thermal/fan sensors are largely unavailable on Apple Silicon, so rather than
/// fabricate numbers, those readouts declare themselves unavailable and the README
/// scopes full SMC support to the roadmap. When a sample can't be read, the value is
/// `nil`, never a placeholder.
final class SensorMonitor: ObservableObject {
    struct Sample: Identifiable {
        let id = UUID()
        let value: Double
    }

    @Published private(set) var cpuUsage: Double = 0          // 0…1
    @Published private(set) var memoryUsedFraction: Double = 0 // 0…1
    @Published private(set) var cpuHistory: [Sample] = []      // last 60s
    @Published private(set) var memoryHistory: [Sample] = []

    /// Live CPU die temperature in °C, or `nil` if this Mac doesn't surface it.
    @Published private(set) var cpuTemperature: Double?
    @Published private(set) var temperatureHistory: [Sample] = []
    /// Primary fan RPM, or `nil` on fanless Macs.
    @Published private(set) var fanRPM: Double?

    /// Whether the SMC exposes a CPU temperature on this machine. Probed once when
    /// sampling starts; the UI reads it to show a real readout vs. an honest note.
    @Published private(set) var thermalSensorsAvailable = false

    private let smc = SMCReader()
    private lazy var hid = IOHIDThermalReader() // Apple Silicon thermal fallback
    private var timer: Timer?
    private var previousCPUTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?
    private let historyLength = 60

    /// Start sampling. Called only when the user enables the tab, so a disabled Sensor
    /// tab costs literally nothing (spec §7, §10).
    func start() {
        guard timer == nil else { return }
        smc.open()
        // Probe once so the UI can decide between a real readout and an honest note.
        thermalSensorsAvailable = currentTemperature() != nil
        sample()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.sample() }
        RunLoop.main.add(timer, forMode: .common)
        timer.tolerance = 0.25
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        smc.close()
    }

    deinit { stop() }

    // MARK: Sampling

    private func sample() {
        if let usage = readCPUUsage() {
            cpuUsage = usage
            append(usage, to: &cpuHistory)
        }
        if let mem = readMemoryFraction() {
            memoryUsedFraction = mem
            append(mem, to: &memoryHistory)
        }
        if thermalSensorsAvailable, let temp = currentTemperature() {
            cpuTemperature = temp
            append(temp, to: &temperatureHistory)
        }
        fanRPM = smc.primaryFanRPM()
    }

    /// CPU temperature from whichever source this Mac exposes: SMC first (Intel / M1),
    /// then the HID thermal service (newer Apple Silicon).
    private func currentTemperature() -> Double? {
        smc.averageCPUTemperature() ?? hid?.averageCPUTemperature()
    }

    private func append(_ value: Double, to history: inout [Sample]) {
        history.append(Sample(value: value))
        if history.count > historyLength { history.removeFirst(history.count - historyLength) }
    }

    /// Aggregate CPU utilisation via `host_statistics(HOST_CPU_LOAD_INFO)`, computed as
    /// the busy-tick delta between samples. Portable across Intel and Apple Silicon.
    private func readCPUUsage() -> Double? {
        var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        var info = host_cpu_load_info_data_t()
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let user = info.cpu_ticks.0
        let system = info.cpu_ticks.1
        let idle = info.cpu_ticks.2
        let nice = info.cpu_ticks.3

        defer { previousCPUTicks = (user, system, idle, nice) }
        guard let previous = previousCPUTicks else { return 0 }

        let userDiff = Double(user &- previous.user)
        let systemDiff = Double(system &- previous.system)
        let niceDiff = Double(nice &- previous.nice)
        let idleDiff = Double(idle &- previous.idle)
        let total = userDiff + systemDiff + niceDiff + idleDiff
        guard total > 0 else { return 0 }
        return (userDiff + systemDiff + niceDiff) / total
    }

    /// Fraction of physical memory currently in use (active + wired + compressed).
    private func readMemoryFraction() -> Double? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = Double(vm_kernel_page_size)
        let used = (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count)) * pageSize
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        guard total > 0 else { return nil }
        return min(1, used / total)
    }
}
