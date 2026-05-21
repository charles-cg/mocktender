import SwiftUI

struct DrinkOrb: View {
    let drink: Drink
    var size: CGFloat = 132
    var showLabel: Bool = true
    var selected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            if let action {
                // A real Button cooperates with the enclosing ScrollView —
                // press cancels if the finger drifts (so the scroll wins
                // ties) and a tap fires only on lift, never on hold.
                Button(action: action) { orb }
                    .buttonStyle(OrbPressStyle())
            } else {
                orb
            }
            if showLabel {
                Text(drink.name)
                    .font(.system(size: 15, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(Color(hex: 0x0A2350))
                    .lineLimit(1)
                    .frame(maxWidth: size + 20)
            }
        }
    }

    /// Subtle press-down scale, replicating the old gesture feedback without
    /// stealing touches from the surrounding scroll view.
    private struct OrbPressStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }

    private var orb: some View {
        let a = drink.grad[0]
        let b = drink.grad[1]
        let c = drink.grad[2]
        // Flatter look: gradient stretched wider (less inset darkening at the
        // edge), highlight dialed back, drop shadow softer. Still circular —
        // just less of a marble / 3D-ball read.
        return ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [a, b, c],
                        center: UnitPoint(x: 0.38, y: 0.36),
                        startRadius: 0,
                        endRadius: size * 1.05
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            selected ? Color.white : Color.clear,
                            lineWidth: selected ? 3 : 0
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            selected ? Color(red: 120/255, green: 210/255, blue: 255/255, opacity: 0.85) : Color.clear,
                            lineWidth: selected ? 2 : 0
                        )
                        .padding(-2)
                )
                .shadow(color: Color(red: 20/255, green: 40/255, blue: 80/255, opacity: 0.12),
                        radius: 7, x: 0, y: 5)

            // Soft top-light — gentle, not glossy.
            Circle()
                .fill(
                    RadialGradient(colors: [Color.white.opacity(0.45), .clear],
                                   center: .center, startRadius: 0, endRadius: size * 0.22)
                )
                .frame(width: size * 0.40, height: size * 0.28)
                .blur(radius: 3)
                .offset(x: -size * 0.15, y: -size * 0.20)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
    }
}
