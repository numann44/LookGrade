import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case story
    case baseline
    case bridge
    case name
    case goals
    case focus
    case confidence
    case profile
    case trajectory
    case privacy
    case ready
}

private enum OnboardingGoal: String, CaseIterable, Identifiable, Hashable {
    case understand
    case improve
    case track
    case guidance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .understand: return L10n.text("Find my score")
        case .improve: return L10n.text("Look better")
        case .track: return L10n.text("Track my progress")
        case .guidance: return L10n.text("Build my routine")
        }
    }

    var color: Color {
        switch self {
        case .understand: return AppColors.score(for: .symmetry)
        case .improve: return AppColors.score(for: .skin)
        case .track: return AppColors.score(for: .eyes)
        case .guidance: return AppColors.accentPrimary
        }
    }
}

private enum OnboardingFocus: String, CaseIterable, Identifiable {
    case skin
    case balance
    case definition
    case harmony

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skin: return L10n.text("Skin")
        case .balance: return L10n.text("Balance")
        case .definition: return L10n.text("Definition")
        case .harmony: return L10n.text("Harmony")
        }
    }

    var detail: String {
        switch self {
        case .skin: return L10n.text("Texture & tone")
        case .balance: return L10n.text("Feature balance")
        case .definition: return L10n.text("Shape & structure")
        case .harmony: return L10n.text("The whole picture")
        }
    }

    var color: Color {
        switch self {
        case .skin: return AppColors.score(for: .skin)
        case .balance: return AppColors.score(for: .symmetry)
        case .definition: return AppColors.score(for: .jawline)
        case .harmony: return AppColors.accentPrimary
        }
    }
}

/// Eight-step, locally personalized onboarding. The hand-off remains the same:
/// finishing or skipping presents RootView's existing consent screen.
struct OnboardingScreen: View {
    var onFinish: () -> Void

    @Environment(AppPrefsModel.self) private var appPrefs
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .story
    @State private var isMovingForward = true
    @State private var name = ""
    @State private var selectedGoals: Set<OnboardingGoal> = []
    @State private var selectedFocus: OnboardingFocus?
    @State private var confidence = 0.55
    @State private var buildPhase = 0
    @State private var profileReady = false
    @State private var didHydrate = false
    @State private var guideTargetKey: String?
    @State private var reaction = ""
    @StateObject private var miroController = MiroMascotController()
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                DarkOnboardingPalette.background.ignoresSafeArea()

                if step == .story {
                    DarkStoryStep(controller: miroController, onContinue: advance)
                } else if step == .bridge {
                    DarkBridgeStep(controller: miroController, onContinue: advance)
                } else {
                VStack(spacing: 0) {
                    if showsNavigation {
                        DarkOnboardingHeader(
                            step: step.rawValue,
                            count: OnboardingStep.allCases.count,
                            onBack: goBack,
                            onSkip: finish
                        )
                    }

                    ZStack {
                        ScrollView(showsIndicators: false) {
                            stepContent
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                                .frame(
                                    minHeight: max(
                                        proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom - 190,
                                        430
                                    ),
                                    alignment: .center
                                )
                                .padding(.horizontal, 22)
                                .padding(.vertical, 12)
                        }
                        .scrollDismissesKeyboard(.interactively)
                    }
                    .clipped()

                    if showsFooter {
                        Text(reaction.isEmpty ? L10n.text("You’ve got this. I’m here with you.") : reaction)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(rgb: 0xB9D8C8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .frame(minHeight: 34)
                            .contentTransition(.opacity)
                            .accessibilityAddTraits(.updatesFrequently)
                        DarkOnboardingFooter(
                            title: footerTitle,
                            isEnabled: canAdvance,
                            showsLoading: step == .profile && !profileReady,
                            action: advance
                        )
                        .opacity(step == .name && nameFieldFocused ? 0 : 1)
                        .allowsHitTesting(!(step == .name && nameFieldFocused))
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom, 12))
                    }
                }
                .overlayPreferenceValue(MiroTargetPreferenceKey.self) { targets in
                    GeometryReader { guideProxy in
                        if step != .story {
                            OnboardingMiroGuide(
                                controller: miroController,
                                step: step,
                                targetKey: guideTargetKey,
                                confidence: confidence,
                                targets: targets,
                                proxy: guideProxy
                            )
                            .transition(.scale(scale: 0.82).combined(with: .opacity))
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            }
            // Keep the onboarding canvas fixed when the keyboard appears.
            // The name field stays in the upper half and exposes its own
            // keyboard Continue action, so nothing jumps or compresses.
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .preferredColorScheme(.dark)
        .analyticsScreen("onboarding_\(String(describing: step))")
        .onAppear {
            hydrateStoredProfile()
            miroController.setReducedMotion(reduceMotion)
            updateGuide(for: step, shouldWake: true)
        }
        .onChange(of: step) { _, newStep in
            updateGuide(for: newStep, shouldWake: false)
        }
        .onChange(of: confidence) { _, _ in
            guard step == .confidence, !reduceMotion else { return }
            guideTargetKey = "confidence-slider"
            miroController.look(y: -0.76)
            miroController.express(.curious)
            reaction = confidence < 0.34 ? L10n.text("Start simple. Keep improving.") : confidence < 0.68 ? L10n.text("Your key strengths and your next steps.") : L10n.text("That’s the mindset. Let’s go deeper.")
        }
        .onChange(of: name) { _, value in
            guard step == .name else { return }
            miroController.look(x: -0.8)
            miroController.express(value.count >= 2 ? .grin : .curious)
            reaction = value.count >= 2 ? L10n.text("\(value). I like it. Let’s make this yours.") : L10n.text("What should I call you?")
        }
        .onChange(of: buildPhase) { _, newPhase in
            guard step == .profile, newPhase > 0 else { return }
            guideTargetKey = "speaker"
            miroController.express(newPhase == 3 ? .laugh : .curious)
            guard !reduceMotion else { return }
            miroController.look(x: -0.72)
            miroController.tap()
        }
        .onChange(of: reduceMotion) { _, enabled in
            miroController.setReducedMotion(enabled)
            updateGuide(for: step, shouldWake: false)
        }
        .task(id: step) {
            guard step == .profile, !profileReady else { return }
            await buildPersonalProfile()
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        Group {
            switch step {
            case .story:
                DarkStoryStep(controller: miroController, onContinue: advance)
            case .baseline:
                DarkBaselineStep()
            case .bridge:
                DarkBridgeStep(controller: miroController, onContinue: advance)
            case .name:
                DarkNameStep(name: $name, isFocused: $nameFieldFocused, onSubmit: advance)
            case .goals:
                DarkGoalsStep(
                    name: displayName,
                    selected: $selectedGoals,
                    onSelection: focusGuide(on:)
                )
            case .focus:
                DarkFocusStep(
                    name: displayName,
                    selected: $selectedFocus,
                    onSelection: focusGuide(on:)
                )
            case .confidence:
                DarkConfidenceStep(name: displayName, value: $confidence)
            case .profile:
                DarkProfileStep(
                    name: displayName,
                    focus: selectedFocus,
                    goalCount: selectedGoals.count,
                    phase: buildPhase,
                    isReady: profileReady
                )
            case .trajectory:
                DarkTrajectoryStep()
            case .privacy:
                DarkPrivacyStep()
            case .ready:
                DarkReadyStep(name: displayName)
            }
        }
        .id(step.rawValue)
        .transition(stepTransition)
    }

    private var stepTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: isMovingForward ? 12 : -8)),
            removal: .opacity
        )
    }

    private var showsNavigation: Bool {
        step != .story && step != .bridge
    }

    private var showsFooter: Bool {
        step != .story && step != .bridge
    }

    private var canAdvance: Bool {
        switch step {
        case .story, .baseline, .bridge, .confidence, .trajectory, .privacy, .ready: return true
        case .name: return name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
        case .goals: return !selectedGoals.isEmpty
        case .focus: return selectedFocus != nil
        case .profile: return profileReady
        }
    }

    private var footerTitle: String {
        switch step {
        case .story: return L10n.text("Get started")
        case .profile where !profileReady: return L10n.text("Preparing your profile")
        case .ready: return L10n.text("Review privacy")
        default: return L10n.text("Continue")
        }
    }

    private var displayName: String {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean
    }

    private func advance() {
        guard canAdvance else { return }
        trackAction("continue")
        nameFieldFocused = false

        guard step != .ready else {
            finish()
            return
        }
        Haptics.selection()
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        isMovingForward = true
        withAnimation(reduceMotion ? .linear(duration: 0.01) : .premiumEase) {
            step = next
        }
    }

    private func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        trackAction("back")
        nameFieldFocused = false
        Haptics.selection()
        isMovingForward = false
        withAnimation(reduceMotion ? .linear(duration: 0.01) : .premiumEase) {
            step = previous
        }
    }

    private func finish() {
        AppAnalytics.shared.track(.onboardingCompleted, ["step": String(describing: step), "step_index": step.rawValue,
            "action": step == .ready ? "completed" : "skipped", "selection_count": selectedGoals.count,
            "has_name": !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty])
        nameFieldFocused = false
        appPrefs.saveOnboardingProfile(
            name: name,
            goals: selectedGoals.map(\.rawValue).sorted(),
            focus: selectedFocus?.rawValue ?? "",
            confidence: confidence
        )
        Haptics.selection()
        onFinish()
    }

    private func trackAction(_ action: String, selected: Bool = true) {
        AppAnalytics.shared.track(.onboardingAction, ["step": String(describing: step),
            "step_index": step.rawValue, "action": action, "selected": selected,
            "selection_count": selectedGoals.count])
    }

    private func updateGuide(for step: OnboardingStep, shouldWake: Bool) {
        guideTargetKey = defaultGuideTarget(for: step)
        reaction = ""
        miroController.express([.name, .goals, .focus, .confidence].contains(step) ? .curious : .grin)
        guard !reduceMotion else {
            miroController.look()
            return
        }

        miroController.look()
        switch step {
        case .story:
            if shouldWake { miroController.wake() }
        case .baseline:
            miroController.look(x: -0.65, y: 0.42)
        case .bridge:
            miroController.look(x: 0.72)
        case .name:
            miroController.look(x: -0.55, y: 0.62)
        case .goals, .focus:
            miroController.look(x: -0.72)
        case .confidence:
            miroController.look(y: -0.76)
        case .profile:
            miroController.blink()
        case .trajectory:
            miroController.look(x: -0.58, y: 0.32)
        case .privacy:
            miroController.look(x: -0.62, y: 0.45)
        case .ready:
            miroController.look(x: -0.45, y: 0.45)
            miroController.tap()
        }
    }

    private func defaultGuideTarget(for step: OnboardingStep) -> String? {
        switch step {
        case .story: return nil
        case .bridge: return "bridge-bubble"
        default: return "speaker"
        }
    }

    private func focusGuide(on goal: OnboardingGoal) {
        trackAction("goal_toggle", selected: selectedGoals.contains(goal))
        guideTargetKey = "goal-\(goal.rawValue)"
        if selectedGoals.contains(goal) {
            switch goal {
            case .understand: reaction = L10n.text("Know your score. Build from there.")
            case .improve: reaction = L10n.text("You already look great. Let’s build on that, together.")
            case .track: reaction = L10n.text("I’ll be here to celebrate your progress with you.")
            case .guidance: reaction = L10n.text("A plan made around you. You deserve that.")
            }
        } else { reaction = L10n.text("Your goals. Your call.") }
        miroController.express(selectedGoals.contains(goal) ? .laugh : .curious)
        if selectedGoals.contains(goal) { miroController.wink() }
        guard !reduceMotion else { return }
        miroController.look(x: -0.76)
        miroController.tap()
    }

    private func focusGuide(on focus: OnboardingFocus) {
        trackAction("focus_selected")
        guideTargetKey = "focus-\(focus.rawValue)"
        reaction = displayName.isEmpty ? L10n.text("\(focus.title) first. Let’s build on your strengths.") : L10n.text("\(focus.title) first. I like your focus, \(displayName).")
        miroController.express(.grin)
        miroController.wink()
        guard !reduceMotion else { return }
        miroController.look(x: -0.72, y: -0.48)
        miroController.tap()
    }

    private func hydrateStoredProfile() {
        guard !didHydrate else { return }
        didHydrate = true
        name = appPrefs.onboardingName
        selectedGoals = Set(appPrefs.onboardingGoals.compactMap(OnboardingGoal.init(rawValue:)))
        selectedFocus = OnboardingFocus(rawValue: appPrefs.onboardingFocus)
        confidence = appPrefs.onboardingConfidence

        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["FACERATE_ONBOARDING_STEP"].flatMap(Int.init),
           let previewStep = OnboardingStep(rawValue: raw) {
            step = previewStep
            if selectedGoals.isEmpty { selectedGoals = [.understand, .track] }
            if selectedFocus == nil { selectedFocus = .harmony }
        }
        #endif
    }

    @MainActor
    private func buildPersonalProfile() async {
        let delay: UInt64 = reduceMotion ? 120_000_000 : 620_000_000
        if buildPhase < 3 {
            for phase in (buildPhase + 1)...3 {
                do {
                    try await Task.sleep(nanoseconds: delay)
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? .linear(duration: 0.01) : .premiumEase) {
                    buildPhase = phase
                }
            }
        }

        do {
            try await Task.sleep(nanoseconds: reduceMotion ? 80_000_000 : 260_000_000)
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        withAnimation(reduceMotion ? .linear(duration: 0.01) : .spring(response: 0.55, dampingFraction: 0.82)) {
            profileReady = true
        }
        Haptics.success()
    }
}

private struct MiroTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}

private extension View {
    func miroTarget(_ key: String) -> some View {
        anchorPreference(key: MiroTargetPreferenceKey.self, value: .bounds) { [key: $0] }
    }
}

/// A single persistent mascot travels between the real bounds of controls.
/// It stays out of hit-testing so every onboarding button keeps its original
/// interaction behavior even while Miro visually overlaps a card edge.
private struct OnboardingMiroGuide: View {
    let controller: MiroMascotController
    let step: OnboardingStep
    let targetKey: String?
    let confidence: Double
    let targets: [String: Anchor<CGRect>]
    let proxy: GeometryProxy

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var size: CGFloat { step == .bridge ? 200 : 158 }

    var body: some View {
        MiroMascotView(controller: controller, attention: targetKey == "confidence-slider" ? .up : .left)
            .frame(width: size, height: size)
            .position(position)
            .shadow(color: Color.black.opacity(0.22), radius: 12, y: 7)
            .animation(reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.72), value: targetKey)
            .animation(reduceMotion ? nil : .interactiveSpring(response: 0.38, dampingFraction: 0.82), value: confidence)
            .accessibilityHidden(true)
    }

    private var targetRect: CGRect? {
        guard let targetKey, let anchor = targets[targetKey] else { return nil }
        return proxy[anchor]
    }

    private var position: CGPoint {
        let fallback = CGPoint(x: L10n.isRightToLeft ? 62 : proxy.size.width - 62, y: proxy.size.height * 0.27)
        guard let rect = targetRect else { return fallback }

        let proposed: CGPoint
        if targetKey == "speaker" {
            proposed = CGPoint(x: L10n.isRightToLeft ? rect.minX + 48 : rect.maxX - 48, y: rect.midY + 20)
        } else if step == .bridge {
            proposed = CGPoint(x: rect.midX, y: rect.maxY + 118)
        } else if step == .confidence {
            proposed = CGPoint(x: rect.minX + CGFloat(L10n.isRightToLeft ? 1 - confidence : confidence) * rect.width, y: rect.maxY + 64)
        } else {
            proposed = CGPoint(x: L10n.isRightToLeft ? rect.minX - 40 : rect.maxX + 40, y: rect.midY)
        }

        let margin = size * 0.48
        return CGPoint(
            x: min(max(proposed.x, margin), proxy.size.width - margin),
            y: min(max(proposed.y, margin + 70), proxy.size.height - margin - 116)
        )
    }
}

private enum DarkOnboardingPalette {
    static let background = Color(rgb: 0x111212)
    static let surface = Color(rgb: 0x191A1A)
    static let surfaceRaised = Color(rgb: 0x212222)
    static let line = Color.white.opacity(0.10)
    static let text = Color(rgb: 0xF5F5F1)
    static let muted = Color(rgb: 0x999B98)
    static let faint = Color(rgb: 0x626461)
    static let blue = Color(rgb: 0x3D8BFF)
}

private struct DarkOnboardingHeader: View {
    let step: Int
    let count: Int
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DarkOnboardingPalette.text)
                        .frame(width: 42, height: 42, alignment: .leading)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(L10n.text("Skip"), action: onSkip)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DarkOnboardingPalette.faint)
                    .frame(minWidth: 42, minHeight: 42, alignment: .trailing)
                    .buttonStyle(.plain)
            }

            HStack(spacing: 5) {
                ForEach(0..<count, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? DarkOnboardingPalette.text : DarkOnboardingPalette.line)
                        .frame(height: 3)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 3)
    }
}

private struct DarkOnboardingFooter: View {
    let title: String
    let isEnabled: Bool
    let showsLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if showsLoading {
                    ProgressView().tint(DarkOnboardingPalette.background).controlSize(.small)
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(DarkOnboardingPalette.background)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(DarkOnboardingPalette.text, in: Capsule())
        }
        .buttonStyle(OnboardingPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.34)
        .animation(.easeOut(duration: 0.18), value: isEnabled)
    }
}

private struct DarkStoryStep: View {
    let controller: MiroMascotController
    let onContinue: () -> Void

    var body: some View {
        MiroDialogueScene(
            controller: controller,
            messages: [
                L10n.text("Hey, I’m Miro. You already look great."),
                L10n.text("Want to look even better? Let’s work on it together."),
                L10n.text("Your features. Your goals. I’ll help you make the most of both.")
            ],
            finalHint: L10n.text("Tap anywhere to get started"),
            onContinue: onContinue
        )
    }
}

/// This scene fills the viewport itself, rather than living in the question
/// scroll view. A single transparent button covers all app-owned screen space.
private struct MiroDialogueScene: View {
    let controller: MiroMascotController
    let messages: [String]
    let finalHint: String
    let onContinue: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.scenePhase) private var scenePhase
    @State private var dialogue = MiroDialogueProgress(count: 3)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
            VStack(spacing: 0) {
                Text(L10n.text("LOOKGRADE  /  MEET MIRO"))
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.7)
                    .foregroundStyle(DarkOnboardingPalette.muted)
                    .padding(.top, 24)

                VStack(spacing: 22) {
                    MiroSpeechBubble(text: messages[dialogue.index], tailEdge: .bottom)
                        .frame(maxWidth: 330)
                        .padding(.horizontal, 28)
                        .id(dialogue.index)
                        .transition(.opacity)
                    MiroMascotView(controller: controller, attention: .up)
                        .frame(width: mascotSize(proxy), height: mascotSize(proxy))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 18) {
                    HStack(spacing: 7) {
                        ForEach(0..<messages.count, id: \.self) { index in
                            Capsule().fill(index == dialogue.index ? Color(rgb: 0xB9D8C8) : DarkOnboardingPalette.line)
                                .frame(width: index == dialogue.index ? 22 : 6, height: 5)
                        }
                    }
                    HStack(spacing: 9) {
                        Text(dialogue.index == messages.count - 1 ? finalHint : L10n.text("Tap anywhere to continue"))
                        Image(systemName: "arrow.forward")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DarkOnboardingPalette.muted)
                }
                .padding(.bottom, 28)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
                Button { advance(expectedIndex: dialogue.index, source: "tap") } label: {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .accessibilityLabel(messages[dialogue.index])
                .accessibilityHint(dialogue.index == messages.count - 1 ? finalHint : L10n.text("Tap anywhere to continue"))
                .accessibilityIdentifier("miro.dialogue.surface")
            }
        }
        .task(id: "\(dialogue.index)-\(scenePhase)") {
            guard scenePhase == .active else { return }
            controller.express(dialogue.index == 1 ? .grin : .curious)
            if dialogue.index == 1 { controller.wink() }
            guard !voiceOverEnabled, dialogue.index < messages.count - 1 else { return }
            let expected = dialogue.index
            do { try await Task.sleep(for: .seconds(L10n.readingDelay(for: messages[dialogue.index]))) } catch { return }
            guard !Task.isCancelled else { return }
            advance(expectedIndex: expected, source: "automatic")
        }
    }

    private func mascotSize(_ proxy: GeometryProxy) -> CGFloat {
        min(300, proxy.size.width * 0.76, proxy.size.height * 0.40)
    }

    private func advance(expectedIndex: Int, source: String) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) {
            switch dialogue.advance(from: expectedIndex) {
            case .ignored: return
            case .next:
                AppAnalytics.shared.track(.onboardingAction, ["action": "dialogue_advance", "source": source, "step_index": expectedIndex])
                Haptics.selection()
            case .finished:
                AppAnalytics.shared.track(.onboardingAction, ["action": "dialogue_finish", "source": source, "step_index": expectedIndex])
                onContinue()
            }
        }
    }
}

private struct MiroSpeechBubble: View {
    enum TailEdge { case leading, bottom }

    let text: String
    var tailEdge: TailEdge = .bottom

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(DarkOnboardingPalette.background)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DarkOnboardingPalette.text, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: tailEdge == .leading ? .leading : .bottom) {
                MiroBubbleTail()
                    .fill(DarkOnboardingPalette.text)
                    .frame(width: 15, height: 18)
                    .rotationEffect(tailEdge == .leading ? .degrees(L10n.isRightToLeft ? -90 : 90) : .zero)
                    .offset(x: tailEdge == .leading ? (L10n.isRightToLeft ? 10 : -10) : 0, y: tailEdge == .bottom ? 11 : 0)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 10, y: 5)
            .contentTransition(.opacity)
    }
}

private struct MiroBubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DarkBaselineStep: View {
    @State private var animate = false
    private let rows: [(String, Double, Bool)] = [
        (L10n.text("Symmetry"), 0.84, true),
        (L10n.text("Skin quality"), 0.72, false),
        (L10n.text("Structure"), 0.64, false),
        (L10n.text("Feature harmony"), 0.78, false)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            DarkStepHeading(kicker: L10n.text("YOUR BASELINE"), title: L10n.text("Let’s meet your best features."), body: L10n.text("Eight areas, explained simply. Here’s a sample."))

            VStack(spacing: 19) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    VStack(spacing: 8) {
                        HStack {
                            Text(row.0)
                                .font(.system(size: 13, weight: row.2 ? .semibold : .regular))
                                .foregroundStyle(row.2 ? DarkOnboardingPalette.text : DarkOnboardingPalette.muted)
                            Spacer()
                            Text("0–10")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(DarkOnboardingPalette.faint)
                        }

                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(DarkOnboardingPalette.line)
                                Capsule()
                                    .fill(row.2 ? DarkOnboardingPalette.blue : DarkOnboardingPalette.text.opacity(0.78))
                                    .frame(width: animate ? proxy.size.width * row.1 : 5)
                            }
                        }
                        .frame(height: 8)
                    }
                    .animation(.easeOut(duration: 0.72).delay(Double(index) * 0.13), value: animate)
                }
            }
            .padding(20)
            .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DarkOnboardingPalette.line) }
            .miroTarget("baseline-card")

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.text("A baseline, not a verdict."))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DarkOnboardingPalette.text)
                Text(L10n.text("Scores help you notice patterns and track change over time."))
                    .font(.system(size: 13))
                    .foregroundStyle(DarkOnboardingPalette.muted)
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 16))
        }
        .onAppear {
            withAnimation { animate = true }
        }
    }
}

private struct DarkBridgeStep: View {
    let controller: MiroMascotController
    let onContinue: () -> Void

    var body: some View {
        MiroDialogueScene(
            controller: controller,
            messages: [
                L10n.text("You’ve got your own kind of good-looking. Let’s bring it out."),
                L10n.text("A little care. A few better habits. You, feeling even more confident."),
                L10n.text("Tell me what matters to you. We’ll make this personal.")
            ],
            finalHint: L10n.text("Tap anywhere to make it personal"),
            onContinue: onContinue
        )
    }
}

private struct DarkStepHeading: View {
    let kicker: String
    let title: String
    let bodyText: String

    init(kicker: String, title: String, body: String) {
        self.kicker = kicker
        self.title = title
        self.bodyText = body
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("MIRO · YOUR GLOW-UP GUIDE"))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(L10n.isRightToLeft ? 0 : 1.1)
                    .foregroundStyle(Color(rgb: 0xB9D8C8))
                Text(title)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .tracking(L10n.isRightToLeft ? 0 : -0.5)
                    .foregroundStyle(DarkOnboardingPalette.background)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DarkOnboardingPalette.text, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(alignment: .trailing) {
                        MiroBubbleTail().fill(DarkOnboardingPalette.text)
                            .frame(width: 14, height: 14)
                            .rotationEffect(.degrees(L10n.isRightToLeft ? 90 : -90)).offset(x: L10n.isRightToLeft ? -10 : 10)
                    }
                if !bodyText.isEmpty {
                    Text(bodyText)
                        .font(.system(size: 13))
                        .foregroundStyle(DarkOnboardingPalette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 102)
        }
        .frame(minHeight: 192)
        .miroTarget("speaker")
    }
}

private struct DarkNameStep: View {
    @Binding var name: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 42) {
            DarkStepHeading(kicker: L10n.text("YOUR REPORT"), title: L10n.text("What’s your name?"), body: L10n.text("Stored only on this device."))

            TextField(L10n.text("Your name"), text: $name)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(DarkOnboardingPalette.text)
                .tint(DarkOnboardingPalette.blue)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($isFocused)
                .onSubmit(onSubmit)
                .onChange(of: name) { _, value in
                    let clean = value.replacingOccurrences(of: "\n", with: " ")
                    name = String(clean.prefix(24))
                }
                .padding(.vertical, 13)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(isFocused ? DarkOnboardingPalette.text : DarkOnboardingPalette.line).frame(height: 1)
                }
                .miroTarget("name-field")

            Spacer(minLength: 160)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.text("Continue"), action: onSubmit)
                    .font(.system(size: 16, weight: .semibold))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }
        }
    }
}

private struct DarkGoalsStep: View {
    let name: String
    @Binding var selected: Set<OnboardingGoal>
    let onSelection: (OnboardingGoal) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            DarkStepHeading(
                kicker: L10n.text("SELECT ALL THAT APPLY"),
                title: name.isEmpty ? L10n.text("What’s your goal?") : L10n.text("What’s the goal, \(name)?"),
                body: L10n.text("Pick what you want to improve.")
            )
            .miroTarget("goals-heading")

            VStack(spacing: 10) {
                ForEach(OnboardingGoal.allCases) { goal in
                    Button {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.18)) {
                            if selected.contains(goal) { selected.remove(goal) } else { selected.insert(goal) }
                        }
                        onSelection(goal)
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .strokeBorder(selected.contains(goal) ? DarkOnboardingPalette.text : DarkOnboardingPalette.line, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if selected.contains(goal) {
                                        Circle().fill(DarkOnboardingPalette.text).frame(width: 10, height: 10)
                                    }
                                }
                            Text(goal.title)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(DarkOnboardingPalette.text)
                            Spacer()
                        }
                        .padding(.horizontal, 17)
                        .frame(minHeight: 61)
                        .background(selected.contains(goal) ? DarkOnboardingPalette.surfaceRaised : DarkOnboardingPalette.surface,
                                    in: RoundedRectangle(cornerRadius: 14))
                        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(selected.contains(goal) ? Color.white.opacity(0.25) : DarkOnboardingPalette.line) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected.contains(goal) ? .isSelected : [])
                    .miroTarget("goal-\(goal.rawValue)")
                }
            }
            .padding(.trailing, 84)
        }
    }
}

private struct DarkFocusStep: View {
    let name: String
    @Binding var selected: OnboardingFocus?
    let onSelection: (OnboardingFocus) -> Void
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            DarkStepHeading(
                kicker: L10n.text("STARTING POINT"),
                title: name.isEmpty ? L10n.text("Where first?") : L10n.text("Where first, \(name)?"),
                body: L10n.text("I’ll put your favorite area first.")
            )
            .miroTarget("focus-heading")

            VStack(spacing: 10) {
                ForEach(OnboardingFocus.allCases) { focus in
                    Button {
                        Haptics.selection()
                        withAnimation(.easeOut(duration: 0.2)) { selected = focus }
                        onSelection(focus)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(focus.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(DarkOnboardingPalette.text)
                                Text(focus.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(DarkOnboardingPalette.muted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: selected == focus ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected == focus ? Color(rgb: 0xB9D8C8) : DarkOnboardingPalette.faint)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 67, alignment: .leading)
                        .background(selected == focus ? DarkOnboardingPalette.surfaceRaised : DarkOnboardingPalette.surface,
                                    in: RoundedRectangle(cornerRadius: 16))
                        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(selected == focus ? Color.white.opacity(0.34) : DarkOnboardingPalette.line) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == focus ? .isSelected : [])
                    .miroTarget("focus-\(focus.rawValue)")
                }
            }
            .padding(.trailing, 84)
        }
    }
}

private struct DarkConfidenceStep: View {
    let name: String
    @Binding var value: Double

    private var title: String {
        switch value {
        case ..<0.34: return L10n.text("Keep it gentle")
        case ..<0.68: return L10n.text("Give me the essentials")
        default: return L10n.text("Show me the full picture")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            DarkStepHeading(
                kicker: L10n.text("YOUR PACE"),
                title: name.isEmpty ? L10n.text("What’s your vibe?") : L10n.text("What’s your vibe?"),
                body: L10n.text("A quick look or all the details?")
            )

            VStack(spacing: 27) {
                Text(title)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(DarkOnboardingPalette.text)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.opacity)

                Slider(value: $value, in: 0...1, onEditingChanged: { editing in
                    if !editing {
                        AppAnalytics.shared.track(.onboardingAction, ["action": "pace_adjusted", "step": "confidence"])
                    }
                })
                    .tint(DarkOnboardingPalette.text)
                    .miroTarget("confidence-slider")
                    .padding(.bottom, 110)

                HStack {
                    Text(L10n.text("Gentle"))
                    Spacer()
                    Text(L10n.text("Detailed"))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DarkOnboardingPalette.faint)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 26)
            .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DarkOnboardingPalette.line) }
        }
    }
}

private struct DarkProfileStep: View {
    let name: String
    let focus: OnboardingFocus?
    let goalCount: Int
    let phase: Int
    let isReady: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            DarkStepHeading(
                kicker: isReady ? L10n.text("PROFILE READY") : L10n.text("BUILDING YOUR PROFILE"),
                title: isReady ? (name.isEmpty ? L10n.text("Your personal plan!") : L10n.text("Your plan, \(name)!")) : L10n.text("One sec. Making it yours!"),
                body: isReady ? L10n.text("Your goals are set. Time to get started.") : ""
            )

            VStack(spacing: 10) {
                DarkProfileRow(number: "01", title: L10n.text("Priority"), value: focus?.title ?? L10n.text("Harmony"), visible: phase >= 1)
                    .miroTarget("profile-1")
                DarkProfileRow(number: "02", title: L10n.text("Goals"), value: L10n.text("\(max(goalCount, 1)) selected"), visible: phase >= 2)
                    .miroTarget("profile-2")
                DarkProfileRow(number: "03", title: L10n.text("Approach"), value: L10n.text("Private and measured"), visible: phase >= 3)
                    .miroTarget("profile-3")
            }

            if !isReady {
                HStack(spacing: 8) {
                    ProgressView().tint(DarkOnboardingPalette.text).controlSize(.small)
                    Text(L10n.text("Preparing your report order"))
                        .font(.system(size: 12))
                        .foregroundStyle(DarkOnboardingPalette.muted)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct DarkProfileRow: View {
    let number: String
    let title: String
    let value: String
    let visible: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(DarkOnboardingPalette.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased(with: L10n.locale))
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(L10n.isRightToLeft ? 0 : 1.1)
                    .foregroundStyle(DarkOnboardingPalette.faint)
                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(DarkOnboardingPalette.text)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 72)
        .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 15))
        .overlay { RoundedRectangle(cornerRadius: 15).strokeBorder(DarkOnboardingPalette.line) }
        .opacity(visible ? 1 : 0)
        .offset(y: visible ? 0 : 12)
        .animation(.easeOut(duration: 0.4), value: visible)
    }
}

private struct DarkTrajectoryStep: View {
    @State private var progress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            DarkStepHeading(kicker: L10n.text("OVER TIME"), title: L10n.text("Let’s see your hard work pay off."), body: L10n.text("Save your scans. See your story unfold."))

            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    Text(L10n.text("YOUR LOOKGRADE ROUTINE"))
                    Spacer()
                    Text(L10n.text("CONSISTENCY"))
                }
                .font(.system(size: 9, weight: .semibold))
                .tracking(L10n.isRightToLeft ? 0 : 0.8)
                .foregroundStyle(DarkOnboardingPalette.faint)

                ZStack {
                    ForEach(0..<4, id: \.self) { index in
                        Rectangle()
                            .fill(DarkOnboardingPalette.line)
                            .frame(height: 1)
                            .offset(y: CGFloat(index) * 39 - 58)
                    }

                    DarkTrajectoryCurve()
                        .trim(from: 0, to: progress)
                        .stroke(DarkOnboardingPalette.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .shadow(color: DarkOnboardingPalette.blue.opacity(0.32), radius: 8)
                }
                .frame(height: 176)

                HStack {
                    Text(L10n.text("First scan"))
                    Spacer()
                    Text(L10n.text("A clearer trend"))
                }
                .font(.system(size: 11))
                .foregroundStyle(DarkOnboardingPalette.muted)
            }
            .padding(18)
            .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DarkOnboardingPalette.line) }
            .miroTarget("trajectory-card")

            Text(L10n.text("Your score is a snapshot. Your history is the story."))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DarkOnboardingPalette.text)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2)) { progress = 1 }
        }
    }
}

private struct DarkTrajectoryCurve: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.height * 0.78))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.55, y: rect.height * 0.62),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.80),
            control2: CGPoint(x: rect.width * 0.42, y: rect.height * 0.77)
        )
        path.addCurve(
            to: CGPoint(x: rect.width, y: rect.height * 0.12),
            control1: CGPoint(x: rect.width * 0.72, y: rect.height * 0.54),
            control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.17)
        )
        return path
    }
}

private struct DarkPrivacyStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            DarkStepHeading(kicker: L10n.text("PRIVATE BY DEFAULT"), title: L10n.text("Your face stays yours."), body: L10n.text("Analysis stays on your phone. You’re in control."))

            VStack(spacing: 0) {
                DarkPrivacyRow(number: "01", title: L10n.text("Processed on your phone"), detail: L10n.text("Face analysis runs locally on this device."))
                Divider().overlay(DarkOnboardingPalette.line)
                DarkPrivacyRow(number: "02", title: L10n.text("Never sold or shared"), detail: L10n.text("Your scan is not used to build an ad profile."))
                Divider().overlay(DarkOnboardingPalette.line)
                DarkPrivacyRow(number: "03", title: L10n.text("Delete whenever"), detail: L10n.text("Saved scans remain under your control."))
            }
            .padding(.horizontal, 16)
            .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DarkOnboardingPalette.line) }
            .miroTarget("privacy-card")
        }
    }
}

private struct DarkPrivacyRow: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DarkOnboardingPalette.blue)
                .padding(.top, 3)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkOnboardingPalette.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(DarkOnboardingPalette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 16)
    }
}

private struct DarkReadyStep: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            DarkStepHeading(
                kicker: L10n.text("ONE LAST STEP"),
                title: name.isEmpty ? L10n.text("Ready for your close-up?") : L10n.text("Ready, \(name)?"),
                body: L10n.text("One selfie, then your preview. Pro unlocks the full report.")
            )

            VStack(spacing: 0) {
                DarkReadyRow(number: "01", title: L10n.text("Review privacy"))
                Divider().overlay(DarkOnboardingPalette.line)
                DarkReadyRow(number: "02", title: L10n.text("Take your first photo"))
                Divider().overlay(DarkOnboardingPalette.line)
                DarkReadyRow(number: "03", title: L10n.text("Unlock your full report"))
            }
            .padding(.horizontal, 16)
            .background(DarkOnboardingPalette.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(DarkOnboardingPalette.line) }
        }
    }
}

private struct DarkReadyRow: View {
    let number: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Text(number)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(DarkOnboardingPalette.faint)
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DarkOnboardingPalette.text)
            Spacer()
        }
        .frame(minHeight: 52)
    }
}

private struct OnboardingFlowHeader: View {
    let step: Int
    let count: Int
    let canGoBack: Bool
    let canSkip: Bool
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack {
            if canGoBack {
                Button(action: onBack) {
                    Text(L10n.text("Back"))
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(minWidth: 52, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.text("Back"))
            } else {
                Text("LookGrade")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(minWidth: 52, minHeight: 44, alignment: .leading)
            }

            Spacer()

            Text(L10n.text("\(step + 1) of \(count)"))
                .appFont(.caption, tabularNumbers: true)
                .foregroundStyle(AppColors.textTertiary)

            if canSkip {
                Button(L10n.text("Skip"), action: onSkip)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(minWidth: 52, minHeight: 44, alignment: .trailing)
                    .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 52, height: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }
}

private struct OnboardingFlowFooter: View {
    let title: String
    let isEnabled: Bool
    let isFinal: Bool
    let showsLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if showsLoading {
                    ProgressView()
                        .tint(AppColors.bgPrimary)
                        .controlSize(.small)
                }
                Text(title)
                    .appFont(.bodyStrong)
                if isFinal {
                    LucideIcon(name: "arrow-right", size: 18)
                }
            }
            .foregroundStyle(isFinal ? Color.white : AppColors.bgPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                if isFinal {
                    AppColors.accentGradient
                } else {
                    AppColors.textPrimary
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Color.white.opacity(isFinal ? 0.12 : 0.04), lineWidth: 1)
            }
        }
        .buttonStyle(OnboardingPressStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.34)
        .animation(.easeOut(duration: 0.2), value: isEnabled)
    }
}

private struct StepHeading: View {
    let eyebrow: String
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(eyebrow)
                .appFont(.caption)
                .foregroundStyle(AppColors.textTertiary)

            Text(title)
                .font(.system(size: 30, weight: .bold))
                .tracking(L10n.isRightToLeft ? 0 : -0.7)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(bodyText)
                .appFont(.body)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WelcomeStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepHeading(
                eyebrow: L10n.text("A clearer view"),
                title: L10n.text("A clearer look at you."),
                bodyText: L10n.text("Private, thoughtful, and made to be useful.")
            )

            OnboardingIntroVisual()
                .frame(height: 292)

            HStack(spacing: 0) {
                WelcomeFact(value: "8", label: L10n.text("areas"))
                WelcomeDivider()
                WelcomeFact(value: L10n.text("local"), label: L10n.text("analysis"))
                WelcomeDivider()
                WelcomeFact(value: L10n.text("quick"), label: L10n.text("first scan"))
            }
            .padding(.vertical, 15)
            .background(AppColors.bgSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(AppColors.borderMuted, lineWidth: 1)
            }
        }
    }
}

private struct WelcomeFact: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .appFont(.bodyStrong, tabularNumbers: true)
                .foregroundStyle(AppColors.textPrimary)
            Text(label)
                .appFont(.overline)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WelcomeDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.borderSubtle)
            .frame(width: 1, height: 31)
    }
}

private struct NameStep: View {
    @Binding var name: String
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            StepHeading(
                eyebrow: L10n.text("Your report"),
                title: L10n.text("What should we call you?"),
                bodyText: L10n.text("Your name makes the experience feel like yours. It stays on this device.")
            )

            VStack(alignment: .leading, spacing: 12) {
                TextField(L10n.text("Your name"), text: $name)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.continue)
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .onChange(of: name) { _, newValue in
                        let singleLine = newValue.replacingOccurrences(of: "\n", with: " ")
                        if singleLine.count > 24 {
                            name = String(singleLine.prefix(24))
                        } else if singleLine != newValue {
                            name = singleLine
                        }
                    }
                    .padding(.horizontal, 17)
                    .frame(height: 60)
                    .background(AppColors.bgSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(isFocused ? AppColors.accentPrimary : AppColors.borderSubtle, lineWidth: 1)
                    }

                HStack(spacing: 7) {
                    LucideIcon(name: "lock", size: 13)
                    Text(L10n.text("Stored locally and never added to your photo."))
                }
                .appFont(.caption)
                .foregroundStyle(AppColors.textTertiary)
            }

            Spacer(minLength: 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
                isFocused = true
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.text("Continue"), action: onSubmit)
                    .font(.system(size: 16, weight: .semibold))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }
        }
    }
}

private struct GoalsStep: View {
    @Binding var selected: Set<OnboardingGoal>
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            StepHeading(
                eyebrow: L10n.text("Make it yours"),
                title: L10n.text("What are you here for?"),
                bodyText: L10n.text("Pick every answer that feels true.")
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(OnboardingGoal.allCases) { goal in
                    GoalTile(
                        goal: goal,
                        isSelected: selected.contains(goal)
                    ) {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) {
                            if selected.contains(goal) {
                                selected.remove(goal)
                            } else {
                                selected.insert(goal)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct GoalTile: View {
    let goal: OnboardingGoal
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(goal.color.opacity(isSelected ? 0.96 : 0.42))
                            .frame(width: index == 1 ? 30 : 15, height: 7)
                            .offset(y: index == 1 ? -3 : 0)
                    }
                }

                Text(goal.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                Text(isSelected ? L10n.text("Selected") : L10n.text("Tap to choose"))
                    .appFont(.caption)
                    .foregroundStyle(isSelected ? goal.color : AppColors.textTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .background(
                isSelected ? AppColors.bgSurfaceElevated : AppColors.bgSurface,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(isSelected ? goal.color.opacity(0.92) : AppColors.borderMuted, lineWidth: 1)
            }
            .scaleEffect(isSelected ? 1 : 0.985)
        }
        .buttonStyle(.plain)
    }
}

private struct FocusStep: View {
    @Binding var selected: OnboardingFocus?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            StepHeading(
                eyebrow: L10n.text("First things first"),
                title: L10n.text("What should we notice first?"),
                bodyText: L10n.text("Your score stays objective. This only shapes the story around it.")
            )

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(OnboardingFocus.allCases) { focus in
                    FocusCard(focus: focus, isSelected: selected == focus) {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            selected = focus
                        }
                    }
                }
            }
        }
    }
}

private struct FocusCard: View {
    let focus: OnboardingFocus
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(focus.color)
                        .frame(width: isSelected ? 36 : 22, height: 9)
                    Spacer()
                    if isSelected {
                        Text("✓")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(focus.color)
                    }
                }

                Spacer(minLength: 2)

                Text(focus.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(focus.detail)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(
                isSelected ? AppColors.bgSurfaceElevated : AppColors.bgSurface,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isSelected ? focus.color : AppColors.borderMuted, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ConfidenceStep: View {
    @Binding var value: Double

    private enum ScanTone: CaseIterable, Identifiable {
        case gentle, clear, focused

        var id: String { title }
        var title: String {
            switch self {
            case .gentle: return L10n.text("Gently")
            case .clear: return L10n.text("Clearly")
            case .focused: return L10n.text("Deeply")
            }
        }
        var detail: String {
            switch self {
            case .gentle: return L10n.text("A relaxed first look")
            case .clear: return L10n.text("The useful essentials")
            case .focused: return L10n.text("More context over time")
            }
        }
        var value: Double {
            switch self {
            case .gentle: return 0.2
            case .clear: return 0.55
            case .focused: return 0.85
            }
        }
    }

    private var selectedTone: ScanTone {
        ScanTone.allCases.min(by: { abs($0.value - value) < abs($1.value - value) }) ?? .clear
    }

    private var label: String {
        switch value {
        case ..<0.34: return L10n.text("Mostly curious")
        case ..<0.68: return L10n.text("Ready to understand more")
        default: return L10n.text("Focused on progress")
        }
    }

    private var detail: String {
        switch value {
        case ..<0.34: return L10n.text("You want a clear baseline without pressure.")
        case ..<0.68: return L10n.text("You want context, priorities, and useful direction.")
        default: return L10n.text("You want to measure small changes over time.")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            StepHeading(
                eyebrow: L10n.text("Your pace"),
                title: L10n.text("How should your first report feel?"),
                bodyText: L10n.text("You can always change this later.")
            )

            VStack(spacing: 10) {
                ForEach(ScanTone.allCases) { tone in
                    Button {
                        Haptics.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                            value = tone.value
                        }
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(tone == selectedTone ? AppColors.accentPrimary : AppColors.bgSurfaceHigh)
                                .frame(width: 14, height: 14)
                                .overlay {
                                    Circle().strokeBorder(AppColors.borderSubtle, lineWidth: tone == selectedTone ? 0 : 1)
                                }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(tone.title)
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(tone.detail)
                                    .appFont(.caption)
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 17)
                        .frame(height: 76)
                        .background(tone == selectedTone ? AppColors.bgSurfaceElevated : AppColors.bgSurface,
                                    in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .strokeBorder(tone == selectedTone ? AppColors.accentPrimary : AppColors.borderMuted, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(detail)
                .appFont(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, 4)
        }
    }
}

private struct ProfileStep: View {
    let name: String
    let focus: OnboardingFocus?
    let goalCount: Int
    let phase: Int
    let isReady: Bool

    private var phaseText: String {
        switch phase {
        case 0: return L10n.text("Reading your goals")
        case 1: return L10n.text("Setting your pace")
        case 2: return L10n.text("Making it personal")
        default: return L10n.text("Ready when you are")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            StepHeading(
                eyebrow: isReady ? L10n.text("All set") : L10n.text("A moment"),
                title: isReady ? L10n.text("Made for \(name).") : L10n.text("Putting your choices together."),
                bodyText: isReady
                    ? L10n.text("Your report will lead with what matters to you.")
                    : ""
            )

            OnboardingBuildVisual(progress: Double(phase) / 3, isComplete: isReady)
                .frame(maxWidth: .infinity)
                .frame(height: 204)

            if isReady {
                VStack(spacing: 0) {
                    ProfileSummaryRow(icon: "scan-face", title: L10n.text("Start with"), value: focus?.title ?? L10n.text("Harmony"))
                    Rectangle().fill(AppColors.borderMuted).frame(height: 1).padding(.leading, 48)
                    ProfileSummaryRow(
                        icon: "check",
                        title: L10n.text("Your picks"),
                        value: goalCount == 1 ? L10n.text("1 priority") : L10n.text("\(max(goalCount, 1)) priorities")
                    )
                    Rectangle().fill(AppColors.borderMuted).frame(height: 1).padding(.leading, 48)
                    ProfileSummaryRow(icon: "trending-up", title: L10n.text("Your pace"), value: L10n.text("Clear and measured"))
                }
                .background(AppColors.bgSurface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AppColors.borderMuted, lineWidth: 1)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 10) {
                    Text(phaseText)
                        .appFont(.bodyStrong)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(L10n.text("Almost there."))
                        .appFont(.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct ProfileSummaryRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(AppColors.accentPrimary)
                .frame(width: 36, height: 36)
                .background(AppColors.accentPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                Text(value)
                    .appFont(.bodyStrong)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
    }
}

private struct PrivacyStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            StepHeading(
                eyebrow: L10n.text("Private by default"),
                title: L10n.text("Your face stays yours."),
                bodyText: L10n.text("Nothing complicated. You stay in control.")
            )

            OnboardingPrivacyVisual()
                .frame(maxWidth: .infinity)
                .frame(height: 178)

            VStack(spacing: 0) {
                PrivacyFact(icon: "smartphone", title: L10n.text("On your phone"), bodyText: L10n.text("Analysis happens locally."))
                Rectangle().fill(AppColors.borderMuted).frame(height: 1).padding(.leading, 52)
                PrivacyFact(icon: "shield", title: L10n.text("Not sold or shared"), bodyText: L10n.text("Your scan is not an ad profile."))
                Rectangle().fill(AppColors.borderMuted).frame(height: 1).padding(.leading, 52)
                PrivacyFact(icon: "trash-2", title: L10n.text("Delete whenever"), bodyText: L10n.text("Your saved scans are yours to remove."))
            }
            .background(AppColors.bgSurface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(AppColors.borderMuted, lineWidth: 1)
            }
        }
    }
}

private struct PrivacyFact: View {
    let icon: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(AppColors.accentPrimary)
                .frame(width: 38, height: 38)
                .background(AppColors.accentPrimary.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .appFont(.bodyStrong)
                    .foregroundStyle(AppColors.textPrimary)
                Text(bodyText)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}

private struct ReadyStep: View {
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            OnboardingReadyVisual()
                .frame(maxWidth: .infinity)
                .frame(height: 186)

            StepHeading(
                eyebrow: L10n.text("One last thing"),
                title: name.isEmpty ? L10n.text("Ready for your first look?") : L10n.text("Ready, \(name)?"),
                bodyText: L10n.text("Review the privacy agreement, then make your first scan.")
            )

            VStack(spacing: 0) {
                HowItWorksRow(number: "01", icon: "scan", title: L10n.text("Scan"), detail: L10n.text("One clear photo"))
                HowItWorksConnector()
                HowItWorksRow(number: "02", icon: "sparkles", title: L10n.text("See"), detail: L10n.text("Your eight areas"))
                HowItWorksConnector()
                HowItWorksRow(number: "03", icon: "trending-up", title: L10n.text("Notice"), detail: L10n.text("What changes over time"))
            }
            .padding(.vertical, 8)
            .background(AppColors.bgSurface, in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(AppColors.borderMuted, lineWidth: 1)
            }
        }
    }
}

private struct HowItWorksRow: View {
    let number: String
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.bgSurfaceHigh)
                LucideIcon(name: icon, size: 18)
                    .foregroundStyle(AppColors.accentPrimary)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text(title)
                        .appFont(.bodyStrong)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(number)
                        .appFont(.overline)
                        .foregroundStyle(AppColors.textTertiary)
                }
                Text(detail)
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .frame(height: 62)
    }
}

private struct HowItWorksConnector: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.borderMuted)
            .frame(width: 1, height: 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 35)
    }
}

private struct OnboardingAmbientGlow: View {
    let step: Int

    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill((step == 3 ? AppColors.accentGradEnd : AppColors.accentPrimary).opacity(0.10))
                .frame(width: 370, height: 370)
                .blur(radius: 96)
                .position(x: proxy.size.width * (step.isMultiple(of: 2) ? 0.30 : 0.72), y: proxy.size.height * 0.32)
                .animation(.easeInOut(duration: 0.9), value: step)
        }
        .allowsHitTesting(false)
    }
}

private struct OnboardingPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.13), value: configuration.isPressed)
    }
}

extension Animation {
    static var easeOutCubic: Animation {
        .timingCurve(0.215, 0.61, 0.355, 1, duration: 0.36)
    }

    static var premiumEase: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.48)
    }
}

#Preview {
    OnboardingScreen(onFinish: {})
        .environment(AppPrefsModel())
}
