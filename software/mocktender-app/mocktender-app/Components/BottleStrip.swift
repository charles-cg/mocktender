import SwiftUI

struct BottleStrip: View {
    let pump: Pump
    let remaining: Double
    var capacity: Double = 1000

    var body: some View {
        let pct = max(0, min(1, remaining / capacity))
        let low = pct < 0.2
        VStack(spacing: 8) {
            ZStack(alignment: .bottom) {
                // bottle body
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 20, bottomLeading: 12, bottomTrailing: 12, topTrailing: 20),
                    style: .continuous
                )
                .fill(Color.white.opacity(0.55))
                .background(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 20, bottomLeading: 12, bottomTrailing: 12, topTrailing: 20)
                    ).fill(.ultraThinMaterial)
                )
                .overlay(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 20, bottomLeading: 12, bottomTrailing: 12, topTrailing: 20)
                    ).stroke(Color.white.opacity(0.95), lineWidth: 0.5)
                )

                // liquid
                GeometryReader { geo in
                    let h = geo.size.height * pct
                    LinearGradient(colors: [pump.light, pump.color],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: h)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.55))
                                .frame(height: 2)
                                .blur(radius: 1)
                                .offset(y: -geo.size.height * pct / 2 + 1),
                            alignment: .center
                        )
                        .animation(.easeInOut(duration: 0.6), value: pct)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 20, bottomLeading: 12, bottomTrailing: 12, topTrailing: 20)
                    )
                )

                // cap
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.9), Color(red: 230/255, green: 240/255, blue: 255/255, opacity: 0.6)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 34, height: 14)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.95), lineWidth: 0.5))
                    .offset(y: -124 / 2 - 1)
            }
            .frame(width: 50, height: 124)
            .shadow(color: Color(red: 20/255, green: 40/255, blue: 80/255, opacity: 0.10),
                    radius: 6, x: 0, y: 4)

            VStack(spacing: 2) {
                Text(pump.short)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: 0x0A2350))
                Text("\(Int(remaining.rounded())) ml")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(low ? Color(hex: 0xC52C2C) : Color(hex: 0x0A2350).opacity(0.6))
            }
        }
    }
}
