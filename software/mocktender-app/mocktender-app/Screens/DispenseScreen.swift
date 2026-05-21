import SwiftUI

struct DispenseScreen: View {
    @Environment(BluetoothManager.self) private var ble
    let drink: Drink
    let cup: CupSize
    var onCancel: () -> Void

    var body: some View {
        let pct = ble.dispenseProgress * 100
        let dispensedMl = Int((ble.dispenseProgress * Double(cup.ml)).rounded())

        // Dispense renders on top of the dimmed Aero scene, so use white
        // text + a soft white ring track for full contrast.
        VStack(spacing: 0) {
            Spacer().frame(height: 70)
            Text(drink.name)
                .font(.system(size: 22, weight: .bold))
                .kerning(-0.3)
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0, green: 0, blue: 40/255).opacity(0.45), radius: 4, y: 2)

            if ble.bleLostDuringDispense {
                BleLostChip(label: "BLE lost · finishing pour",
                            darkBackground: true)
                    .padding(.top, 8)
            }

            ZStack {
                ProgressRing(progress: ble.dispenseProgress, size: 280, stroke: 12, drinkColor: drink.grad[1])
                DrinkOrb(drink: drink, size: 200, showLabel: false)
            }
            .frame(width: 280, height: 280)
            .padding(.top, 18)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(Int(pct.rounded()))")
                        .font(.system(size: 80, weight: .bold))
                        .monospacedDigit()
                        .kerning(-3)
                    Text("%")
                        .font(.system(size: 28, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundStyle(.white)
                .shadow(color: Color(red: 0, green: 0, blue: 60/255).opacity(0.5), radius: 10, y: 2)

                Text("\(dispensedMl) / \(cup.ml) ml")
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 18)

            // Pump dots — one slot per pump used in the recipe. Each slot has
            // a fixed 18×18 container so the active glow can bloom without
            // shifting neighbours, and the row stays centered on the screen.
            HStack(spacing: 12) {
                ForEach(Catalog.pumps.filter { drink.ratios[$0.id] != nil }) { p in
                    let active = ble.activePumpId == p.id
                    ZStack {
                        Circle()
                            .fill(active ? p.color : Color.white.opacity(0.25))
                            .frame(width: 12, height: 12)
                            .shadow(color: active ? p.color : .clear, radius: active ? 6 : 0)
                    }
                    .frame(width: 18, height: 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, 18)
            .animation(.easeOut(duration: 0.2), value: ble.activePumpId)

            Spacer()

            HoldToCancel(onCancel: onCancel)
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
        }
    }
}

struct ProgressRing: View {
    let progress: Double  // 0…1
    var size: CGFloat = 260
    var stroke: CGFloat = 12
    var drinkColor: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.18), lineWidth: stroke)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    AngularGradient(colors: [Color.white.opacity(0.95), drinkColor.opacity(0.95)],
                                    center: .center),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: .white.opacity(0.55), radius: 4)
                .animation(.linear(duration: 0.4), value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct BleLostChip: View {
    let label: String
    var darkBackground: Bool = false
    var body: some View {
        let textColor = darkBackground ? Color.white.opacity(0.85) : Color(hex: 0x0A2350).opacity(0.75)
        let strokeColor = darkBackground ? Color.white.opacity(0.3) : Color(hex: 0x0A2350).opacity(0.15)
        HStack(spacing: 6) {
            Circle()
                .fill(Color(hex: 0xFFB46B))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: 0xFFB46B).opacity(0.8), radius: 3)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(
            Capsule().fill(Color.white.opacity(0.5))
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(strokeColor, lineWidth: 0.5))
        )
    }
}

struct HoldToCancel: View {
    var holdMs: Double = 850
    var onCancel: () -> Void

    @State private var pct: Double = 0
    @State private var holdStart: Date? = nil
    @State private var ticker: Timer? = nil

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color(red: 1, green: 90/255, blue: 90/255, opacity: 0.22))
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(Capsule().stroke(Color.white.opacity(0.35), lineWidth: 0.5))

            GeometryReader { geo in
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 1, green: 90/255, blue: 90/255, opacity: 0.85),
                                 Color(red: 200/255, green: 40/255, blue: 40/255, opacity: 0.95)],
                        startPoint: .top, endPoint: .bottom))
                    .frame(width: geo.size.width * pct / 100)
                    .animation(pct == 0 ? .easeOut(duration: 0.15) : nil, value: pct)
            }
            .clipShape(Capsule())

            Text(pct > 0 ? "Keep holding…" : "Hold to cancel")
                .font(.system(size: 15, weight: .bold))
                .kerning(-0.2)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 54)
        .shadow(color: Color(red: 120/255, green: 20/255, blue: 20/255).opacity(0.2),
                radius: 8, x: 0, y: 4)
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if holdStart == nil {
                        holdStart = Date()
                        ticker = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { _ in
                            guard let s = holdStart else { return }
                            let elapsed = Date().timeIntervalSince(s) * 1000
                            let p = min(100, elapsed / holdMs * 100)
                            DispatchQueue.main.async {
                                pct = p
                                if p >= 100 {
                                    fireCancel()
                                }
                            }
                        }
                    }
                }
                .onEnded { _ in cancelHold() }
        )
    }

    private func cancelHold() {
        ticker?.invalidate(); ticker = nil
        holdStart = nil
        pct = 0
    }
    private func fireCancel() {
        ticker?.invalidate(); ticker = nil
        holdStart = nil
        pct = 0
        onCancel()
    }
}
