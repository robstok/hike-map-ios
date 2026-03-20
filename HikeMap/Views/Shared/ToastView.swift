import SwiftUI

struct Toast: Identifiable {
    enum ToastType { case success, error, info }
    let id: UUID
    let message: String
    let type: ToastType

    var backgroundColor: Color {
        switch type {
        case .success: return Color(hex: "#22C55E")
        case .error:   return Color(hex: "#EF4444")
        case .info:    return Color(hex: "#3B82F6")
        }
    }

    var icon: String {
        switch type {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }
}

struct ToastStack: View {
    let toasts: [Toast]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(toasts) { toast in
                ToastRow(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35), value: toasts.map(\.id))
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

struct ToastRow: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.icon)
                .foregroundStyle(.white)
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(toast.backgroundColor, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}
