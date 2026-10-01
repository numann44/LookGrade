import Foundation
import Observation
import RevenueCat

/// Local entitlement state backed by RevenueCat. Whether the subscription
/// state came from a fresh purchase, a restore, or the delegate's
/// customer-info-changed callback, `apply(_:)` is the single reconciliation
/// path for all three, mirroring entitlements_providers.dart's
/// `_applyCustomerInfo`.
@Observable
@MainActor
final class EntitlementsModel: NSObject {
    private let store: EntitlementsStore
    private let recoveryStore = SubscriptionRecoveryStore()
    private(set) var entitlements: Entitlements
    private(set) var currentOffering: Offering?
    private(set) var managementURL: URL?
    // Metadata from RevenueCat's entitlement, never inferred from button copy.
    private(set) var analyticsPeriodType: String?
    private(set) var analyticsIsSandbox: Bool?

    #if DEBUG
    /// Local-only access for Simulator and QA builds. This flag is compiled
    /// out of Release builds and never changes RevenueCat customer state.
    private(set) var hasTestAccess =
        ProcessInfo.processInfo.environment["FACERATE_TEST_MODE"] == "1"
    #endif

    init(store: EntitlementsStore = EntitlementsStore()) {
        self.store = store
        self.entitlements = store.load()
        super.init()
        Purchases.shared.delegate = self
        #if DEBUG
        if !hasTestAccess {
            Task { await refresh() }
            Task { await loadOfferings() }
        }
        #else
        Task { await refresh() }
        Task { await loadOfferings() }
        #endif
    }

    /// The effective app-access gate. A real subscription is always required
    /// in Release; Debug builds may opt into a temporary local test pass.
    var hasAccess: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["FACERATE_FORCE_GATE"] == "1" {
            return false
        }
        return entitlements.isPro || hasTestAccess
        #else
        return entitlements.isPro
        #endif
    }

    var canScan: Bool { hasAccess }

    #if DEBUG
    func grantTestAccess() {
        hasTestAccess = true
    }
    #endif

    /// Called after the user deletes their local scan/profile data. Pro status
    /// is not user content — the App Store / RevenueCat owns it — so a local
    /// wipe must not drop it. Just reconcile against the server.
    func preserveAccessAfterDataDeletion() {
        Task { await refresh() }
    }

    func loadOfferings() async {
        currentOffering = try? await Purchases.shared.offerings().current
    }

    func refresh() async {
        // Purchases.configure() already primes the cache; this just makes
        // sure our local mirror is reconciled on cold launch too, not only
        // on the next delegate callback.
        if let info = try? await Purchases.shared.customerInfo() {
            apply(info)
        }

        // An App Store subscription is owned by the purchaser's Apple
        // account, not by this app install. If this device has previously
        // held Pro and has since been reinstalled, silently reconcile the
        // current receipt once. The normal visible Restore Purchases control
        // remains available for older installs or a changed Apple account.
        guard !entitlements.isPro,
              recoveryStore.hasHeldPro,
              RevenueCatConfig.usesAppStore else { return }

        if let restored = try? await Purchases.shared.syncPurchases() {
            apply(restored)
        }
    }

    func purchase(_ package: Package) async throws -> Bool {
        let result = try await Purchases.shared.purchase(package: package)
        apply(result.customerInfo)
        return !result.userCancelled
    }

    func restorePurchases() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
        return entitlements.isPro
    }

    func apply(_ info: CustomerInfo) {
        var next = entitlements
        let active = info.entitlements[RevenueCatConfig.entitlementId]
        analyticsPeriodType = active.map { String(describing: $0.periodType) }
        analyticsIsSandbox = active?.isSandbox
        next.isPro = active?.isActive == true
        if next.isPro {
            recoveryStore.markHeldPro()
            if let productId = active?.productIdentifier {
                let normalizedId = productId.lowercased()
                if normalizedId.contains("year") {
                    next.plan = .yearly
                } else if normalizedId.contains("month") {
                    next.plan = .monthly
                } else {
                    next.plan = .weekly
                }
            }
            if next.proSince == nil { next.proSince = Date() }
        } else {
            next.plan = nil
            next.proSince = nil
        }
        entitlements = next
        managementURL = info.managementURL
        store.save(next)
    }
}

/// A one-bit recovery hint, not a device fingerprint and not a subscription
/// source of truth. It stays in the keychain across a normal reinstall and
/// only decides whether the App Store receipt should be reconciled silently.
/// RevenueCat/Apple's active entitlement remains the sole access decision.
private final class SubscriptionRecoveryStore {
    private let service = "com.lokman.facerate"
    private let account = "lookgrade.subscription-recovery.v1"

    var hasHeldPro: Bool {
        KeychainDataStore.read(service: service, account: account) != nil
    }

    func markHeldPro() {
        KeychainDataStore.write(Data([1]), service: service, account: account)
    }
}

extension EntitlementsModel: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo)
        }
    }
}
