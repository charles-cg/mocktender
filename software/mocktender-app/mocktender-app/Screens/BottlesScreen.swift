import SwiftUI

struct BottlesScreen: View {
    @Environment(BluetoothManager.self) private var ble
    @Bindable var app: AppState

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Spacer().frame(height: 110)
                    Text("Bottles")
                        .font(.system(size: 34, weight: .bold))
                        .kerning(-0.6)
                        .foregroundStyle(Color(hex: 0x0A2350))
                        .padding(.horizontal, 22)
                        .padding(.bottom, 22)

                    GlassPanel(padding: 18) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 2),
                                  spacing: 22) {
                            ForEach(ble.bottles) { b in
                                if let p = Catalog.pump(b.id) {
                                    BottleStrip(pump: p, remaining: b.remaining, capacity: b.capacity)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
            }

            HeaderPill(action: { app.screen = .home }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .bold))
                Text("Back")
            }
            .padding(.leading, 16)
            .padding(.top, 60)
        }
    }
}
