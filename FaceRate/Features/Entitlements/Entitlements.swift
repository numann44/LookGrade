import Foundation

/// Subscription plan currently held by the user.
enum ProPlan: String, Codable {
    case weekly, monthly, yearly
}

/// Single source of truth for "what is this user allowed to do".
///
/// FaceRate is a hard-paywall app: there is no free usage. App Store trial
/// subscribers still receive the same active `pro` entitlement and limits as
/// paid subscribers.
struct Entitlements: Codable, Equatable {
    var isPro: Bool
    var plan: ProPlan?
    var proSince: Date?

    var canScan: Bool { isPro }

    static let initial = Entitlements(isPro: false, plan: nil, proSince: nil)
}
