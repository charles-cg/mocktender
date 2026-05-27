import SwiftUI

// Single-button error overlay. The machine has no resume path today, so the
// only outcome is "close the overlay and bail out of the pour" — the caller
// passes that as `onDismiss`.
struct ErrorOverlay: View {
    let kind: MachineError
    var onDismiss: () -> Void

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
                    GlassButton(title: "Exit", primary: true, full: true, action: onDismiss)
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
        case .cupRemoved:   return "The cup was removed before the pour finished."
        case .lowLiquid(let pumpShort):
            return pumpShort.isEmpty
                ? "Refill the bottle and try again."
                : "Refill the \(pumpShort) bottle and try again."
        case .disconnected: return "Move closer to the machine."
        }
    }
}
