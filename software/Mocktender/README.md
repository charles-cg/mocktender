# Mocktender (SwiftUI)

Source-only SwiftUI implementation of the Mocktender design (Frutiger Aero ×
Liquid Glass). Targets **iOS 18** (one major behind the current iOS 26 — picks
up `@Observable`, `UnevenRoundedRectangle`, and the Layout protocol while
staying on a well-shaken release).

## Setup

1. Xcode → New Project → iOS / App. Product name `Mocktender`. Interface
   SwiftUI, language Swift, **iOS 18.0** deployment target.
2. Delete the auto-generated `MocktenderApp.swift` and `ContentView.swift`.
3. Drag the contents of this folder into the project (`App/`, `Models/`,
   `Bluetooth/`, `Components/`, `Screens/`).
4. Build & run.

## Architecture

- `BluetoothManager` is an `@Observable` singleton (`BluetoothManager.shared`)
  injected via `.environment(_:)`. The CoreBluetooth plumbing is stubbed —
  the existing properties (`isConnected`, `bleLostDuringDispense`, `cupSize`,
  `bottles`, `dispenseProgress`, `activePumpId`, `lastError`) match the packet
  fields the Atmega16 firmware emits.
- `AppState` is the screen router + dev-harness tweak state.
- Views read state from the environment manager and call methods on it; they
  never own BLE state directly.

## Implementing real BLE

Replace the `simulateDispense` / `startScan` / `connect` stubs in
`Bluetooth/BluetoothManager.swift` with `CBCentralManager` code that:

- Scans for the MT-01 service UUID,
- Subscribes to the notify characteristic (cup size / bottle remaining /
  errors / progress),
- Writes a 2-byte command `drink.char + cup.char` on dispense,
- Sets `bleLostDuringDispense = true` (without cancelling the pour) when the
  link drops while `dispenseProgress > 0 && < 1`.

The views will follow along unchanged.

## Flow

`connect → home ⇄ detail → dispense → deliver → home` (or `→ connect` if BLE
was lost mid-pour). Errors raise `ErrorOverlay` over whatever screen is
active.

The dispense pour is **blocking** (hold-to-cancel only) and the deliver screen
locks the UI until the load cell reports the cup was lifted.
