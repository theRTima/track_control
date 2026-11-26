import Foundation

/// Minimal logger. Silent unless `TRACKCONTROL_DEBUG=1` is set in the
/// environment, in which case frames and system calls are written to
/// `~/Library/Logs/TrackControl.log`.
public enum Debug {
    public static let isEnabled = ProcessInfo.processInfo.environment["TRACKCONTROL_DEBUG"] == "1"

    private static let queue = DispatchQueue(label: "TrackControl.Debug")
    private static let url: URL = {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("TrackControl.log")
    }()

    /// Opened once and kept open, so a frame does not open and close the file.
    private static let handle: FileHandle? = {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
        let handle = try? FileHandle(forWritingTo: url)
        _ = try? handle?.seekToEnd()
        return handle
    }()

    /// `@autoclosure` so the message is not even built when logging is off: the
    /// call sites sit on the per-frame gesture path.
    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = "[\(Date())] \(message())\n"
        queue.async { try? handle?.write(contentsOf: Data(line.utf8)) }
    }
}
