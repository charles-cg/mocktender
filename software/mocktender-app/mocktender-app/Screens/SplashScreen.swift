import SwiftUI

// Boot-up splash. Sits over the regular AeroScene for ~1.6 s, fades in on
// appear and fades out into the first real screen. Pure presentation —
// `MocktenderApp` drives the timer that flips the gate.
struct SplashScreen: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Reuse the sky palette so the splash transitions cleanly into
            // whatever screen comes next.
            AeroScene(palette: .sky) {
                VStack(spacing: 26) {
                    MocktenderLogo(size: 168)
                        .scaleEffect(appeared ? 1.0 : 0.92)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.7, dampingFraction: 0.78), value: appeared)

                    VStack(spacing: 6) {
                        Text("Mocktender")
                            .font(.system(size: 44, weight: .bold))
                            .kerning(-0.8)
                            .foregroundStyle(Color(hex: 0x0A2350))
                            .shadow(color: Color.white.opacity(0.6), radius: 4, y: 1)
                        Text("Pour, glass, sip.")
                            .font(.system(size: 14, weight: .semibold))
                            .kerning(0.3)
                            .foregroundStyle(Color(hex: 0x0A2350).opacity(0.55))
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 8)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)
                }
            }
        }
        .onAppear { appeared = true }
    }
}

#Preview { SplashScreen() }
