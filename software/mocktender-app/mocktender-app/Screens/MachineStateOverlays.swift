import SwiftUI

// Full-screen overlays that mirror non-IDLE firmware FSM states. RootView
// stacks the appropriate one on top of the current screen and clears it the
// moment the machine reports IDLE (or transitions out of the state).

// MARK: - Calibration

struct CalibrationOverlay: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(hex: 0x0A2350).opacity(0.88)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: 0.28)
                        .stroke(
                            AngularGradient(
                                colors: [Color(hex: 0x7FD2FF), Color.white],
                                center: .center),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(pulse ? 360 : 0))
                        .animation(
                            .linear(duration: 1.2).repeatForever(autoreverses: false),
                            value: pulse
                        )
                }
                .frame(width: 92, height: 92)
                .shadow(color: Color(hex: 0x7FD2FF).opacity(0.6), radius: 12)

                VStack(spacing: 6) {
                    Text("Calibrating")
                        .font(.system(size: 26, weight: .bold))
                        .kerning(-0.3)
                        .foregroundStyle(.white)
                    Text("Letting the scale settle.\nKeep the tray clear.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear { pulse = true }
        .transition(.opacity)
    }
}

// MARK: - Maintenance

struct MaintenanceOverlay: View {
    /// The sub-mode the operator currently has selected on the front panel.
    /// Driven by the firmware's maintenance packets (cup field).
    let mode: BluetoothManager.MaintenanceMode
    /// The pump dialled in on the front-panel pot, as reported in the
    /// maintenance packet's error field. 0…5 = a single pump (P1…P6),
    /// 6 = all pumps, `nil` = not yet known.
    let selectedPump: Int?

    /// Human-readable description of the pot selection for the operator.
    private var selectionText: String {
        guard let sel = selectedPump else { return "Reading selector…" }
        if sel == 6 { return "All pumps" }
        guard Catalog.pumps.indices.contains(sel) else { return "—" }
        let p = Catalog.pumps[sel]
        return "\(p.code) · \(p.name)"
    }

    /// Tint for the selection chip — the dialled pump's colour, or a neutral
    /// blue for "all pumps" / unknown.
    private var selectionColor: Color {
        guard let sel = selectedPump, sel != 6,
              Catalog.pumps.indices.contains(sel) else { return Color(hex: 0x2E7DF6) }
        return Catalog.pumps[sel].color
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
            GlassPanel(radius: 28, padding: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x0A2350))
                    Text("Maintenance")
                        .font(.system(size: 22, weight: .bold))
                        .kerning(-0.3)
                        .foregroundStyle(Color(hex: 0x0A2350))
                    Text("Tap the maintenance button to switch, then\npress Start to run the highlighted action.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x0A2350).opacity(0.65))

                    HStack(spacing: 12) {
                        ModePill(icon: "drop.fill", label: "Clean",
                                 selected: mode == .clean)
                        ModePill(icon: "arrow.clockwise", label: "Refill",
                                 selected: mode == .refill)
                    }
                    .padding(.top, 2)

                    // Which pump the front-panel pot currently selects for the
                    // clean/refill action. Mirrors the firmware's globalPump.
                    HStack(spacing: 8) {
                        Image(systemName: selectedPump == 6
                              ? "square.grid.2x2.fill" : "spigot.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text(selectionText)
                            .font(.system(size: 13, weight: .bold))
                            .kerning(-0.2)
                            .lineLimit(1)
                    }
                    .foregroundStyle(selectionColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(selectionColor.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selectionColor.opacity(0.35), lineWidth: 1)
                    )
                    .padding(.top, 4)
                    .animation(.easeInOut(duration: 0.2), value: selectedPump)
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal, 24)
        }
        .animation(.easeInOut(duration: 0.2), value: mode)
        .transition(.opacity)
    }

    /// One selectable maintenance action. The highlighted pill mirrors the
    /// machine's currently-armed selection.
    private struct ModePill: View {
        let icon: String
        let label: String
        let selected: Bool

        var body: some View {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                Text(label)
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(selected ? Color.white : Color(hex: 0x0A2350).opacity(0.55))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected
                          ? AnyShapeStyle(LinearGradient(
                                colors: [Color(hex: 0x2E7DF6), Color(hex: 0x0A2350)],
                                startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color(hex: 0x0A2350).opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.white.opacity(0.5) : Color.clear,
                            lineWidth: 1)
            )
            .shadow(color: selected ? Color(hex: 0x2E7DF6).opacity(0.35) : .clear,
                    radius: 8, y: 4)
        }
    }
}

// MARK: - Cleaning

struct CleaningOverlay: View {
    @State private var drip = false

    var body: some View {
        ZStack {
            Color(hex: 0x06203D).opacity(0.85)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 96, height: 96)
                    Image(systemName: "drop.fill")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(Color(hex: 0x7FD2FF))
                        .offset(y: drip ? 6 : -6)
                        .animation(
                            .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                            value: drip
                        )
                }
                .shadow(color: Color(hex: 0x7FD2FF).opacity(0.5), radius: 14)

                VStack(spacing: 6) {
                    Text("Cleaning in progress")
                        .font(.system(size: 24, weight: .bold))
                        .kerning(-0.3)
                        .foregroundStyle(.white)
                    Text("The selected pump is being flushed.\nKeep the catch cup in place.")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 32)
        }
        .onAppear { drip = true }
        .transition(.opacity)
    }
}

// MARK: - Refill banner

struct RefillBanner: View {
    let data: RefillBannerData

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0x22C769), Color(hex: 0x0E8C46)],
                        startPoint: .top, endPoint: .bottom))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .shadow(color: Color(hex: 0x22C769).opacity(0.35), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(Color(hex: 0x0A2350))
                Text(subtitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0A2350).opacity(0.6))
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 0.5)
                )
        )
        .shadow(color: Color(red: 20/255, green: 40/255, blue: 80/255).opacity(0.18),
                radius: 10, y: 6)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var title: String {
        if data.pumpShort == nil { return "All bottles refilled" }
        return "Bottle refilled"
    }
    private var subtitle: String {
        if let short = data.pumpShort {
            let cap = Catalog.pumps.first { $0.short == short }?.capacityMl ?? 750
            return "\(short) is back to \(Int(cap)) ml."
        }
        return "All six bottles topped up."
    }
}

// MARK: - Low bottle banner

struct LowBottleBanner: View {
    let data: LowBottleBannerData

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(hex: 0xFFB347), Color(hex: 0xE07A1F)],
                        startPoint: .top, endPoint: .bottom))
                Image(systemName: "exclamationmark")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 32, height: 32)
            .shadow(color: Color(hex: 0xE07A1F).opacity(0.35), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text("\(data.pumpName) is low")
                    .font(.system(size: 14, weight: .bold))
                    .kerning(-0.2)
                    .foregroundStyle(Color(hex: 0x0A2350))
                Text("\(data.pumpShort) is at ~15% — refill soon.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0A2350).opacity(0.6))
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.85))
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.9), lineWidth: 0.5)
                )
        )
        .shadow(color: Color(red: 20/255, green: 40/255, blue: 80/255).opacity(0.18),
                radius: 10, y: 6)
        .padding(.horizontal, 16)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}
