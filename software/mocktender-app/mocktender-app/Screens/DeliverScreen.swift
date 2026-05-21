import SwiftUI

struct DeliverScreen: View {
    @Environment(BluetoothManager.self) private var ble
    let drink: Drink
    let cup: CupSize
    var onCupRemoved: () -> Void

    @State private var pulse = false
    @State private var lift = false

    var body: some View {
        // Deliver renders on top of the dimmed Aero scene, so white reads.
        VStack(spacing: 0) {
            Spacer().frame(height: 90)
            Text("READY")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.4)
                .foregroundStyle(Color.white.opacity(0.75))
            Text(drink.name)
                .font(.system(size: 32, weight: .bold))
                .kerning(-0.5)
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0, green: 0, blue: 40/255).opacity(0.45),
                        radius: 5, y: 2)
                .padding(.top, 4)

            DrinkOrb(drink: drink, size: 220, showLabel: false)
                .scaleEffect(pulse ? 1.025 : 1)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                .padding(.top, 22)
                .onAppear { pulse = true; lift = true }

            VStack(spacing: 8) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: lift ? -6 : 0)
                    .opacity(lift ? 1 : 0.85)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: lift)

                Text("Remove cup to continue")
                    .font(.system(size: 17, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(.white)

                Text("\(cup.label) · \(cup.ml) ml delivered")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(.top, 30)

            if ble.bleLostDuringDispense {
                BleLostChip(label: "BLE lost · will reconnect after pickup",
                            darkBackground: true)
                    .padding(.top, 12)
            }

            Spacer()

            // Prototype affordance — the real app reads the cup-lifted packet.
            Button(action: onCupRemoved) {
                Text("Simulate cup removal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule().fill(Color.white.opacity(0.16))
                            .background(Capsule().fill(.ultraThinMaterial))
                            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .padding(.bottom, 36)
        }
    }
}
