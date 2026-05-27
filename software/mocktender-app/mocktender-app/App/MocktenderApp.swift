import SwiftUI

@main
struct MocktenderApp: App {
    @State private var ble = BluetoothManager.shared
    @State private var app = AppState()
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView(app: app)
                    .environment(ble)

                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .preferredColorScheme(.light)
            .task {
                NotificationManager.shared.requestAuthorization()
                NotificationManager.shared.refresh(bottles: ble.bottles)
                // Splash hold ~1.6 s, then fade into the first real screen.
                try? await Task.sleep(for: .milliseconds(1600))
                withAnimation(.easeOut(duration: 0.45)) {
                    showSplash = false
                }
            }
        }
    }
}
