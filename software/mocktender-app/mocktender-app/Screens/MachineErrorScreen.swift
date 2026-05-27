import SwiftUI

/// Full-cover, non-dismissible error screen. Shown whenever the firmware
/// reports `state == .error` — the operator has to press the physical
/// reset button on the machine to clear it. When the firmware transitions
/// back to IDLE, the next BLE packet flips `machineState` and this view
/// is removed.
struct MachineErrorScreen: View {
    let kind: MachineError?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x6E1B1B), Color(hex: 0x2A0606)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(hex: 0xFFD28A), Color(hex: 0xFF5230)],
                            startPoint: .top, endPoint: .bottom))
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .frame(width: 128, height: 128)
                .shadow(color: Color.black.opacity(0.35), radius: 18, y: 10)

                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 30, weight: .heavy))
                        .kerning(-0.4)
                        .foregroundStyle(.white)
                    Text(desc)
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 6) {
                    Text("Press the RESET button on the machine")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text("to clear the error and return to ready.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.75))
                }
                .padding(.bottom, 40)
            }
        }
        // Absorb every gesture so nothing underneath can be interacted with
        // until the firmware itself clears the error.
        .contentShape(Rectangle())
        .onTapGesture { }
        .gesture(DragGesture(minimumDistance: 0).onChanged { _ in })
        .transition(.opacity)
    }

    private var title: String {
        switch kind {
        case .cupRemoved?:        return "Cup removed"
        case .lowLiquid?:         return "Bottle empty"
        case .disconnected?:      return "Disconnected"
        case nil:                 return "Machine error"
        }
    }
    private var desc: String {
        switch kind {
        case .cupRemoved?:
            return "The cup was lifted off the tray before the pour finished. Put a fresh cup down after resetting."
        case .lowLiquid(let pumpShort)?:
            return pumpShort.isEmpty
                ? "A bottle ran dry during the pour. Refill it before continuing."
                : "The \(pumpShort) bottle ran dry during the pour. Refill it before continuing."
        case .disconnected?:
            return "The machine reported a fault and lost the connection. Stay close while it recovers."
        case nil:
            return "The machine reported a fault. Check the unit for any obvious issue."
        }
    }
}
