import SwiftUI

struct HomeScreen: View {
    @Environment(BluetoothManager.self) private var ble
    @Bindable var app: AppState

    var body: some View {
        // Two stacked layers: the pinned nav bar (header pills) on top,
        // and a ScrollView underneath with title + grid. The nav bar stays
        // visible no matter how far the grid scrolls.
        VStack(spacing: 0) {
            navBar
                .padding(.horizontal, 18)
                .padding(.top, 60)
                .padding(.bottom, 12)
                .background(
                    // Soft fade so the orbs don't visually jam into the
                    // pills as they scroll past — only on the very bottom
                    // of the bar, kept light to stay Aero.
                    LinearGradient(
                        colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                )
                .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Drinks")
                        .font(.system(size: 34, weight: .bold))
                        .kerning(-0.6)
                        .foregroundStyle(Color(hex: 0x0A2350))
                        .padding(.horizontal, 22)
                        .padding(.top, 4)
                        .padding(.bottom, 18)

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                              spacing: 18) {
                        ForEach(Catalog.drinks) { d in
                            DrinkOrb(drink: d, size: 108) {
                                app.selectedDrink = d
                                app.screen = .detail
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 36)
                }
            }
        }
    }

    private var navBar: some View {
        HStack(alignment: .center) {
            StatusPill(connected: ble.isConnected) { app.screen = .connect }
            Spacer()
            HStack(spacing: 6) {
                BottlesPill(bottles: ble.bottles) { app.screen = .bottles }
                CupSizeBadge(cup: ble.cupSize)
            }
        }
    }
}
