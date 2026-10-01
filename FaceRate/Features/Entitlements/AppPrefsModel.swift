import Foundation
import Observation
import SwiftUI

/// User-selectable app appearance.
enum ThemeChoice: String, CaseIterable {
    case system, light, dark

    var label: String {
        switch self {
        case .system: return L10n.text("System")
        case .light: return L10n.text("Light")
        case .dark: return L10n.text("Dark")
        }
    }

    var icon: String {
        switch self {
        case .system: return "smartphone"
        case .light: return "sun"
        case .dark: return "eye"
        }
    }

    /// `nil` follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
@MainActor
final class AppPrefsModel {
    private let store: AppPrefsStore
    private(set) var hasSeenOnboarding: Bool
    private(set) var theme: ThemeChoice
    private(set) var remindersEnabled: Bool
    private(set) var onboardingName: String
    private(set) var onboardingGoals: [String]
    private(set) var onboardingFocus: String
    private(set) var onboardingConfidence: Double
    private(set) var pendingOnboardingScanID: String?

    init(store: AppPrefsStore = AppPrefsStore()) {
        self.store = store
        self.hasSeenOnboarding = store.hasSeenOnboarding
        self.theme = ThemeChoice(rawValue: store.themePreference) ?? .system
        self.remindersEnabled = store.remindersEnabled
        self.onboardingName = store.onboardingName
        self.onboardingGoals = store.onboardingGoals
        self.onboardingFocus = store.onboardingFocus
        self.onboardingConfidence = store.onboardingConfidence
        self.pendingOnboardingScanID = store.pendingOnboardingScanID
    }

    func markOnboardingSeen() {
        store.hasSeenOnboarding = true
        hasSeenOnboarding = true
    }

    func markOnboardingScanPending(_ result: ScanResult) {
        let id = ScanHistoryEntry.id(forCapturedAt: result.input.capturedAt)
        pendingOnboardingScanID = id
        store.pendingOnboardingScanID = id
    }

    func clearPendingOnboardingScan() {
        pendingOnboardingScanID = nil
        store.pendingOnboardingScanID = nil
    }

    func setTheme(_ choice: ThemeChoice) {
        theme = choice
        store.themePreference = choice.rawValue
    }

    /// Stores the lightweight onboarding profile locally. These answers only
    /// personalize presentation and recommendations; they never alter the
    /// deterministic face-analysis score.
    func saveOnboardingProfile(
        name: String,
        goals: [String],
        focus: String,
        confidence: Double
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        onboardingName = cleanName
        onboardingGoals = goals
        onboardingFocus = focus
        onboardingConfidence = min(max(confidence, 0), 1)

        store.onboardingName = cleanName
        store.onboardingGoals = goals
        store.onboardingFocus = focus
        store.onboardingConfidence = onboardingConfidence
    }

    /// Toggles the weekly reminder. Turning it on requests notification
    /// permission first; if the user declines, the toggle falls back to off.
    func setReminders(_ on: Bool) async {
        if on {
            let granted = await ReminderManager.requestAuthorization()
            guard granted else {
                remindersEnabled = false
                store.remindersEnabled = false
                return
            }
            await ReminderManager.scheduleWeekly()
        } else {
            ReminderManager.cancel()
        }
        remindersEnabled = on
        store.remindersEnabled = on
    }

    var colorScheme: ColorScheme? { theme.colorScheme }

    /// Used by "Delete all data".
    func reset() {
        store.reset()
        hasSeenOnboarding = false
        onboardingName = ""
        onboardingGoals = []
        onboardingFocus = ""
        onboardingConfidence = 0.55
        pendingOnboardingScanID = nil
    }
}
