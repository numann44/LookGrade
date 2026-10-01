import UIKit

/// DESIGN.md §2.8 — light tap on primary buttons, medium impact on scan
/// completion, success notification on new high score / glow-up badge.
/// Thin wrapper matching the Dart app's `HapticFeedback.*` call sites.
enum Haptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
