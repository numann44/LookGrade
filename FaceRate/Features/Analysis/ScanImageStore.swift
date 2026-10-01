import Foundation

/// Manages the short-lived on-disk copies of captured face photos.
///
/// The captured photo is the most sensitive artifact the app touches, so it
/// lives in a single directory we fully control (not the shared temp dir the
/// OS never guarantees to clear): at most one photo — the latest capture — is
/// ever at rest, and `clearAll()` (wired into "Delete all data") wipes every
/// trace. Files sit under Caches, so iOS may also purge them under storage
/// pressure. This replaces the old `temporaryDirectory` writes that
/// accumulated unbounded and survived a data wipe.
enum ScanImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ScanImages", isDirectory: true)
    }

    /// iOS can relocate an app's data container during an update. Recover
    /// only our own UUID-named captures; never reinterpret arbitrary paths.
    static func currentPath(forStoredPath path: String) -> String {
        let components = (path as NSString).pathComponents
        guard components.count >= 4,
              Array(components.suffix(4).prefix(3)) == ["Library", "Caches", "ScanImages"],
              let filename = components.last,
              (filename as NSString).pathExtension == "jpg",
              UUID(uuidString: (filename as NSString).deletingPathExtension) != nil else {
            return path
        }
        return directory.appendingPathComponent(filename).path
    }

    /// Writes JPEG data for a new capture, first removing any previous photo
    /// so only the current one is ever on disk. Returns the file URL.
    static func write(_ data: Data) throws -> URL {
        clearAll()
        let dir = directory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent(UUID().uuidString + ".jpg")
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return url
    }

    /// Removes every stored face photo. Called on "Delete all data".
    static func clearAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
