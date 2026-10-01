import SwiftUI

/// DESIGN.md §3.5 — centered oval guide with 4 cyan corner brackets.
enum CaptureGuideState {
    case searching, aligned, tooDark, tooBright

    var color: Color {
        switch self {
        case .searching, .aligned: return AppColors.captureOval
        case .tooDark, .tooBright: return AppColors.stateWarning
        }
    }
}

struct OvalCameraOverlay: View {
    var state: CaptureGuideState = .searching

    var body: some View {
        GeometryReader { geo in
            // Base the guide on the *shorter* edge so the oval + its brackets
            // stay fully on-screen in landscape / iPad multitasking too — using
            // width alone overflowed the height once the app can rotate.
            let basis = min(geo.size.width, geo.size.height)
            let ovalSize = CGSize(width: basis * 0.68, height: basis * 0.68 * 1.35)
            let rect = CGRect(
                x: (geo.size.width - ovalSize.width) / 2,
                y: (geo.size.height - ovalSize.height) / 2,
                width: ovalSize.width, height: ovalSize.height
            )

            ZStack {
                Ellipse()
                    .stroke(state.color, lineWidth: 2)
                    .shadow(color: state == .aligned ? AppColors.accentGlow : .clear, radius: 16)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                ForEach(0..<4, id: \.self) { corner in
                    CornerBracket()
                        .stroke(AppColors.captureBracket, lineWidth: 3)
                        .frame(width: 36, height: 36)
                        .rotationEffect(.degrees(Double(corner) * 90))
                        .position(bracketPosition(corner: corner, rect: rect.insetBy(dx: -20, dy: -20)))
                }
            }
        }
    }

    private func bracketPosition(corner: Int, rect: CGRect) -> CGPoint {
        switch corner {
        case 0: return CGPoint(x: rect.minX, y: rect.minY)
        case 1: return CGPoint(x: rect.maxX, y: rect.minY)
        case 2: return CGPoint(x: rect.maxX, y: rect.maxY)
        default: return CGPoint(x: rect.minX, y: rect.maxY)
        }
    }
}

/// A single top-left-oriented corner bracket; `OvalCameraOverlay` rotates
/// it 0/90/180/270 to cover all 4 corners.
private struct CornerBracket: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 16))
        p.addArc(
            center: CGPoint(x: rect.minX + 16, y: rect.minY + 16),
            radius: 16, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

#Preview {
    ZStack {
        AppColors.bgPrimary
        OvalCameraOverlay(state: .aligned)
    }
    .frame(width: 390, height: 600)
}
