import SwiftUI

/// Hosts Capture -> Analyzing -> Score Report as one modal "session" (all
/// presented via a single `.fullScreenCover`, matching how the Flutter app
/// pushes these three as a stack on top of the persistent tab shell).
struct ScanFlowView: View {
    private enum Step {
        case capture
        case analyzing(ScanInput)
        case report
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(LastResultModel.self) private var lastResult
    @State private var step: Step = .capture

    var body: some View {
        Group {
            switch step {
            case .capture:
                CaptureScreen(
                    onCancel: closeFlow,
                    onCaptured: { input in step = .analyzing(input) }
                )
            case .analyzing(let input):
                AnalyzingScreen(
                    input: input,
                    onCancel: closeFlow,
                    onComplete: { step = .report },
                    onRetake: { step = .capture }
                )
            case .report:
                if let result = lastResult.result {
                    ScoreReportScreen(
                        result: result,
                        onSeeTips: {
                            dismiss()
                            router.select(.tips)
                        },
                        onSettings: {
                            dismiss()
                            router.select(.profile)
                        }
                    )
                } else {
                    Color.clear.onAppear { dismiss() }
                }
            }
        }
    }

    /// Update the binding that owns the full-screen cover directly. Calling
    /// `dismiss()` as well keeps this view safe if it is hosted differently in
    /// previews or future navigation flows.
    private func closeFlow() {
        router.showScanFlow = false
        dismiss()
    }
}

/// First launch reuses the production camera and Vision pipeline, then keeps
/// the numeric report locked until RevenueCat grants access.
struct FirstScanFlowView: View {
    private enum Step {
        case welcome
        case capture
        case analyzing(ScanInput)
        case ready(ScanResult)
    }

    var onCancel: () -> Void
    var onUnlock: (ScanResult) -> Void

    @Environment(LastResultModel.self) private var lastResult
    @State private var step: Step = .welcome

    var body: some View {
        Group {
            switch step {
            case .welcome:
                ZStack {
                    AppColors.bgPrimary.ignoresSafeArea()
                    VStack(spacing: 22) {
                        HStack {
                            Button(L10n.text("Back"), action: onCancel)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer()
                        }
                        Spacer(minLength: 0)
                        MiroCompanion(
                            message: L10n.text("You look great. Want to build on that with me? Now, let’s find out your score."),
                            expression: .laugh, size: 260, stacked: true
                        )
                        Text(L10n.text("Scan your face to find your starting point. Then let’s work on looking your best."))
                            .appFont(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                        PrimaryButton(title: L10n.text("Let’s take my selfie")) {
                            AppAnalytics.shared.track(.scanRequested, ["source": "onboarding"])
                            step = .capture
                        }
                        Text(L10n.text("Your photo is analyzed on this device."))
                            .appFont(.caption).foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(24)
                    .frame(maxWidth: 500)
                }
                .analyticsScreen("first_scan_intro")
            case .capture:
                CaptureScreen(
                    onCancel: onCancel,
                    onCaptured: { input in
                        withAnimation(.premiumEase) {
                            step = .analyzing(input)
                        }
                    }
                )

            case .analyzing(let input):
                AnalyzingScreen(
                    input: input,
                    onCancel: { step = .capture },
                    onComplete: {
                        guard let result = lastResult.result else {
                            step = .capture
                            return
                        }
                        withAnimation(.premiumEase) {
                            step = .ready(result)
                        }
                    },
                    onRetake: { step = .capture },
                    recordInHistory: false,
                    completionDelayNanoseconds: 1_750_000_000
                )

            case .ready(let result):
                FirstScanReadyScreen(
                    result: result,
                    onRetake: {
                        AppAnalytics.shared.track(.reportAction, ["action": "retake", "is_locked": true])
                        step = .capture
                    },
                    onUnlock: { onUnlock(result) }
                )
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct FirstScanReadyScreen: View {
    let result: ScanResult
    let onRetake: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        ZStack {
            // This is the exact screen shown after a successful purchase —
            // the captured photo and report structure remain visible while
            // score-bearing details are selectively concealed by the report.
            ScoreReportScreen(
                result: result,
                onSeeTips: {},
                onSettings: {},
                onClose: onRetake,
                isLockedPreview: true,
                showsBottomAction: false
            )
            .accessibilityHidden(true)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 9) {
                MiroCompanion(
                    message: L10n.text("Looking good! Your score is ready. Let’s build on your strengths, together."),
                    expression: .grin, size: 126
                )
                PrimaryButton(title: L10n.text("Explore my Pro plans")) {
                    Haptics.heavy()
                    onUnlock()
                }

                Text(L10n.text("Unlock your score, all categories, and personal insights"))
                    .appFont(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 9)
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle().fill(AppColors.borderMuted).frame(height: 1)
            }
        }
    }
}

#if DEBUG
/// Simulator-only visual QA entry point. This is compiled out of App Store
/// builds and never changes the production first-launch flow.
struct FirstScanReadyPreview: View {
    var body: some View {
        FirstScanReadyScreen(
            result: MockScanData.seedResult(),
            onRetake: {},
            onUnlock: {}
        )
    }
}
#endif
