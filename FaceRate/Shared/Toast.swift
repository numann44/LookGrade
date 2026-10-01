import SwiftUI

/// DESIGN.md §3.10 — bottom-anchored, autoclose 3s, swipe-to-dismiss.
enum ToastVariant {
    case success, warning, danger

    var color: Color {
        switch self {
        case .success: return AppColors.stateSuccess
        case .warning: return AppColors.stateWarning
        case .danger: return AppColors.stateDanger
        }
    }
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let variant: ToastVariant

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

/// Attach with `.toast($message)`; auto-dismisses after 3s or on swipe-down.
struct ToastOverlay: View {
    let message: ToastMessage
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.xs8) {
            Circle().fill(message.variant.color).frame(width: 8, height: 8)
            Text(message.text).appFont(.body).foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, AppSpacing.md16)
        .padding(.vertical, AppSpacing.sm12)
        .background(AppColors.bgSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.md).stroke(AppColors.borderSubtle, lineWidth: 1))
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.height > 20 { onDismiss() }
            }
        )
        .task {
            try? await Task.sleep(for: .seconds(3))
            onDismiss()
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        overlay(alignment: .bottom) {
            if let value = message.wrappedValue {
                ToastOverlay(message: value) { message.wrappedValue = nil }
                    .padding(.bottom, AppSpacing.xxl32)
                    .animation(.easeOut(duration: 0.22), value: message.wrappedValue)
            }
        }
    }
}
