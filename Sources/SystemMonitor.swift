import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class SystemMonitor {
    var cpuUsage: Double = 0
    var memoryUsed: UInt64 = 0
    var memoryTotal: UInt64 = 0
    var diskUsed: UInt64 = 0
    var diskTotal: UInt64 = 0
    var networkIn: Double = 0
    var networkOut: Double = 0

    private var prevCPUUser: UInt64 = 0
    private var prevCPUSystem: UInt64 = 0
    private var prevCPUIdle: UInt64 = 0
    private var prevCPUNice: UInt64 = 0
    private var prevNetBytesIn: UInt64 = 0
    private var prevNetBytesOut: UInt64 = 0
    private var prevUpdateTime = Date()

    init() {}

    func update() {
        updateCPU()
        updateMemory()
        updateDisk()
        updateNetwork()
    }

    // MARK: - CPU

    private func updateCPU() {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
            &numCPUs, &cpuInfo, &numCPUInfo
        )
        defer {
            if let info = cpuInfo {
                vm_deallocate(
                    mach_task_self_,
                    vm_address_t(bitPattern: info),
                    vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
                )
            }
        }
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(numCPUs) {
            let base = i * Int(CPU_STATE_MAX)
            totalUser   += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]))
            totalSystem += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]))
            totalIdle   += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]))
            totalNice   += UInt64(UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]))
        }

        let dUser   = totalUser   &- prevCPUUser
        let dSystem = totalSystem &- prevCPUSystem
        let dIdle   = totalIdle   &- prevCPUIdle
        let dNice   = totalNice   &- prevCPUNice
        let dTotal  = dUser + dSystem + dIdle + dNice

        if dTotal > 0 {
            cpuUsage = Double(dUser + dSystem + dNice) / Double(dTotal) * 100
        }

        prevCPUUser   = totalUser
        prevCPUSystem = totalSystem
        prevCPUIdle   = totalIdle
        prevCPUNice   = totalNice
    }

    // MARK: - Memory

    private func updateMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return }

        var pageSize = vm_size_t(0)
        host_page_size(mach_host_self(), &pageSize)
        let ps = UInt64(pageSize)

        memoryUsed = (
            UInt64(stats.active_count) +
            UInt64(stats.inactive_count) +
            UInt64(stats.wire_count) +
            UInt64(stats.compressor_page_count)
        ) * ps

        if memoryTotal == 0 {
            var total: UInt64 = 0
            var size = MemoryLayout<UInt64>.size
            sysctlbyname("hw.memsize", &total, &size, nil, 0)
            memoryTotal = total
        }
    }

    // MARK: - Disk

    private func updateDisk() {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/") else { return }
        let total = attrs[.systemSize] as? UInt64 ?? 0
        let free  = attrs[.systemFreeSize] as? UInt64 ?? 0
        diskTotal = total
        diskUsed  = total > free ? total - free : 0
    }

    // MARK: - Network

    private func updateNetwork() {
        let now = Date()
        let elapsed = now.timeIntervalSince(prevUpdateTime)
        let (bytesIn, bytesOut) = readNetworkBytes()

        if prevNetBytesIn > 0 && bytesIn >= prevNetBytesIn && elapsed > 0 {
            networkIn = Double(bytesIn - prevNetBytesIn) / elapsed
        } else if prevNetBytesIn > 0 {
            networkIn = 0
        }

        if prevNetBytesOut > 0 && bytesOut >= prevNetBytesOut && elapsed > 0 {
            networkOut = Double(bytesOut - prevNetBytesOut) / elapsed
        } else if prevNetBytesOut > 0 {
            networkOut = 0
        }

        prevNetBytesIn  = bytesIn
        prevNetBytesOut = bytesOut
        prevUpdateTime  = now
    }

    private func readNetworkBytes() -> (in: UInt64, out: UInt64) {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return (0, 0) }
        defer { freeifaddrs(ifap) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var ptr: UnsafeMutablePointer<ifaddrs>? = first

        while let p = ptr {
            if (Int32(p.pointee.ifa_flags) & IFF_LOOPBACK) == 0,
               p.pointee.ifa_addr?.pointee.sa_family == sa_family_t(AF_LINK),
               let data = p.pointee.ifa_data?.assumingMemoryBound(to: if_data.self) {
                totalIn  += UInt64(data.pointee.ifi_ibytes)
                totalOut += UInt64(data.pointee.ifi_obytes)
            }
            ptr = p.pointee.ifa_next
        }
        return (totalIn, totalOut)
    }

    // MARK: - Formatters

    // Returns exactly 4 chars: "%3.0f" (3-digit right-aligned) + 1-char unit.
    // Decimal boundaries (1_000 / 1_000_000 / …) ensure the divided value stays < 1000
    // even at the top of each range, so %3.0f never overflows to 4 digits.
    func formatBytes(_ bytes: UInt64) -> String {
        let v = Double(bytes)
        if v >= 1_000_000_000_000 { return String(format: "%3.0fT", v / 1_099_511_627_776) }
        if v >= 1_000_000_000     { return String(format: "%3.0fG", v / 1_073_741_824) }
        if v >= 1_000_000         { return String(format: "%3.0fM", v / 1_048_576) }
        if v >= 1_000             { return String(format: "%3.0fK", v / 1_024) }
        return String(format: "%3.0fB", v)
    }

    func formatSpeed(_ bps: Double) -> String {
        if bps >= 1_000_000_000 { return String(format: "%3.0fG", bps / 1_073_741_824) }
        if bps >= 1_000_000     { return String(format: "%3.0fM", bps / 1_048_576) }
        if bps >= 1_000         { return String(format: "%3.0fK", bps / 1_024) }
        return String(format: "%3.0fB", bps)
    }
}
