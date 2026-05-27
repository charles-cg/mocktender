import SwiftUI

// Frutiger Aero / liquid-glass mark for Mocktender. The visual is a glossy
// blue glass orb with a stylized cocktail (martini) glyph inside, a top
// highlight arc, and a small floating bubble. The same shape is reused on
// the splash screen and — wrapped in `MocktenderAppIcon` — exported as the
// AppIcon PNG.
struct MocktenderLogo: View {
    var size: CGFloat = 160

    var body: some View {
        ZStack {
            orb
            martini
            gloss
            bubble
        }
        .frame(width: size, height: size)
    }

    // MARK: - Pieces

    private var orb: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(hex: 0xE6F5FF).opacity(0.95),
                            Color(hex: 0x7FD2FF).opacity(0.85),
                            Color(hex: 0x2D8DF0).opacity(0.95)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.32),
                        startRadius: size * 0.05,
                        endRadius: size * 0.55
                    )
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.8), lineWidth: size * 0.012)
                )
                .overlay(
                    Circle().stroke(Color(hex: 0x0A2350).opacity(0.18), lineWidth: size * 0.006)
                        .blur(radius: 0.4)
                )
                .shadow(color: Color(hex: 0x2D8DF0).opacity(0.35),
                        radius: size * 0.08, x: 0, y: size * 0.04)
        }
    }

    private var martini: some View {
        ZStack {
            // Liquid fill inside the bowl.
            MartiniLiquid()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.85), Color(hex: 0xE6F5FF).opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size * 0.46, height: size * 0.46)
                .offset(y: -size * 0.01)

            // White glass outline (bowl + stem + base).
            MartiniGlass()
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: size * 0.028, lineCap: .round, lineJoin: .round)
                )
                .frame(width: size * 0.46, height: size * 0.46)
                .shadow(color: Color(hex: 0x0A2350).opacity(0.25),
                        radius: size * 0.015, y: size * 0.008)
        }
    }

    private var gloss: some View {
        Ellipse()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.85), Color.white.opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: size * 0.62, height: size * 0.22)
            .offset(y: -size * 0.24)
            .blur(radius: size * 0.01)
            .allowsHitTesting(false)
    }

    private var bubble: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.white.opacity(0.95), Color.white.opacity(0.0)],
                    center: UnitPoint(x: 0.3, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.075
                )
            )
            .frame(width: size * 0.13, height: size * 0.13)
            .offset(x: size * 0.24, y: size * 0.22)
            .allowsHitTesting(false)
    }
}

// MARK: - Shapes

private struct MartiniGlass: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topY = rect.minY + rect.height * 0.16
        let bowlBottom = rect.minY + rect.height * 0.58
        let baseY = rect.maxY - rect.height * 0.08
        let inset = rect.width * 0.10

        // Bowl: open triangle (left rim → bowl bottom → right rim).
        p.move(to: CGPoint(x: rect.minX + inset, y: topY))
        p.addLine(to: CGPoint(x: rect.midX, y: bowlBottom))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: topY))

        // Stem.
        p.move(to: CGPoint(x: rect.midX, y: bowlBottom))
        p.addLine(to: CGPoint(x: rect.midX, y: baseY))

        // Base.
        p.move(to: CGPoint(x: rect.midX - rect.width * 0.22, y: baseY))
        p.addLine(to: CGPoint(x: rect.midX + rect.width * 0.22, y: baseY))
        return p
    }
}

private struct MartiniLiquid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let topY = rect.minY + rect.height * 0.22
        let bowlBottom = rect.minY + rect.height * 0.56
        let inset = rect.width * 0.16

        p.move(to: CGPoint(x: rect.minX + inset, y: topY))
        p.addLine(to: CGPoint(x: rect.midX, y: bowlBottom))
        p.addLine(to: CGPoint(x: rect.maxX - inset, y: topY))
        p.closeSubpath()
        return p
    }
}

// MARK: - App icon canvas

// Square, full-bleed version used to export the PNG that goes into
// Assets.xcassets/AppIcon.appiconset. iOS auto-masks app icons to a squircle,
// so we render to a square bitmap — no manual corner clipping needed for
// AppIcon, but we still round the corners when previewing in-app.
struct MocktenderAppIcon: View {
    var size: CGFloat = 1024
    var rounded: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xCFEAFF), Color(hex: 0x7FD2FF), Color(hex: 0x2D8DF0)],
                startPoint: .top, endPoint: .bottom
            )

            // Soft cloud blob, matches AeroScene.
            RadialGradient(
                colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                center: UnitPoint(x: 0.25, y: 0.2),
                startRadius: 0,
                endRadius: size * 0.55
            )
            .blur(radius: size * 0.02)

            MocktenderLogo(size: size * 0.78)
        }
        .frame(width: size, height: size)
        .clipShape(
            RoundedRectangle(cornerRadius: rounded ? size * 0.22 : 0, style: .continuous)
        )
    }
}

// MARK: - Export helper (dev-only)

// Renders `MocktenderAppIcon` to a 1024×1024 PNG inside the running
// container's Documents directory. Wire it up from a debug button
// (or temporarily inside `onAppear`) once, copy the file out via the
// simulator's File browser, and drag it into
// Assets.xcassets/AppIcon.appiconset.
enum LogoExport {
    @MainActor
    static func writeAppIconPNG() -> URL? {
        let renderer = ImageRenderer(content: MocktenderAppIcon(size: 1024))
        renderer.scale = 1
        guard let img = renderer.uiImage,
              let data = img.pngData() else { return nil }
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MocktenderAppIcon-1024.png")
        try? data.write(to: url)
        print("[LogoExport] wrote \(url.path)")
        return url
    }
}

#Preview("Logo")        { MocktenderLogo(size: 220) }
#Preview("App Icon")    { MocktenderAppIcon(size: 320, rounded: true) }
