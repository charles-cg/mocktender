import SwiftUI

enum GlassTint {
    case light, dark, tinted
    var bg: Color {
        switch self {
        case .light:  return Color.white.opacity(0.70)
        case .dark:   return Color(red: 15/255, green: 30/255, blue: 60/255, opacity: 0.32)
        case .tinted: return Color(red: 230/255, green: 244/255, blue: 255/255, opacity: 0.65)
        }
    }
    var edge: Color {
        switch self {
        case .light, .tinted: return Color.white.opacity(0.9)
        case .dark:           return Color.white.opacity(0.30)
        }
    }
    var shadow: Color {
        switch self {
        case .light:  return Color(red: 30/255, green: 60/255, blue: 110/255, opacity: 0.08)
        case .dark:   return Color.black.opacity(0.35)
        case .tinted: return Color(red: 40/255, green: 90/255, blue: 160/255, opacity: 0.10)
        }
    }
    var shadowRadius: CGFloat { self == .dark ? 18 : 10 }
    var shadowOffsetY: CGFloat { self == .dark ? 14 : 6 }
}

struct GlassPanel<Content: View>: View {
    var radius: CGFloat = 24
    var tint: GlassTint = .light
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.bg)
                    .background(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(tint.edge, lineWidth: 0.5)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Color.white.opacity(0.6), lineWidth: 1)
                            .blur(radius: 1)
                            .mask(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                                    .fill(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                            )
                    )
            )
            .shadow(color: tint.shadow, radius: tint.shadowRadius, x: 0, y: tint.shadowOffsetY)
    }
}

struct GlassPill<Content: View>: View {
    var tint: GlassTint = .light
    var height: CGFloat = 36
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        let pill = HStack(spacing: 6) { content() }
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(
                Capsule().fill(tint.bg)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().stroke(tint.edge, lineWidth: 0.5))
            )
            .shadow(color: tint.shadow, radius: 8, x: 0, y: 3)

        if let action {
            Button(action: action) { pill }
                .buttonStyle(.plain)
        } else {
            pill
        }
    }
}

/// Visual variants for `HeaderPill`.
///
/// - `.data`  : read-only data display. Flatter — translucent glass,
///              no shadow, no chevron. Reads as a status chip, not a control.
/// - `.button`: interactive. Accent-tinted background, trailing chevron,
///              soft shadow — clearly tappable.
enum HeaderPillStyle {
    case data
    case button
}

struct HeaderPill<Content: View>: View {
    var style: HeaderPillStyle = .data
    var action: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        switch style {
        case .data:
            // Data pills are tappable when an action is supplied (e.g. the
            // Back pill on Detail / Bottles screens). Visual stays flat —
            // we only add hit testing and a subtle press-down.
            if let action {
                Button(action: action) { dataChip }
                    .buttonStyle(HeaderPillPressStyle())
            } else {
                dataChip
            }
        case .button:
            if let action {
                Button(action: action) { buttonChip }
                    .buttonStyle(HeaderPillPressStyle())
            } else {
                buttonChip
            }
        }
    }

    private var dataChip: some View {
        HStack(spacing: 6) {
            content()
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A2350).opacity(0.85))
                .monospacedDigit()
                .kerning(-0.1)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.55))
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule().stroke(Color(hex: 0x0A2350).opacity(0.08), lineWidth: 0.5)
                )
        )
    }

    private var buttonChip: some View {
        HStack(spacing: 6) {
            content()
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(hex: 0x0A2350))
                .monospacedDigit()
                .kerning(-0.1)
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Color(hex: 0x0A2350).opacity(0.55))
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xE8F4FF), Color(hex: 0xCFE6FB)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule().stroke(Color(hex: 0x7FB6E8).opacity(0.55), lineWidth: 0.7)
                )
        )
        .shadow(color: Color(hex: 0x2D8DF0).opacity(0.18), radius: 5, x: 0, y: 2)
    }
}

private struct HeaderPillPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct GlassButton: View {
    let title: String
    var primary: Bool = false
    var danger: Bool = false
    var full: Bool = false
    var disabled: Bool = false
    var action: () -> Void

    @GestureState private var pressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if primary {
                    LinearGradient(
                        colors: [Color(hex: 0x7FD2FF), Color(hex: 0x2D8DF0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    // top gloss
                    VStack {
                        LinearGradient(colors: [Color.white.opacity(0.5), .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 16)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)
                            .clipShape(Capsule())
                        Spacer()
                    }
                } else {
                    Color.white.opacity(0.85)
                        .background(.ultraThinMaterial)
                }

                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundStyle(textColor)
            }
            .frame(maxWidth: full ? .infinity : nil)
            .frame(height: 54)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(primary ? Color.white.opacity(0.4) : Color.white.opacity(0.95), lineWidth: 0.5)
            )
            .shadow(color: primary
                    ? Color(red: 45/255, green: 141/255, blue: 240/255).opacity(0.35)
                    : Color(red: 20/255, green: 40/255, blue: 80/255).opacity(0.10),
                    radius: primary ? 14 : 9, x: 0, y: primary ? 8 : 4)
            .opacity(disabled ? 0.5 : 1)
            .scaleEffect(pressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: pressed)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .simultaneousGesture(DragGesture(minimumDistance: 0).updating($pressed) { _, s, _ in s = true })
    }

    private var textColor: Color {
        if primary { return .white }
        if danger { return Color(hex: 0xC52C2C) }
        return Color(hex: 0x0A2350)
    }
}

// MARK: - Pills used in headers

struct StatusPill: View {
    let connected: Bool
    var body: some View {
        HeaderPill(style: .data) {
            Circle()
                .fill(connected ? Color(hex: 0x22C769) : Color(hex: 0xC52C2C))
                .frame(width: 7, height: 7)
                .shadow(color: connected ? Color(hex: 0x22C769) : Color(hex: 0xC52C2C),
                        radius: 3)
            Text(connected ? "MT-01" : "Offline")
        }
    }
}

struct BottlesPill: View {
    let bottles: [Bottle]
    let action: () -> Void
    var body: some View {
        let lowest = bottles.map(\.remaining).min() ?? 1000
        let low = lowest < 200
        HeaderPill(style: .button, action: action) {
            BottleGlyph()
            Text("Bottles")
            if low {
                Circle().fill(Color(hex: 0xC52C2C))
                    .frame(width: 6, height: 6)
                    .shadow(color: Color(hex: 0xC52C2C).opacity(0.8), radius: 3)
            }
        }
    }

    private struct BottleGlyph: View {
        var body: some View {
            ZStack {
                // cap
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: 0x0A2350).opacity(0.5))
                    .frame(width: 4, height: 3)
                    .offset(y: -5.5)
                // body outline
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color(hex: 0x0A2350), lineWidth: 1.4)
                    .frame(width: 8, height: 14)
                    .offset(y: 0.5)
                // liquid
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(hex: 0x7FD2FF))
                    .frame(width: 6, height: 5)
                    .offset(y: 3.5)
            }
            .frame(width: 10, height: 14)
        }
    }
}

struct CupSizeBadge: View {
    let cup: CupSize
    var body: some View {
        HeaderPill(style: .data) {
            CupGlyph(size: cup, large: false)
            if cup == .empty {
                Text("No cup")
            } else {
                Text("\(cup.label) · \(cup.ml) ml")
            }
        }
    }
}

struct CupGlyph: View {
    let size: CupSize
    var large: Bool = false

    var body: some View {
        let (w, h): (CGFloat, CGFloat) = {
            if large {
                switch size { case .empty: return (33, 42); case .small: return (26, 32);
                               case .medium: return (33, 42); case .large: return (40, 50) }
            } else {
                switch size { case .empty: return (15, 17); case .small: return (12, 14);
                               case .medium: return (15, 17); case .large: return (18, 20) }
            }
        }()
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 3, bottomLeading: 5, bottomTrailing: 5, topTrailing: 3),
                style: .continuous
            )
            .fill(LinearGradient(
                colors: [Color.white.opacity(0.7), Color(red: 180/255, green: 220/255, blue: 255/255, opacity: 0.45)],
                startPoint: .top, endPoint: .bottom))
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 3, bottomLeading: 5, bottomTrailing: 5, topTrailing: 3),
                    style: .continuous
                )
                .stroke(Color(hex: 0x0A2350).opacity(0.25), lineWidth: 0.5)
            )
            .frame(width: w, height: h)

            if size != .empty {
                LinearGradient(colors: [
                    Color(red: 120/255, green: 210/255, blue: 255/255, opacity: 0.5),
                    Color(red: 40/255, green: 140/255, blue: 240/255, opacity: 0.65)
                ], startPoint: .top, endPoint: .bottom)
                .frame(width: w, height: h * 0.45)
                .clipShape(
                    UnevenRoundedRectangle(
                        cornerRadii: .init(topLeading: 0, bottomLeading: 5, bottomTrailing: 5, topTrailing: 0)
                    )
                )
            }
        }
        .frame(width: large ? 48 : 20, height: large ? 56 : 20)
    }
}
