import CoreGraphics

/// Named corner-radius scale — soft, premium squircles (used with
/// `.continuous` corner style on cards).
enum AppRadius {
    static let xs: CGFloat = 8     // chips, small tags
    static let sm: CGFloat = 12    // buttons, small tiles
    static let md: CGFloat = 16    // small cards
    static let lg: CGFloat = 22    // primary cards
    static let xl: CGFloat = 28    // hero cards, bottom sheets
    static let full: CGFloat = 999 // pills, avatars
}
