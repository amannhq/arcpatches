// PatchEngine's file-level steps: swapping an app bundle in safely, running tools,
// and adding the weak load command to the browser's executable.
import AppKit

extension PatchEngine {
    static func aside(_ target: URL) -> URL {
        target.deletingLastPathComponent().appendingPathComponent(".\(target.lastPathComponent).arcpatches-old")
    }

    /// An interrupted swapIn (killed between its two moves) leaves the app aside: put it back.
    static func recoverSwap(at target: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: target.path), fm.fileExists(atPath: aside(target).path) { try? fm.moveItem(at: aside(target), to: target) }
    }

    /// recoverSwap for readers (status, the background check, app launch): only when no
    /// patch or restore holds the lock, so it never undoes the first move of a swap in progress.
    /// Otherwise a swap killed midway would leave the browser missing until the next patch.
    static func recoverSwapIfIdle(_ b: BrowserTarget) {
        let fm = FileManager.default
        var targets = [b.source]
        if b.mode == .copy { targets.append(b.copyDestination) }
        let stranded = targets.filter { !fm.fileExists(atPath: $0.path) && fm.fileExists(atPath: aside($0).path) }
        guard !stranded.isEmpty else { return }
        try? fm.createDirectory(at: b.supportDir, withIntermediateDirectories: true)
        let lock = open(b.supportDir.appendingPathComponent("patch.lock").path, O_CREAT | O_RDWR, 0o644)
        guard lock >= 0 else { return }
        defer { close(lock) }
        guard flock(lock, LOCK_EX | LOCK_NB) == 0 else { return }   // a patch is running: it recovers itself
        defer { flock(lock, LOCK_UN) }
        stranded.forEach(recoverSwap(at:))
    }

    /// Replaces `target` with `staging` (same folder): old one aside, new one in, old one removed.
    static func swapIn(_ staging: URL, at target: URL, browser name: String) throws {
        let fm = FileManager.default
        let old = aside(target)
        try? fm.removeItem(at: old)
        do {
            if fm.fileExists(atPath: target.path) { try fm.moveItem(at: target, to: old) }
            try fm.moveItem(at: staging, to: target)
        } catch {
            recoverSwap(at: target)
            let e = error as NSError
            if e.domain == NSCocoaErrorDomain && e.code == NSFileWriteNoPermissionError { throw PatchError.permission(name) }
            throw error
        }
        if (try? fm.removeItem(at: old)) == nil { try? fm.trashItem(at: old, resultingItemURL: nil) }
        _ = try? PatchEngine.runTool("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
                                     ["-f", target.path])
    }

    static func runTool(_ tool: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        return out
    }

    /// Adds LC_LOAD_WEAK_DYLIB to a thin, unsigned 64-bit Mach-O (same as tools/insert-dylib.c).
    /// Weak, so the app still launches (unpatched) if the dylib is ever missing.
    static func insertLoadCommand(into exe: URL, dylib path: String, browser name: String) throws {
        var data = try Data(contentsOf: exe)
        func u32(_ o: Int) -> UInt32 { data.subdata(in: o..<o + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) } }
        func put(_ v: UInt32, _ o: Int) { withUnsafeBytes(of: v.littleEndian) { data.replaceSubrange(o..<o + 4, with: $0) } }
        guard u32(0) == 0xfeedfacf else { throw PatchError.step("\(name)'s executable isn't a thin 64-bit Mach-O") }
        let ncmds = Int(u32(16)), sizeofcmds = Int(u32(20)), headerSize = 32
        var off = headerSize, firstData = Int.max
        for _ in 0..<ncmds {
            let cmd = u32(off), size = Int(u32(off + 4))
            if cmd == 0x1d { throw PatchError.step("\(name)'s executable is still signed") }        // LC_CODE_SIGNATURE
            if cmd == 0xc || cmd == 0x80000018 {                                                  // LC_LOAD(_WEAK)_DYLIB
                let nameOff = Int(u32(off + 8))
                let loaded = data.subdata(in: off + nameOff..<off + size).split(separator: 0).first.map { String(decoding: $0, as: UTF8.self) }
                if loaded == path { return }
            }
            if cmd == 0x19 {                                                                      // LC_SEGMENT_64: find the first section data
                let nsects = Int(u32(off + 64))
                for i in 0..<nsects {
                    let sec = off + 72 + i * 80, secOff = Int(u32(sec + 48))
                    if secOff > 0 { firstData = min(firstData, secOff) }
                }
            }
            off += size
        }
        let bytes = Array(path.utf8) + [0]
        let size = (24 + bytes.count + 7) & ~7
        let end = headerSize + sizeofcmds
        guard end + size <= firstData else { throw PatchError.step("No room in \(name)'s header for the patch") }
        var cmd = Data(count: size)
        func cput(_ v: UInt32, _ o: Int) { withUnsafeBytes(of: v.littleEndian) { cmd.replaceSubrange(o..<o + 4, with: $0) } }
        cput(0x80000018, 0); cput(UInt32(size), 4); cput(24, 8); cput(2, 12); cput(0x10000, 16); cput(0x10000, 20)
        cmd.replaceSubrange(24..<24 + bytes.count, with: bytes)
        data.replaceSubrange(end..<end + size, with: cmd)
        put(UInt32(ncmds + 1), 16)
        put(UInt32(sizeofcmds + size), 20)
        try data.write(to: exe)
    }

    @discardableResult
    func run(_ tool: String, _ args: [String], _ what: String) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { throw PatchError.step("\(what) failed: \(out.trimmingCharacters(in: .whitespacesAndNewlines))") }
        return out
    }
}
