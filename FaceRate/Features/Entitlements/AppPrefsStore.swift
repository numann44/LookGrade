import Foundation

/// Lightweight global app flags: the first-launch tracker and the theme
/// preference.
final class AppPrefsStore {
    static let key = "facerate.has_seen_onboarding.v1"
    static let themeKey = "facerate.theme.v1"
    static let onboardingNameKey = "lookgrade.onboarding.name.v1"
    static let onboardingGoalsKey = "lookgrade.onboarding.goals.v1"
    static let onboardingFocusKey = "lookgrade.onboarding.focus.v1"
    static let onboardingConfidenceKey = "lookgrade.onboarding.confidence.v1"
    static let pendingOnboardingScanIDKey = "lookgrade.onboarding.pending_scan.v1"
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var hasSeenOnboarding: Bool {
        get { defaults.bool(forKey: Self.key) }
        set { defaults.set(newValue, forKey: Self.key) }
    }

    static let remindersKey = "facerate.reminders.v1"

    var themePreference: String {
        get { defaults.string(forKey: Self.themeKey) ?? "system" }
        set { defaults.set(newValue, forKey: Self.themeKey) }
    }

    var remindersEnabled: Bool {
        get { defaults.bool(forKey: Self.remindersKey) }
        set { defaults.set(newValue, forKey: Self.remindersKey) }
    }

    var onboardingName: String {
        get { defaults.string(forKey: Self.onboardingNameKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.onboardingNameKey) }
    }

    var onboardingGoals: [String] {
        get { defaults.stringArray(forKey: Self.onboardingGoalsKey) ?? [] }
        set { defaults.set(newValue, forKey: Self.onboardingGoalsKey) }
    }

    var onboardingFocus: String {
        get { defaults.string(forKey: Self.onboardingFocusKey) ?? "" }
        set { defaults.set(newValue, forKey: Self.onboardingFocusKey) }
    }

    var onboardingConfidence: Double {
        get {
            guard defaults.object(forKey: Self.onboardingConfidenceKey) != nil else { return 0.55 }
            return defaults.double(forKey: Self.onboardingConfidenceKey)
        }
        set { defaults.set(newValue, forKey: Self.onboardingConfidenceKey) }
    }

    /// The first real scan is analyzed before Pro is unlocked. Keep its
    /// deterministic entry ID so a completed purchase can safely promote it
    /// into the user's scan history, even after the app is relaunched.
    var pendingOnboardingScanID: String? {
        get { defaults.string(forKey: Self.pendingOnboardingScanIDKey) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Self.pendingOnboardingScanIDKey)
            } else {
                defaults.removeObject(forKey: Self.pendingOnboardingScanIDKey)
            }
        }
    }

    /// Used by "Delete all data" — resets onboarding so the slides show again.
    /// Theme is a display preference, not user data, so it's left intact.
    func reset() {
        defaults.removeObject(forKey: Self.key)
        defaults.removeObject(forKey: Self.onboardingNameKey)
        defaults.removeObject(forKey: Self.onboardingGoalsKey)
        defaults.removeObject(forKey: Self.onboardingFocusKey)
        defaults.removeObject(forKey: Self.onboardingConfidenceKey)
        defaults.removeObject(forKey: Self.pendingOnboardingScanIDKey)
    }
}
