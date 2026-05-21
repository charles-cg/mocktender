import SwiftUI

struct ConnectScreen: View {
    @Environment(BluetoothManager.self) private var ble
    var onConnected: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 88)

            VStack(spacing: 18) {
                radar
                Text("Pair your machine")
                    .font(.system(size: 30, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(Color(hex: 0x0A2350))
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)

            Spacer().frame(height: 22)

            if let msg = ble.bleStatusMessage {
                Text(msg)
                    .font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(hex: 0xC52C2C))
                    .padding(.horizontal, 22)
                    .padding(.bottom, 10)
            }

            if ble.scanning || !ble.discovered.isEmpty {
                GlassPanel(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(ble.discovered.enumerated()), id: \.element.id) { i, d in
                            if i > 0 { Divider().opacity(0.4) }
                            deviceRow(d)
                        }
                        if ble.scanning && ble.discovered.isEmpty {
                            ForEach(0..<2, id: \.self) { _ in skeleton }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .padding(.horizontal, 22)
            }

            Spacer()

            GlassButton(
                title: ble.scanning
                    ? (ble.discovered.isEmpty ? "Scanning… (tap to stop)" : "Stop scan")
                    : (ble.discovered.isEmpty ? "Scan" : "Rescan"),
                primary: true, full: true
            ) {
                if ble.scanning { ble.stopScan() } else { ble.startScan() }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 28)
        }
        .onChange(of: ble.isConnected) { _, conn in
            if conn { onConnected() }
        }
    }

    private var radar: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                RadarRing(delay: Double(i) * 0.85)
            }
            Circle()
                .fill(RadialGradient(
                    colors: [Color(hex: 0xE8F9FF), Color(hex: 0x7FD2FF), Color(hex: 0x2D8DF0)],
                    center: UnitPoint(x: 0.3, y: 0.25),
                    startRadius: 0, endRadius: 80
                ))
                .frame(width: 104, height: 104)
                .shadow(color: Color(red: 45/255, green: 141/255, blue: 240/255, opacity: 0.32),
                        radius: 12, x: 0, y: 12)
                .overlay(
                    BluetoothRune()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4.2, lineCap: .round, lineJoin: .round))
                        .frame(width: 30, height: 46)
                )
        }
        .frame(width: 160, height: 160)
    }

    /// Canonical Bluetooth rune — two right-pointing triangles meeting at a
    /// center cross. The natural bounding box of the glyph is x:7-17, y:2-22
    /// (10w × 20h). We scale to fit the host rect and re-center, so the rune
    /// is geometrically centered no matter what frame it lands in.
    private struct BluetoothRune: Shape {
        func path(in rect: CGRect) -> Path {
            let glyphW: CGFloat = 10
            let glyphH: CGFloat = 20
            let scale = min(rect.width / glyphW, rect.height / glyphH)
            let drawnW = glyphW * scale
            let drawnH = glyphH * scale
            // Origin so that glyph-space (7, 2) lands at the top-left of the
            // centered draw box.
            let ox = rect.midX - drawnW / 2 - 7 * scale
            let oy = rect.midY - drawnH / 2 - 2 * scale
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: ox + x * scale, y: oy + y * scale)
            }
            var p = Path()
            p.move(to: pt(7, 7))
            p.addLine(to: pt(17, 17))
            p.addLine(to: pt(12, 22))
            p.addLine(to: pt(12, 2))
            p.addLine(to: pt(17, 7))
            p.addLine(to: pt(7, 17))
            return p
        }
    }

    private struct RadarRing: View {
        let delay: Double
        @State private var animating = false
        var body: some View {
            Circle()
                .stroke(Color(red: 45/255, green: 141/255, blue: 240/255, opacity: 0.55), lineWidth: 1.5)
                .frame(width: 160, height: 160)
                .scaleEffect(animating ? 1.6 : 0.65)
                .opacity(animating ? 0 : 0.7)
                .onAppear {
                    withAnimation(.easeOut(duration: 2.6).delay(delay).repeatForever(autoreverses: false)) {
                        animating = true
                    }
                }
        }
    }

    private var skeleton: some View {
        HStack(spacing: 12) {
            Circle().fill(Color(red: 180/255, green: 210/255, blue: 240/255, opacity: 0.4))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(red: 180/255, green: 210/255, blue: 240/255, opacity: 0.45))
                    .frame(height: 9).frame(maxWidth: 140, alignment: .leading)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 180/255, green: 210/255, blue: 240/255, opacity: 0.35))
                    .frame(height: 7).frame(maxWidth: 90, alignment: .leading)
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    @ViewBuilder
    private func deviceRow(_ d: BluetoothManager.Discovered) -> some View {
        Button {
            ble.connect(to: d)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0xE8F9FF), Color(hex: 0x7FD2FF)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(d.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0A2350))
                    Text("\(d.rssi) dBm")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x0A2350).opacity(0.55))
                }
                Spacer()
                if ble.connecting?.id == d.id {
                    ProgressView().tint(Color(hex: 0x0A2350))
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0A2350).opacity(0.35))
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(ble.connecting != nil)
    }
}
