import SwiftUI

/// DESIGN.md §2.7 — number counters roll up from 0 to value over 700ms.
struct CountUpText: View {
    let value: Double
    var style: AppTextStyle = .displayLarge
    var format: (Double) -> String = { String(format: "%.1f", locale: L10n.locale, $0) }

    @State private var animated: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(format(animated))
            .appFont(style, tabularNumbers: true)
            .onAppear { set(value) }
            .onChange(of: value) { _, newValue in set(newValue) }
            .accessibilityLabel(format(value))
    }

    private func set(_ newValue: Double) {
        if reduceMotion {
            animated = newValue
        } else {
            withAnimation(.easeOut(duration: 0.7)) {
                animated = newValue
            }
        }
    }
}

#Preview {
    CountUpText(value: 8.2)
        .foregroundStyle(AppColors.textPrimary)
        .padding()
        .background(AppColors.bgPrimary)
}
