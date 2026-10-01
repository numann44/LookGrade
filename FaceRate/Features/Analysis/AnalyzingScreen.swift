import Combine
import SwiftUI
import UIKit

private let analysisSteps = [L10n.text("Detecting face"), L10n.text("Mapping landmarks"), L10n.text("Reading skin"), L10n.text("Generating insights")]

struct AnalyzingScreen: View {
    let input: ScanInput
    var onCancel: () -> Void
    var onComplete: () -> Void
    var onRetake: () -> Void
    var recordInHistory: Bool = true
    var completionDelayNanoseconds: UInt64 = 350_000_000

    @Environment(ScanCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var scanlinePhase: CGFloat = 0
    private let stepTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Text(L10n.text("Analyzing Scan")).appFont(.displayMedium).foregroundStyle(AppColors.textPrimary)
                .padding(.top, AppSpacing.sm12)
            Text(L10n.text("Please hold still.")).appFont(.body).foregroundStyle(AppColors.textSecondary)
                .padding(.top, 6)

            analyzingCanvas
                .aspectRatio(0.78, contentMode: .fit)
                .frame(maxHeight: .infinity)
                .padding(.top, AppSpacing.lg20)

            if case .failed(let message) = coordinator.state {
                ErrorCard(message: message).padding(.top, AppSpacing.lg20)
            } else {
                ProgressList(currentStep: step).padding(.top, AppSpacing.lg20)
            }

            if case .failed = coordinator.state {
                PrimaryButton(title: L10n.text("Retake photo"), leadingIcon: "smile") { onRetake() }
                    .padding(.top, AppSpacing.sm12)
            } else {
                PrimaryButton(title: L10n.text("Cancel Scan"), variant: .outline, leadingIcon: "x") { onCancel() }
                    .padding(.top, AppSpacing.sm12)
            }
        }
        .padding(.horizontal, AppSpacing.lg20)
        .padding(.bottom, AppSpacing.lg20)
        .background(AppColors.bgPrimary.ignoresSafeArea())
        .analyticsScreen("analysis")
        .onReceive(stepTimer) { _ in
            if step < analysisSteps.count { step += 1 }
        }
        .task {
            let result = await coordinator.run(input, recordInHistory: recordInHistory)
            if result != nil, !Task.isCancelled, case .idle = coordinator.state {
                step = analysisSteps.count
                Haptics.medium()
                do { try await Task.sleep(nanoseconds: completionDelayNanoseconds) }
                catch { return }
                guard !Task.isCancelled else { return }
                onComplete()
            }
        }
    }

    private var analyzingCanvas: some View {
        ZStack {
            AppColors.bgSurface
            capturedImage
            GridLinesView()
            LandmarkDotsView()
            Rectangle()
                .fill(AppColors.meshScanline)
                .frame(height: 1.5)
                .shadow(color: AppColors.meshScanline.opacity(0.6), radius: 12)
                .offset(y: reduceMotion ? 100 : scanlinePhase)
                .opacity(reduceMotion ? 0.5 : 1)
                .onAppear {
                    guard !reduceMotion else { return }
                    withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                        scanlinePhase = 200
                    }
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl * 2))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.xl * 2).stroke(AppColors.borderSubtle, lineWidth: 1))
        .clipped()
    }

    @ViewBuilder
    private var capturedImage: some View {
        if let uiImage = UIImage(contentsOfFile: input.imagePath) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(AppColors.bgSurface.opacity(0.55))
        } else {
            LucideIcon(name: "circle-user", size: 96).foregroundStyle(AppColors.textTertiary)
        }
    }
}

private struct GridLinesView: View {
    var body: some View {
        Canvas { context, size in
            let cols = 12, rows = 16
            var path = Path()
            for i in 0...cols {
                let x = size.width * CGFloat(i) / CGFloat(cols)
                path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height))
            }
            for j in 0...rows {
                let y = size.height * CGFloat(j) / CGFloat(rows)
                path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(AppColors.meshGrid), lineWidth: 0.6)
        }
    }
}

private struct LandmarkDotsView: View {
    var body: some View {
        GeometryReader { geo in
            let points: [CGPoint] = [
                CGPoint(x: geo.size.width * 0.34, y: geo.size.height * 0.40),
                CGPoint(x: geo.size.width * 0.66, y: geo.size.height * 0.40),
                CGPoint(x: geo.size.width * 0.50, y: geo.size.height * 0.55),
                CGPoint(x: geo.size.width * 0.42, y: geo.size.height * 0.70),
                CGPoint(x: geo.size.width * 0.58, y: geo.size.height * 0.70),
            ]
            ForEach(points.indices, id: \.self) { i in
                Circle().fill(AppColors.captureOval).frame(width: 6, height: 6)
                    .shadow(color: AppColors.captureOval.opacity(0.4), radius: 4)
                    .position(points[i])
            }
        }
    }
}

private struct ErrorCard: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm12) {
            LucideIcon(name: "circle-x", size: 20).foregroundStyle(AppColors.stateDanger)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.text("Analysis failed")).appFont(.h3).foregroundStyle(AppColors.stateDanger)
                Text(message).appFont(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(2)
            }
        }
        .padding(AppSpacing.md16)
        .background(AppColors.stateDanger.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.lg).stroke(AppColors.stateDanger.opacity(0.5), lineWidth: 1))
    }
}

private struct ProgressList: View {
    let currentStep: Int
    var body: some View {
        VStack(spacing: AppSpacing.xs8) {
            ForEach(analysisSteps.indices, id: \.self) { i in
                let done = i < currentStep
                let active = i == currentStep
                HStack(spacing: AppSpacing.sm12) {
                    Rectangle()
                        .fill(active ? AppColors.accentPrimary : .clear)
                        .frame(width: 2, height: 18)
                    StepCircle(done: done, active: active)
                    Text(analysisSteps[i])
                        .appFont(active ? .bodyStrong : .body)
                        .foregroundStyle(active ? AppColors.textPrimary : (done ? AppColors.textPrimary : AppColors.textTertiary))
                    Spacer()
                }
            }
        }
        .padding(.horizontal, AppSpacing.md16)
        .padding(.vertical, AppSpacing.md16)
        .glassCard()
    }
}

private struct StepCircle: View {
    let done: Bool
    let active: Bool
    var body: some View {
        ZStack {
            if done {
                Circle().fill(AppColors.accentPrimary.opacity(0.18)).overlay(Circle().stroke(AppColors.accentPrimary, lineWidth: 1))
                LucideIcon(name: "check", size: 12).foregroundStyle(AppColors.accentPrimary)
            } else if active {
                ProgressView().tint(AppColors.accentPrimary)
            } else {
                Circle().stroke(AppColors.textTertiary, lineWidth: 1)
            }
        }
        .frame(width: 22, height: 22)
    }
}
