import UIKit

/// Persists a small thumbnail per scan (keyed by the history entry id) so the
/// before/after comparison has images to show. Distinct from `ScanImageStore`
/// (which holds only the transient full-res capture): these are deliberately
/// downscaled (≤480px, ~30 KB) to bound growth, live in Application Support,
/// and are wiped by "Delete all data" / "Clear history".
enum ScanPhotoLibrary {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ScanPhotos", isDirectory: true)
    }

    private static func url(for id: String) -> URL {
        directory.appendingPathComponent(id + ".jpg")
    }

    /// Downscales the full-res capture at `path` and stores it under `id`.
    static func save(fromPath path: String, id: String) {
        guard !path.isEmpty, let image = UIImage(contentsOfFile: path) else { return }
        let thumb = downscale(image, maxDimension: 480)
        guard let data = thumb.jpegData(compressionQuality: 0.7) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url(for: id), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func image(for id: String) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    static func clearAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
