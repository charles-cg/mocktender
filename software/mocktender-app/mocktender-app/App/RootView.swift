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

                // Machine-state overlays. Calibrate / Maintenance / Cleaning
                // fully cover the current screen until the firmware moves on.
                // Only one is ever visible at a time — they're driven directly
                // by the FSM state byte in the BLE packet.
                if ble.machineState == .calibrate {
                    CalibrationOverlay()
                        .zIndex(70)
                }
                if ble.machineState == .maintenance {
                    MaintenanceOverlay()
                        .zIndex(70)
                }
                if ble.machineState == .cleaning {
                    CleaningOverlay()
                        .zIndex(70)
                }

                // Refill confirmation banner, slides in over the top of any
                // active screen and auto-dismisses (BluetoothManager clears
                // it after ~3 s).
                if let r = ble.refillBanner {
                    VStack {
                        RefillBanner(data: r)
                            .padding(.top, 56)
                        Spacer()
                    }
                    .zIndex(75)
                }
                if let l = ble.lowBottleBanner {
                    VStack {
                        LowBottleBanner(data: l)
                            .padding(.top, 56)
                        Spacer()
                    }
                    .zIndex(76)
                }

                // Firmware-driven hard error: cover the entire app, block
                // every gesture, and wait for the physical reset button. The
                // firmware emits state == .error continuously until reset; the
                // next non-error packet flips machineState and hides this.
                if ble.machineState == .error {
                    MachineErrorScreen(kind: ble.lastError)
                        .zIndex(90)
                }
            }
        }
        .ignoresSafeArea()
        .foregroundStyle(dispenseActive ? Color.white : Color(hex: 0x0A2350))
        .animation(.easeInOut(duration: 0.25), value: app.screen)
        .animation(.easeInOut(duration: 0.25), value: ble.machineState)
        .animation(.easeInOut(duration: 0.25), value: ble.refillBanner)
        .animation(.easeInOut(duration: 0.25), value: ble.lowBottleBanner)
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
