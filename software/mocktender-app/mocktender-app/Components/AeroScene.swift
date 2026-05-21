import SwiftUI

struct AeroScene<Content: View>: View {
    let palette: AeroPalette
    var dimmed: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [palette.top, palette.mid, palette.bot],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // soft cloud blobs
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                blob.frame(width: w * 0.95, height: h * 0.6)
                    .offset(x: -w * 0.30, y: -h * 0.20)
                blob.frame(width: w * 0.9, height: h * 0.55)
                    .offset(x: w * 0.35, y: h * 0.55)
                    .opacity(0.7)
            }
            .allowsHitTesting(false)

            Bubbles(count: 5, dark: palette.isDark)
                .allowsHitTesting(false)

            // Dim sits *between* the scene and the content so foreground
            // views (progress UI, buttons, etc.) render at full contrast
            // against the darkened wash instead of through it.
            if dimmed {
                Color.black.opacity(0.42)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            content()
        }
    }

    private var blob: some View {
        RadialGradient(colors: [palette.blob, .clear], center: .center, startRadius: 0, endRadius: 240)
            .blur(radius: 8)
    }
}

// Rising aero bubbles
struct Bubbles: View {
    let count: Int
    let dark: Bool
    @State private var phase: Double = 0

    private struct Bubble: Hashable {
        let x: CGFloat
        let size: CGFloat
        let dur: Double
        let delay: Double
        let driftDur: Double
    }

    @State private var items: [Bubble] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(items, id: \.self) { b in
                    TimelineView(.animation) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate + b.delay
                        let progress = (t.truncatingRemainder(dividingBy: b.dur)) / b.dur
                        // y goes from bottom (1.0) up past -0.1
                        let y = (1.0 - progress * 1.2) * geo.size.height
                        let xDrift = sin(t * (2 * .pi / b.driftDur)) * 7
                        let opacity = progress < 0.12 ? progress / 0.12
                            : (progress > 0.92 ? max(0, (1 - progress) / 0.08 * 0.4) : 0.55)
                        bubbleCircle(size: b.size)
                            .position(x: b.x * geo.size.width + xDrift, y: y)
                            .opacity(opacity)
                    }
                }
            }
        }
        .onAppear {
            if items.isEmpty {
                items = (0..<count).map { _ in
                    Bubble(
                        x: CGFloat.random(in: 0...1),
                        size: CGFloat.random(in: 14...42),
                        dur: Double.random(in: 18...34),
                        delay: -Double.random(in: 0...20),
                        driftDur: Double.random(in: 7...13)
                    )
                }
            }
        }
    }

    private func bubbleCircle(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: dark
                    ? [Color.white.opacity(0.6), Color(red: 120/255, green: 180/255, blue: 240/255, opacity: 0.2), .clear]
                    : [Color.white.opacity(0.85), Color(red: 180/255, green: 220/255, blue: 255/255, opacity: 0.18), .clear],
                    center: UnitPoint(x: 0.3, y: 0.28),
                    startRadius: 0,
                    endRadius: size
                )
            )
            .frame(width: size, height: size)
            .shadow(color: (dark ? Color(red: 120/255, green: 180/255, blue: 240/255) : Color(red: 180/255, green: 220/255, blue: 255/255)).opacity(0.35), radius: 6)
    }
}
