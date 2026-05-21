import SwiftUI

struct ErrorOverlay: View {
    let kind: MachineError
    var onDismiss: () -> Void
    var onRetry: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            GlassPanel(radius: 28, padding: 20) {
                VStack(spacing: 16) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(LinearGradient(
                                colors: [Color(hex: 0xFFD28A), Color(hex: 0xFF7A52)],
                                startPoint: .top, endPoint: .bottom))
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 17, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(red: 220/255, green: 80/255, blue: 30/255, opacity: 0.28),
                                radius: 8, y: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.system(size: 18, weight: .bold))
                                .kerning(-0.3)
                                .foregroundStyle(Color(hex: 0x0A2350))
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(hex: 0x0A2350).opacity(0.65))
                        }
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        if let s = secondary {
                            GlassButton(title: s, full: true, action: onDismiss)
                        }
                        GlassButton(title: primary, primary: true, full: true, action: onRetry)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 32)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var title: String {
        switch kind {
        case .cupRemoved:   return "Cup removed"
        case .lowLiquid:    return "Bottle empty"
        case .disconnected: return "Disconnected"
        }
    }
    private var desc: String {
        switch kind {
        case .cupRemoved:   return "Place the cup back to resume."
        case .lowLiquid:    return "Refill to finish this drink."
        case .disconnected: return "Move closer to the machine."
        }
    }
    private var primary: String {
        switch kind {
        case .cupRemoved:   return "Resume"
        case .lowLiquid:    return "Retry"
        case .disconnected: return "Reconnect"
        }
    }
    private var secondary: String? {
        switch kind {
        case .cupRemoved, .lowLiquid: return "Cancel"
        case .disconnected:            return "Close"
        }
    }
}
