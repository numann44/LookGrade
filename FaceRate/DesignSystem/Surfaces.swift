import SwiftUI

/// Premium glass surfaces — the material language of the "Aura" system.
/// A card is a filled squircle with a faint top highlight and a 1px edge
/// that catches light at the top, over a soft ambient shadow. Everything
/// layered, nothing flat.
extension View {
    func glassCard(
        cornerRadius: CGFloat = AppRadius.lg,
        fill: Color = AppColors.bgSurface,
        strokeOpacity: Double = 1,
        shadow: Bool = true
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, fill: fill, strokeOpacity: strokeOpacity, shadow: shadow))
    }
}

private struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let strokeOpacity: Double
    let shadow: Bool

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.glassHighlight, Color.white.opacity(0.0)],
                                    startPoint: .top, endPoint: .center
                                )
                            )
                    )
                    .shadow(
                        color: shadow ? AppColors.glassShadow.opacity(0.28) : .clear,
                        radius: 6,
                        y: 3
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppColors.borderSubtle.opacity(strokeOpacity),
                                AppColors.borderMuted.opacity(strokeOpacity)
                            ],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
    }
}
