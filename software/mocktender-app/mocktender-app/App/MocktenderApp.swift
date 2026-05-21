import SwiftUI

@main
struct MocktenderApp: App {
    @State private var ble = BluetoothManager.shared
    @State private var app = AppState()

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
                .environment(ble)
                .preferredColorScheme(.light)
        }
    }
}
