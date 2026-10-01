import SwiftUI
import RevenueCat

/// A per-install marker. It intentionally lives in UserDefaults rather than
/// Keychain: uninstalling the app starts a fresh acquisition flow, while
/// clearing in-app content does not recreate the offer.
enum PaywallExitOffer {
    static let consumedKey = "lookgrade.paywall.exit_offer_consumed.v1"
    static let annualProductID = "facerate_yearly_exit"
}

/// App-owned presentation with RevenueCat-owned products and transactions.
/// Keeping the UI local makes the paywall match FaceRate on every device,
/// while prices, trials, purchases, restores, and entitlements remain live.
struct PaywallScreen: View {
    var dismissable: Bool = true
    var allowsExitOffer: Bool = true
    /// Used by the first-scan gate, which remains locked after a user leaves
    /// their one-time exit offer.
    var onExit: (() -> Void)? = nil
    var source: String = "profile"
    @State private var analyticsVisitID = UUID().uuidString
    @State private var didTrackVisit = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(EntitlementsModel.self) private var entitlementsModel

    @State private var selectedIdentifier: String?
    @State private var isLoading = false
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var introEligibility: [String: IntroEligibilityStatus] = [:]
    @State private var isShowingExitOffer = {
        #if DEBUG
        ProcessInfo.processInfo.environment["FACERATE_PREVIEW_EXIT_OFFER"] == "1"
        #else
        false
        #endif
    }()
    @State private var showsExitWarning = false
    @State private var showsExitMascot = false
    @State private var exitDialogue = MiroDialogueProgress(count: 2)
    @State private var pendingExitPackage: Package?
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    // Resolve public plans by product ID. The offering also contains a second
    // annual product for the exit offer, so the generic `.annual` accessor can
    // surface the discounted SKU when StoreKit changes its ordering.
    private var annualPackage: Package? {
        standardPackage(productID: "facerate_yearly")
            ?? entitlementsModel.currentOffering?.availablePackages.first {
                $0.packageType == .annual
                    && $0.storeProduct.productIdentifier != PaywallExitOffer.annualProductID
            }
    }

    private var weeklyPackage: Package? {
        standardPackage(productID: "facerate_weekly")
            ?? entitlementsModel.currentOffering?.weekly
    }

    private var monthlyPackage: Package? {
        standardPackage(productID: "facerate_monthly")
            ?? entitlementsModel.currentOffering?.monthly
    }
    /// This is a distinct App Store subscription SKU. Its price is never
    /// invented in the UI: if RevenueCat has not supplied it, no discounted
    /// purchase surface is shown.
    private var exitAnnualPackage: Package? {
        return entitlementsModel.currentOffering?.availablePackages.first {
            $0.storeProduct.productIdentifier == PaywallExitOffer.annualProductID
        }
    }

    private func standardPackage(productID: String) -> Package? {
        entitlementsModel.currentOffering?.availablePackages.first {
            $0.storeProduct.productIdentifier == productID
        }
    }

    private var activeExitAnnualPackage: Package? {
        guard allowsExitOffer else { return nil }
        return exitAnnualPackage
    }

    private var exitOriginalPrice: String? {
        return annualPackage?.storeProduct.localizedPriceString
    }

    /// Yearly leads, while Weekly and Monthly remain immediately visible.
    /// Missing App Store products never block packages that did load.
    private var packages: [Package] {
        [annualPackage, weeklyPackage, monthlyPackage].compactMap { $0 }
    }

    private var allPackages: [Package] {
        packages + (activeExitAnnualPackage.map { [$0] } ?? [])
    }

    private var exitPackages: [Package] {
        [activeExitAnnualPackage, weeklyPackage, monthlyPackage].compactMap { $0 }
    }

    private var packageIdentifiers: [String] { allPackages.map(\.identifier) }

    private var displaysExitOffer: Bool {
        isShowingExitOffer && activeExitAnnualPackage != nil
    }

    private var selectedPackage: Package? {
        if displaysExitOffer {
            return exitPackages.first { $0.identifier == selectedIdentifier }
                ?? activeExitAnnualPackage
        }
        return packages.first { $0.identifier == selectedIdentifier } ?? packages.first
    }

    private var isExitPackageSelected: Bool {
        guard displaysExitOffer,
              let activeExitAnnualPackage,
              let selectedPackage else { return false }
        return selectedPackage.identifier == activeExitAnnualPackage.identifier
    }

    private var yearlySavings: Int? {
        guard let annualPackage else { return nil }

        let comparisonPrice: Decimal?
        if let monthlyPackage {
            comparisonPrice = monthlyPackage.storeProduct.price * 12
        } else if let weeklyPackage {
            comparisonPrice = weeklyPackage.storeProduct.price * 52
        } else {
            comparisonPrice = nil
        }

        guard let comparisonPrice, comparisonPrice > 0 else { return nil }
        let rawSavings = (comparisonPrice - annualPackage.storeProduct.price) / comparisonPrice * 100
        // Decimal's NSNumber bridge reports an incorrect `intValue` on some
        // OS versions, so convert through its reliable Double representation.
        let percentage = Int(Double(truncating: rawSavings as NSNumber).rounded())
        return percentage > 0 ? min(percentage, 99) : nil
    }

    var body: some View {
        ZStack {
            AppColors.bgPrimary.ignoresSafeArea()
            PaywallBackdrop()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    hero

                    if isLoading && allPackages.isEmpty {
                        loadingState
                    } else if packages.isEmpty {
                        unavailableState
                    } else if displaysExitOffer, let activeExitAnnualPackage {
                        exitOfferPlan(activeExitAnnualPackage)
                    } else {
                        planList
                        accessSummary
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .appFont(.caption)
                            .foregroundStyle(AppColors.stateDanger)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    }

                    legalCopy
                        .padding(.top, 18)
                        .padding(.bottom, 154)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .accessibilityHidden(showsExitMascot)
            .allowsHitTesting(!showsExitMascot)

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            purchaseBar
                .opacity(showsExitMascot ? 0 : 1)
                .allowsHitTesting(!showsExitMascot)
                .accessibilityHidden(showsExitMascot)
        }
        .overlay {
            if showsExitMascot {
                ExitOfferMascotMoment(
                    isSmiling: exitDialogue.index == 1,
                    onContinue: { advanceExitDialogue(expectedIndex: exitDialogue.index) }
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
        .analyticsScreen("paywall")
        .onAppear {
            guard !didTrackVisit else { return }
            didTrackVisit = true
            trackPaywall(.paywallViewed)
        }
        .task {
            await refreshPackagesIfNeeded()
        }
        .onChange(of: packageIdentifiers) { _, _ in
            chooseDefaultPackage()
            Task { await refreshIntroEligibility() }
        }
        .task(id: "\(showsExitMascot ? exitDialogue.index : -1)-\(scenePhase)") {
            guard showsExitMascot, !voiceOverEnabled, scenePhase == .active else { return }
            let expected = exitDialogue.index
            do { try await Task.sleep(for: .seconds(L10n.readingDelay(for: exitDialogue.index == 0 ? L10n.text("Leaving already? You’ve got so much to work with. One last thing…") : L10n.text("I’d love to keep going with you. Here’s a lower yearly price.")))) } catch { return }
            guard !Task.isCancelled else { return }
            advanceExitDialogue(expectedIndex: expected)
        }
        .alert(L10n.text("Leave your 50% offer?"), isPresented: $showsExitWarning) {
            Button(L10n.text("Keep my offer"), role: .cancel) { trackPaywall(.offerKept) }
            Button(L10n.text("Leave anyway"), role: .destructive) {
                finishExit()
            }
        } message: {
            Text(L10n.text("This discounted yearly plan will not be shown again on this installation."))
        }
    }

    private var topBar: some View {
        HStack {
            Text("LOOKGRADE PRO")
                .appFont(.overline)
                .foregroundStyle(AppColors.textSecondary)

            Spacer()

            if dismissable {
                Button {
                    handleClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.bgSurfaceElevated, in: Circle())
                        .overlay {
                            Circle().strokeBorder(AppColors.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Close"))
            }
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var hero: some View {
        VStack(spacing: 6) {
            MiroCompanion(
                message: displaysExitOffer
                    ? L10n.text("I’d love to keep going with you. Here’s your special yearly price.")
                    : L10n.text("You look great already. Let’s make your next steps personal."),
                expression: displaysExitOffer ? .laugh : .grin,
                size: 164
            )
            Text(displaysExitOffer ? L10n.text("Your next chapter, for less.") : L10n.text("Your glow-up. With a clear plan."))
                .font(.system(size: 25, weight: .semibold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(L10n.text("Full report · Personal tips · Progress tracking"))
                .appFont(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
    }

    private var planList: some View {
        VStack(spacing: 10) {
            ForEach(packages, id: \.identifier) { package in
                PaywallPlanCard(
                    package: package,
                    kind: planKind(for: package),
                    selected: selectedPackage?.identifier == package.identifier,
                    savings: package.packageType == .annual ? yearlySavings : nil,
                    trialText: trialText(for: package)
                ) {
                    Haptics.selection()
                    selectedIdentifier = package.identifier
                    trackPaywall(.planSelected, package: package)
                    errorMessage = nil
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private func exitOfferPlan(_ package: Package) -> some View {
        VStack(spacing: 10) {
            Text(L10n.text("PRIVATE OFFER"))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(L10n.isRightToLeft ? 0 : 1.2)
                .foregroundStyle(Color(rgb: 0x301B1A))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(JoyColors.coral, in: Capsule())

            ExitOfferAnnualCard(
                package: package,
                originalPrice: exitOriginalPrice,
                trialText: trialText(for: package),
                selected: isExitPackageSelected
            ) {
                Haptics.selection()
                selectedIdentifier = package.identifier
                trackPaywall(.planSelected, package: package)
                errorMessage = nil
            }

            ForEach([weeklyPackage, monthlyPackage].compactMap { $0 }, id: \.identifier) { standardPackage in
                PaywallPlanCard(
                    package: standardPackage,
                    kind: planKind(for: standardPackage),
                    selected: selectedPackage?.identifier == standardPackage.identifier,
                    savings: nil,
                    trialText: trialText(for: standardPackage)
                ) {
                    Haptics.selection()
                    selectedIdentifier = standardPackage.identifier
                    trackPaywall(.planSelected, package: standardPackage)
                    errorMessage = nil
                }
            }

            accessSummary
                .padding(.horizontal, -20)
                .padding(.top, 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var accessSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.text("INCLUDED IN EVERY PLAN"))
                    .appFont(.overline)
                    .foregroundStyle(JoyColors.mint)
                Spacer()
                Text(L10n.text("5 / DAY"))
                    .appFont(.mono, tabularNumbers: true)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text(L10n.text("5 face analyses every 24 hours"))
                .appFont(.bodyStrong)
                .foregroundStyle(AppColors.textPrimary)

            Text(L10n.text("Your allowance renews every 24 hours. A subscription is required; there are no free analyses."))
                .appFont(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(AppColors.bgSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(JoyColors.mint)
            Text(L10n.text("Loading plans…"))
                .appFont(.caption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(minHeight: 270)
    }

    private var unavailableState: some View {
        VStack(spacing: 10) {
            Text(L10n.text("Plans are temporarily unavailable"))
                .appFont(.h3)
                .foregroundStyle(AppColors.textPrimary)

            Text(L10n.text("Your purchases are safe. Please try loading the App Store plans again."))
                .appFont(.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            Button(L10n.text("Try again")) {
                Task { await reloadPackages() }
            }
            .appFont(.bodyStrong)
            .foregroundStyle(JoyColors.mint)
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(AppColors.bgSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(AppColors.borderSubtle, lineWidth: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var legalCopy: some View {
        VStack(spacing: 9) {
            Text(L10n.text("Payment is charged to your App Store account after confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the current period ends."))
                .font(.system(size: 10.5, weight: .regular))
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(L10n.text("Terms of Use"), destination: LegalLinks.terms)
                Link(L10n.text("Privacy Policy"), destination: LegalLinks.privacy)
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 28)
    }

    private var purchaseBar: some View {
        VStack(spacing: 9) {
            PrimaryButton(title: purchaseButtonTitle, isLoading: busy) {
                purchase()
            }
            .disabled(selectedPackage == nil || busy)

            Button(L10n.text("Restore Purchases")) {
                restore()
            }
            .appFont(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .disabled(busy)

        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.borderMuted)
                .frame(height: 1)
        }
    }

    private var purchaseButtonTitle: String {
        guard let package = selectedPackage else { return L10n.text("Continue") }
        if isExitPackageSelected {
            if trialText(for: package) != nil {
                return L10n.text("Claim 50% off · start trial")
            }
            return L10n.text("Claim my 50% off")
        }
        if trialText(for: package) != nil {
            return L10n.text("Start free trial")
        }
        return L10n.text("Continue with \(planKind(for: package).title)")
    }

    private func refreshPackagesIfNeeded() async {
        if allPackages.isEmpty {
            await reloadPackages()
        } else {
            chooseDefaultPackage()
            await refreshIntroEligibility()
            trackPlans()
        }
    }

    private func reloadPackages() async {
        isLoading = true
        errorMessage = nil
        await entitlementsModel.loadOfferings()
        isLoading = false
        chooseDefaultPackage()
        await refreshIntroEligibility()
        trackPlans()
    }

    private func chooseDefaultPackage() {
        if displaysExitOffer, let activeExitAnnualPackage {
            selectedIdentifier = activeExitAnnualPackage.identifier
            return
        }
        guard selectedIdentifier == nil || !packageIdentifiers.contains(selectedIdentifier ?? "") else { return }
        selectedIdentifier = annualPackage?.identifier
            ?? monthlyPackage?.identifier
            ?? weeklyPackage?.identifier
            ?? packages.first?.identifier
    }

    private func planKind(for package: Package) -> PaywallPlanKind {
        switch package.packageType {
        case .annual: return .yearly
        case .monthly: return .monthly
        case .weekly: return .weekly
        default: return .monthly
        }
    }

    private func trialText(for package: Package) -> String? {
        #if DEBUG
        // Test Store does not always bridge its configured trial into
        // StoreProduct.introductoryDiscount. Keep screenshot/UI previews
        // faithful to the dashboard without affecting App Store builds.
        if !RevenueCatConfig.usesAppStore,
           (package.packageType == .annual
            || package.storeProduct.productIdentifier == PaywallExitOffer.annualProductID) {
            return L10n.text("Free trial: \(L10n.duration(7, unit: .day))")
        }
        #endif

        guard let discount = package.storeProduct.introductoryDiscount,
              discount.paymentMode == .freeTrial,
              introEligibility[package.storeProduct.productIdentifier] == .eligible else { return nil }

        let period = discount.subscriptionPeriod
        let total = period.value * max(discount.numberOfPeriods, 1)
        let duration: String
        switch period.unit {
        case .day: duration = L10n.duration(total, unit: .day)
        case .week: duration = L10n.duration(total * 7, unit: .day)
        case .month: duration = L10n.duration(total, unit: .month)
        case .year: duration = L10n.duration(total, unit: .year)
        @unknown default: duration = L10n.duration(total, unit: .day)
        }
        return L10n.text("Free trial: \(duration)")
    }

    private func refreshIntroEligibility() async {
        let trialProducts = allPackages.filter {
            $0.storeProduct.introductoryDiscount?.paymentMode == .freeTrial
        }
        guard !trialProducts.isEmpty else {
            introEligibility = [:]
            return
        }

        #if DEBUG
        // RevenueCat Test Store products carry their configured free-trial
        // metadata, but Apple's receipt-based eligibility API has no App Store
        // receipt to inspect. Treat those synthetic products as eligible so
        // Debug previews mirror the configured acquisition flow. Release
        // builds always use Apple's real eligibility result below.
        if !RevenueCatConfig.usesAppStore {
            introEligibility = Dictionary(
                uniqueKeysWithValues: trialProducts.map {
                    ($0.storeProduct.productIdentifier, IntroEligibilityStatus.eligible)
                }
            )
            return
        }
        #endif

        let productIDs = trialProducts.map(\.storeProduct.productIdentifier)
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: productIDs
        )
        introEligibility = result.mapValues { $0.status }
    }

    private func purchase() {
        guard let package = selectedPackage, !busy else { return }
        busy = true
        errorMessage = nil
        Haptics.heavy()
        let purchaseContext = analyticsProperties(package: package)
        AppAnalytics.shared.track(.purchaseStarted, purchaseContext)

        Task {
            defer { busy = false }
            do {
                let completed = try await entitlementsModel.purchase(package)
                var outcome = purchaseContext
                outcome["has_access"] = entitlementsModel.hasAccess
                outcome["period_type"] = entitlementsModel.analyticsPeriodType
                outcome["is_sandbox"] = entitlementsModel.analyticsIsSandbox
                AppAnalytics.shared.track(completed ? .purchaseCompleted : .purchaseCancelled, outcome)
                if completed && dismissable { dismiss() }
            } catch {
                var outcome = purchaseContext
                outcome["error_code"] = (error as NSError).code
                AppAnalytics.shared.track(.purchaseFailed, outcome)
                errorMessage = L10n.text("Purchase couldn't be completed. Please try again.")
            }
        }
    }

    private func restore() {
        guard !busy else { return }
        busy = true
        errorMessage = nil
        trackPaywall(.restoreStarted)

        Task {
            defer { busy = false }
            do {
                let restored = try await entitlementsModel.restorePurchases()
                trackPaywall(.restoreCompleted, extra: ["has_access": restored])
                if restored {
                    if dismissable { dismiss() }
                } else {
                    errorMessage = L10n.text("No active purchases were found for this App Store account.")
                }
            } catch {
                trackPaywall(.restoreFailed, extra: ["error_code": (error as NSError).code])
                errorMessage = L10n.text("Purchases couldn't be restored. Please try again.")
            }
        }
    }

    private func handleClose() {
        guard dismissable else { return }
        guard !showsExitMascot else { return }
        trackPaywall(.paywallClose)

        if displaysExitOffer {
            trackPaywall(.offerWarning)
            showsExitWarning = true
            return
        }

        guard allowsExitOffer else {
            finishExit()
            return
        }

        if let activeExitAnnualPackage {
            revealExitOfferWithMascot(activeExitAnnualPackage)
            return
        }

        // A slow StoreKit response must never silently skip the private offer.
        // Refresh once and reveal only RevenueCat's real discounted SKU.
        Task {
            await reloadPackages()
            if let package = activeExitAnnualPackage {
                revealExitOfferWithMascot(package)
            } else {
                trackPaywall(.offerUnavailable)
                errorMessage = L10n.text("The private offer is still loading. Please try again in a moment.")
            }
        }
    }

    private func revealExitOfferWithMascot(_ package: Package) {
        trackPaywall(.offerIntro, package: package)
        pendingExitPackage = package
        exitDialogue = MiroDialogueProgress(count: 2)
        Haptics.selection()
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
            showsExitMascot = true
        }
    }

    private func advanceExitDialogue(expectedIndex: Int) {
        guard showsExitMascot else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            switch exitDialogue.advance(from: expectedIndex) {
            case .ignored: return
            case .next: Haptics.selection()
            case .finished:
                guard let package = pendingExitPackage else {
                    showsExitMascot = false
                    return
                }
                isShowingExitOffer = true
                selectedIdentifier = package.identifier
                showsExitMascot = false
                pendingExitPackage = nil
                trackPaywall(.offerViewed, package: package)
            }
        }
    }

    private func finishExit() {
        trackPaywall(.paywallLeft, extra: ["destination": onExit == nil ? "previous_screen" : "onboarding_scan"])
        UserDefaults.standard.set(true, forKey: PaywallExitOffer.consumedKey)
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }
    private func analyticsProperties(package: Package? = nil) -> [String: Any] {
        var data: [String: Any] = ["source": source, "paywall_visit_id": analyticsVisitID,
                                  "variant": displaysExitOffer ? "private_offer" : "standard"]
        if let offering = entitlementsModel.currentOffering { data["offering_id"] = offering.identifier }
        if let package = package ?? selectedPackage {
            // Private-offer packages can belong to a different offering than
            // `current`; attribute the interaction to the actual package.
            data["offering_id"] = package.presentedOfferingContext.offeringIdentifier
            data["product_id"] = package.storeProduct.productIdentifier
            data["package_id"] = package.identifier
            data["price"] = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
            data["currency"] = package.storeProduct.currencyCode ?? "unknown"
            data["trial_eligible"] = trialText(for: package) != nil
        }
        return data
    }

    private func trackPaywall(_ event: AnalyticsEvent, package: Package? = nil, extra: [String: Any] = [:]) {
        AppAnalytics.shared.track(event, analyticsProperties(package: package).merging(extra) { _, new in new })
    }

    private func trackPlans() {
        trackPaywall(packages.isEmpty ? .plansFailed : .plansLoaded, extra: [
            "product_count": packages.count, "available_product_ids": packages.map { $0.storeProduct.productIdentifier }
        ])
    }
}

private enum PaywallPlanKind: Equatable {
    case yearly
    case weekly
    case monthly

    var title: String {
        switch self {
        case .yearly: return L10n.text("Yearly")
        case .weekly: return L10n.text("Weekly")
        case .monthly: return L10n.text("Monthly")
        }
    }

    var cadence: String {
        switch self {
        case .yearly: return L10n.text("year")
        case .weekly: return L10n.text("week")
        case .monthly: return L10n.text("month")
        }
    }
}

private struct PaywallPlanCard: View {
    let package: Package
    let kind: PaywallPlanKind
    let selected: Bool
    let savings: Int?
    let trialText: String?
    let onTap: () -> Void

    private var isYearly: Bool { kind == .yearly }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: isYearly ? 12 : 7) {
                if isYearly {
                    HStack(spacing: 7) {
                        badge(L10n.text("BEST VALUE"), color: JoyColors.lemon, ink: Color(rgb: 0x252014))
                        if let savings {
                            badge(L10n.text("SAVE \(savings)%"), color: JoyColors.mint, ink: Color(rgb: 0x10241B))
                        }
                        Spacer(minLength: 0)
                    }
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(kind.title.uppercased(with: L10n.locale))
                            .appFont(.overline)
                            .foregroundStyle(selected ? JoyColors.mint : AppColors.textSecondary)

                        Text(priceLine)
                            .appFont(isYearly ? .h2 : .h3, tabularNumbers: true)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.78)

                        Text(detailLine)
                            .appFont(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Circle()
                        .strokeBorder(selected ? JoyColors.mint : AppColors.borderSubtle, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if selected {
                                Circle()
                                    .fill(JoyColors.mint)
                                    .frame(width: 11, height: 11)
                            }
                        }
                }
            }
            .padding(isYearly ? 17 : 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selected ? AppColors.bgSurfaceElevated : AppColors.bgSurface,
                in: RoundedRectangle(cornerRadius: isYearly ? 20 : 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: isYearly ? 20 : 16, style: .continuous)
                    .strokeBorder(selected ? JoyColors.mint : AppColors.borderSubtle, lineWidth: selected ? 1.8 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var priceLine: String {
        let price = package.storeProduct.localizedPriceString
        if let trialText {
            return L10n.text("\(trialText), then \(recurringPrice(price))")
        }
        return recurringPrice(price)
    }

    private func recurringPrice(_ price: String) -> String {
        switch kind {
        case .yearly: return L10n.text("\(price) per year")
        case .weekly: return L10n.text("\(price) per week")
        case .monthly: return L10n.text("\(price) per month")
        }
    }

    private var detailLine: String {
        if isYearly, let monthly = package.storeProduct.localizedPricePerMonth {
            return L10n.text("Just \(monthly) per month · Renews annually")
        }
        switch kind {
        case .yearly: return L10n.text("Renews annually. Cancel anytime.")
        case .weekly: return L10n.text("Flexible access. Cancel anytime.")
        case .monthly: return L10n.text("Renews monthly. Cancel anytime.")
        }
    }

    private var accessibilityText: String {
        var values = [kind.title, priceLine, detailLine]
        if isYearly { values.insert(L10n.text("Best value"), at: 0) }
        if let savings { values.append(L10n.text("Save \(savings) percent")) }
        return values.joined(separator: ", ")
    }

    private func badge(_ text: String, color: Color, ink: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .tracking(L10n.isRightToLeft ? 0 : 0.5)
            .foregroundStyle(ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}

private struct ExitOfferAnnualCard: View {
    let package: Package
    let originalPrice: String?
    let trialText: String?
    let selected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    badge(L10n.text("BEST VALUE"), color: JoyColors.lemon, ink: Color(rgb: 0x252014))
                    badge(L10n.text("50% OFF"), color: JoyColors.coral, ink: Color(rgb: 0x261516))
                    Spacer(minLength: 0)
                }

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.text("YEARLY"))
                            .appFont(.overline)
                            .foregroundStyle(JoyColors.coral)

                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            if let originalPrice {
                                Text(originalPrice)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(JoyColors.coral.opacity(0.82))
                                    .strikethrough(true, color: JoyColors.coral)
                            }

                            Text(L10n.text("\(package.storeProduct.localizedPriceString) per year"))
                                .appFont(.h2, tabularNumbers: true)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .minimumScaleFactor(0.7)
                        }

                        Text(trialText.map { L10n.text("\($0), then renews annually") }
                             ?? L10n.text("Renews annually. Cancel anytime."))
                            .appFont(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 8)

                    Circle()
                        .strokeBorder(selected ? JoyColors.coral : AppColors.borderSubtle, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .overlay {
                            if selected {
                                Circle()
                                    .fill(JoyColors.coral)
                                    .frame(width: 11, height: 11)
                            }
                        }
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.bgSurfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(JoyColors.coral, lineWidth: selected ? 2.4 : 1.5)
            }
            .shadow(color: JoyColors.coral.opacity(selected ? 0.2 : 0.09), radius: 16, y: 7)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.text("Private 50 percent off yearly offer, \(originalPrice ?? L10n.text("standard price")) reduced to \(package.storeProduct.localizedPriceString)"))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func badge(_ text: String, color: Color, ink: Color) -> some View {
        Text(text)
            .font(.system(size: 9.5, weight: .bold))
            .tracking(L10n.isRightToLeft ? 0 : 0.5)
            .foregroundStyle(ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color, in: Capsule())
    }
}

private struct ExitOfferMascotMoment: View {
    let isSmiling: Bool
    let onContinue: () -> Void

    private var message: String {
        isSmiling
            ? L10n.text("I’d love to keep going with you. Here’s a lower yearly price.")
            : L10n.text("Leaving already? You’ve got so much to work with. One last thing…")
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.92)
                VStack(spacing: 0) {
                    Spacer(minLength: 30)
                    MiroCompanion(
                        message: message,
                        expression: isSmiling ? .laugh : .sad,
                        size: min(280, proxy.size.height * 0.34),
                        stacked: true
                    )
                    .frame(maxWidth: 350)
                    .padding(.horizontal, 28)
                    Spacer(minLength: 30)
                    HStack(spacing: 9) {
                        Text(isSmiling ? L10n.text("Tap anywhere to see my offer") : L10n.text("Tap anywhere to continue"))
                        Image(systemName: "arrow.forward")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 28) + 24)
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                Button(action: onContinue) { Color.clear.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(message)
                    .accessibilityHint(isSmiling ? L10n.text("Tap anywhere to see my offer") : L10n.text("Tap anywhere to continue"))
                    .accessibilityIdentifier("miro.offer.surface")
            }
        }
    }
}

private struct PaywallBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(JoyColors.mint.opacity(0.08))
                .frame(width: 260, height: 260)
                .blur(radius: 2)
                .offset(x: proxy.size.width - 150, y: -115)

            Circle()
                .fill(JoyColors.sky.opacity(0.05))
                .frame(width: 220, height: 220)
                .offset(x: -115, y: proxy.size.height * 0.46)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
