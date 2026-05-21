import SwiftUI

struct RootView: View {
    @Environment(BluetoothManager.self) private var ble
    @Bindable var app: AppState

    var body: some View {
        let dispenseActive = app.screen == .dispense || app.screen == .deliver
        // AeroScene now layers the dim *under* the content, so dispense and
        // deliver UI sits above the wash and stays bright.
        AeroScene(palette: app.palette, dimmed: dispenseActive) {
            ZStack {
                switch app.screen {
                case .connect:
                    ConnectScreen { app.screen = .home }
                case .home:
                    HomeScreen(app: app)
                case .detail:
                    DetailScreen(app: app, onDispense: startDispense)
                case .bottles:
                    BottlesScreen(app: app)
                case .dispense:
                    DispenseScreen(drink: app.selectedDrink, cup: ble.cupSize,
                                   onCancel: cancelDispense)
                case .deliver:
                    DeliverScreen(drink: app.selectedDrink, cup: ble.cupSize,
                                  onCupRemoved: cupRemoved)
                }

                if let e = ble.lastError {
                    ErrorOverlay(
                        kind: e,
                        onDismiss: { ble.lastError = nil; cancelDispense() },
                        onRetry:   { ble.lastError = nil; startDispense() }
                    )
                    .zIndex(80)
                }
            }
        }
        .ignoresSafeArea()
        .foregroundStyle(dispenseActive ? Color.white : Color(hex: 0x0A2350))
        .animation(.easeInOut(duration: 0.25), value: app.screen)
    }

    // MARK: - Dispense lifecycle

    private func startDispense() {
        ble.sendDispense(drink: app.selectedDrink, cup: ble.cupSize)
        app.screen = .dispense
        ble.simulateDispense(
            drink: app.selectedDrink,
            cup: ble.cupSize,
            speed: app.pourSpeed,
            injectError: faultToError(app.injectFault),
            injectDisconnect: app.injectFault == .disconnect,
            onError: {
                // overlay shown via ble.lastError
            },
            onComplete: {
                // Only fires when the pour actually reaches 100%; cancel
                // and error paths break out before this point.
                guard app.screen == .dispense else { return }
                app.screen = .deliver
            }
        )
    }

    private func cancelDispense() {
        ble.cancelDispense()
        ble.bleLostDuringDispense = false
        ble.lastError = nil
        app.screen = .detail
    }

    private func cupRemoved() {
        ble.dispenseProgress = 0
        ble.activePumpId = nil
        ble.reportCupRemoved()
        if ble.bleLostDuringDispense {
            ble.bleLostDuringDispense = false
            ble.isConnected = false
            app.screen = .connect
        } else {
            app.screen = .home
        }
    }

    private func faultToError(_ f: AppState.InjectFault) -> MachineError? {
        switch f {
        case .none, .disconnect: return nil
        case .cup:    return .cupRemoved
        case .liquid: return .lowLiquid(pumpShort: "")
        }
    }
}
