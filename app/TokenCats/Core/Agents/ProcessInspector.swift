import Darwin
import Foundation

struct ProcessDetail: Equatable, Sendable {
    /// Controlling terminal name (e.g. "ttys035"); nil for detached processes.
    let tty: String?
    /// Kernel start time "<sec>.<usec>"; identifies a process across PID reuse.
    let startedAt: String
    /// argv joined by spaces.
    let command: String
    let cwd: String?
    var parentPid: Int32 = 0
    /// Short process name (e.g. "claude", "node").
    var name: String = ""
}

protocol ProcessInspector: Sendable {
    /// nil when the process no longer exists or cannot be inspected.
    func detail(of pid: Int32) -> ProcessDetail?
    func allPids() -> [Int32]
    func environment(of pid: Int32) -> [String: String]
    func openFilePaths(of pid: Int32) -> [String]
}

extension ProcessInspector {
    func allPids() -> [Int32] { [] }
    func environment(of pid: Int32) -> [String: String] { [:] }
    func openFilePaths(of pid: Int32) -> [String] { [] }
}

/// Reads process info straight from the kernel (libproc + sysctl): microseconds per pid, no `ps`/`lsof` spawn.
struct SystemProcessInspector: ProcessInspector {
    func detail(of pid: Int32) -> ProcessDetail? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        let startedAt = String(format: "%llu.%06llu", info.pbi_start_tvsec, info.pbi_start_tvusec)
        let name = withUnsafeBytes(of: info.pbi_comm) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return ProcessDetail(
            tty: Self.ttyName(info.e_tdev), startedAt: startedAt, command: Self.arguments(of: pid), cwd: Self.cwd(of: pid),
            parentPid: Int32(bitPattern: info.pbi_ppid), name: name)
    }

    func allPids() -> [Int32] {
        let count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }
        var pids = [Int32](repeating: 0, count: Int(count) + 32)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<Int32>.size))
        return Array(pids.prefix(Int(max(0, filled)))).filter { $0 > 0 }
    }

    /// Environment block of a same-user process (follows argv in KERN_PROCARGS2).
    func environment(of pid: Int32) -> [String: String] {
        guard let (argc, strings) = Self.procArgStrings(of: pid) else { return [:] }
        var env: [String: String] = [:]
        for entry in strings.dropFirst(Int(argc)) {
            guard let eq = entry.firstIndex(of: "=") else { continue }
            env[String(entry[..<eq])] = String(entry[entry.index(after: eq)...])
        }
        return env
    }

    func openFilePaths(of pid: Int32) -> [String] {
        let size = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard size > 0 else { return [] }
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(size) / MemoryLayout<proc_fdinfo>.size)
        let filled = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, size)
        guard filled > 0 else { return [] }
        return fds.prefix(Int(filled) / MemoryLayout<proc_fdinfo>.size).compactMap { fd in
            guard fd.proc_fdtype == PROX_FDTYPE_VNODE else { return nil }
            var info = vnode_fdinfowithpath()
            let infoSize = Int32(MemoryLayout<vnode_fdinfowithpath>.size)
            guard proc_pidfdinfo(pid, fd.proc_fd, PROC_PIDFDVNODEPATHINFO, &info, infoSize) == infoSize else { return nil }
            let path = withUnsafeBytes(of: info.pvip.vip_path) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            return path.isEmpty ? nil : path
        }
    }

    private static func ttyName(_ device: UInt32) -> String? {
        let dev = dev_t(bitPattern: device)
        guard dev != -1, dev != 0, let name = devname(dev, S_IFCHR) else { return nil }
        return String(cString: name)
    }

    private static func cwd(of pid: Int32) -> String? {
        var info = proc_vnodepathinfo()
        let size = Int32(MemoryLayout<proc_vnodepathinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, size) == size else { return nil }
        let path = withUnsafeBytes(of: info.pvi_cdir.vip_path) { raw in
            String(cString: raw.bindMemory(to: CChar.self).baseAddress!)
        }
        return path.isEmpty ? nil : path
    }

    private static func arguments(of pid: Int32) -> String {
        guard let (argc, strings) = procArgStrings(of: pid) else { return "" }
        return strings.prefix(Int(argc)).joined(separator: " ")
    }

    /// KERN_PROCARGS2 layout: argc (Int32), exec path, NUL padding, then NUL-terminated strings:
    /// argc argv entries followed by the environment.
    private static func procArgStrings(of pid: Int32) -> (argc: Int32, strings: [String])? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var length = 0
        guard sysctl(&mib, 3, nil, &length, nil, 0) == 0, length > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: length)
        guard sysctl(&mib, 3, &buffer, &length, nil, 0) == 0 else { return nil }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < length && buffer[index] != 0 { index += 1 }  // exec path
        while index < length && buffer[index] == 0 { index += 1 }  // padding
        var strings: [String] = []
        while index < length {
            let start = index
            while index < length && buffer[index] != 0 { index += 1 }
            if start == index { break }  // end of the environment block
            strings.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return (argc, strings)
    }
}
