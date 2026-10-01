import SwiftUI
import UIKit

/// The captured photo at the top of the report — clean and premium: a soft
/// fade into the background plus a gentle vignette, nothing decorative.
struct ReportHeroPhoto: View {
    var image: UIImage?
    var height: CGFloat = 400

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        AppColors.bgSurfaceElevated
                        LucideIcon(name: "circle-user", size: 84).foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                RadialGradient(
                    colors: [.clear, AppColors.bgPrimary.opacity(0.35)],
                    center: .center, startRadius: 120, endRadius: 320
                )
            )

            LinearGradient(
                colors: [.clear, .clear, AppColors.bgPrimary],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: height)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ReportHeroPhoto(image: nil)
        .background(AppColors.bgPrimary)
}
