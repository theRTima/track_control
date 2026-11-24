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

    /// `@autoclosure` so the message is not even built when logging is off: the
    /// call sites sit on the per-frame gesture path.
    public static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = "[\(Date())] \(message())\n"
        queue.async {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: Data(line.utf8))
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
