import SwiftUI

/// The signature element: a circular gauge ring with an indigo→violet sweep
/// and the score set in big rounded numerals at its center. The premium,
/// health-app way to show an overall reading (Oura / Apple-activity register).
struct ScoreRing: View {
    let score: Double            // 0...10
    var size: CGFloat = 210
    var lineWidth: CGFloat = 16
    var caption: String = L10n.text("OVERALL")
    var ringColors: [Color] = [AppColors.accentGradStart, AppColors.accentGradEnd]

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var target: CGFloat { CGFloat(max(0, min(10, score)) / 10) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppColors.bgSurfaceElevated, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(colors: ringColors + [ringColors.first ?? .clear],
                                    center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: AppColors.accentPrimary.opacity(0.45), radius: 12)

            VStack(spacing: 2) {
                Text(LocalizedStringKey(caption))
                    .appFont(.overline)
                    .foregroundStyle(AppColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    CountUpText(value: score, style: .displayLarge)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("/10")
                        .appFont(.h3)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if reduceMotion {
                progress = target
            } else {
                withAnimation(.spring(response: 1.1, dampingFraction: 0.85).delay(0.1)) {
                    progress = target
                }
            }
        }
        .onChange(of: score) { _, _ in
            withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { progress = target }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.text("Overall reading"))
        .accessibilityValue(L10n.text("\(String(format: "%.1f", locale: L10n.locale, score)) out of 10"))
    }
}

#Preview {
    VStack(spacing: 40) {
        ScoreRing(score: 8.2)
        ScoreRing(score: 6.4, size: 130, lineWidth: 11, ringColors: [AppColors.score(for: .skin), AppColors.score(for: .tone)])
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColors.bgPrimary)
}
