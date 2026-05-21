import SwiftUI

struct DetailScreen: View {
    @Environment(BluetoothManager.self) private var ble
    @Bindable var app: AppState
    var onDispense: () -> Void

    var body: some View {
        let drink = app.selectedDrink
        let cup = ble.cupSize
        let needs: [(pump: Pump, pct: Int, needMl: Double, haveMl: Double)] = Catalog.pumps.compactMap { p in
            let pct = drink.ratios[p.id] ?? 0
            guard pct > 0 else { return nil }
            let need = Double(pct) / 100.0 * Double(cup.ml)
            let have = ble.bottles.first { $0.id == p.id }?.remaining ?? 0
            return (p, pct, need, have)
        }
        let blocker = needs.first(where: { $0.haveMl < $0.needMl })
        let canDispense = blocker == nil && cup != .empty

        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 16) {
                    Spacer().frame(height: 110)
                    DrinkOrb(drink: drink, size: 206, showLabel: false)
                    Text(drink.name)
                        .font(.system(size: 30, weight: .bold))
                        .kerning(-0.5)
                        .foregroundStyle(Color(hex: 0x0A2350))
                        .padding(.bottom, 8)

                    GlassPanel(padding: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            RatioBar(drink: drink, height: 10, radius: 5)
                            FlowLayout(spacing: 14) {
                                ForEach(needs, id: \.pump.id) { n in
                                    HStack(spacing: 7) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(LinearGradient(colors: [n.pump.light, n.pump.color],
                                                                 startPoint: .top, endPoint: .bottom))
                                            .frame(width: 12, height: 12)
                                        Text(n.pump.short)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Color(hex: 0x0A2350))
                                        Text("\(n.pct)%")
                                            .font(.system(size: 13, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(Color(hex: 0x0A2350).opacity(0.5))
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer().frame(height: 130)
                }
            }

            // Top pills
            HStack {
                HeaderPill(action: { app.screen = .home }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                    Text("Back")
                }
                Spacer()
                CupSizeBadge(cup: cup)
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)

            VStack {
                Spacer()
                VStack(spacing: 10) {
                    if let b = blocker {
                        GlassPanel(radius: 16, padding: 10) {
                            HStack(spacing: 8) {
                                Circle().fill(Color(hex: 0xC52C2C)).frame(width: 10, height: 10)
                                Text("\(b.pump.short) too low")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Color(hex: 0x8A1F1F))
                                Spacer()
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(red: 1, green: 225/255, blue: 225/255, opacity: 0.85))
                        )
                    }
                    GlassButton(
                        title: cup == .empty ? "Place cup on tray" : (blocker != nil ? "Refill bottle" : "Dispense"),
                        primary: true, full: true, disabled: !canDispense
                    ) {
                        if canDispense { onDispense() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 44)
            }
        }
    }
}

struct RatioBar: View {
    let drink: Drink
    var height: CGFloat = 8
    var radius: CGFloat = 4

    var body: some View {
        let entries = Catalog.pumps.compactMap { p -> (Pump, Int)? in
            guard let pct = drink.ratios[p.id], pct > 0 else { return nil }
            return (p, pct)
        }
        let total = max(1, entries.reduce(0) { $0 + $1.1 })
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, e in
                    LinearGradient(colors: [e.0.light, e.0.color],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(width: geo.size.width * Double(e.1) / Double(total))
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

// Lightweight wrap layout for the recipe chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 10

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var w: CGFloat = 0, h: CGFloat = 0, lineW: CGFloat = 0, lineH: CGFloat = 0
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if lineW + s.width > maxW {
                w = max(w, lineW)
                h += lineH + spacing
                lineW = s.width + spacing
                lineH = s.height
            } else {
                lineW += s.width + spacing
                lineH = max(lineH, s.height)
            }
        }
        w = max(w, lineW)
        h += lineH
        return CGSize(width: w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        let maxX = bounds.maxX
        for sub in subviews {
            let s = sub.sizeThatFits(.unspecified)
            if x + s.width > maxX {
                x = bounds.minX
                y += lineH + spacing
                lineH = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            lineH = max(lineH, s.height)
        }
    }
}
