import Foundation
import Observation
import CoreBluetooth

// BLE bridge to the Atmega16.
//
// The firmware speaks plain UART; the machine has a BLE-to-UART module wired
// to RXD/TXD. The default service/characteristic UUIDs below match a HM-10
// (and the many HM-10 clones — JDY-08/MLT-BT05). If your module uses a
// different scheme (e.g. Nordic UART), override the constants in
// `BluetoothManager.BLEConfig`.
//
// This pass implements TX only — the app writes the recipe character
// ('1'..'9' or 'A', see firmware/src/interrupts.c) to the module's writable
// characteristic, which the module forwards to the AVR's USART RX. RX from
// the machine back to the app is deferred to a later prompt.

@Observable
final class BluetoothManager: NSObject {
    static let shared = BluetoothManager()

    // MARK: - BLE configuration
    enum BLEConfig {
        /// HM-10 (and most CC2540/CC2541-based UART bridges) advertise FFE0.
        static let serviceUUID = CBUUID(string: "FFE0")
        /// The same characteristic is usually used for both TX and RX
        /// (write-without-response + notify).
        static let txCharacteristicUUID = CBUUID(string: "FFE1")
    }

    // MARK: - Inbound state (driven by packets from the machine; populated
    // by future RX work)
    var isConnected: Bool = false
    /// Set true when BLE drops *during* an active dispense. The pour keeps
    /// running on the machine; the UI surfaces the Connect screen only after
    /// the cup is removed.
    var bleLostDuringDispense: Bool = false
    var cupSize: CupSize = .medium
    var bottles: [Bottle] = Catalog.pumps.map { Bottle(id: $0.id, remaining: 1000 - Double.random(in: 0...250)) }
    var lastError: MachineError? = nil

    /// Pour progress 0…1. Until the firmware streams real progress packets,
    /// this is driven by the local `simulateDispense` clock so the UI animates.
    var dispenseProgress: Double = 0
    var activePumpId: String? = nil

    // MARK: - Discovery (Connect screen)
    struct Discovered: Identifiable, Hashable {
        let id: String          // peripheral.identifier.uuidString
        let name: String
        let rssi: Int
        let paired: Bool
    }
    var discovered: [Discovered] = []
    var scanning: Bool = false
    var connecting: Discovered? = nil

    /// Surfaces the last TX outcome so views/devtools can show it. Stays
    /// `nil` on success.
    var lastTxError: String? = nil

    /// Surfaces the central's state to the UI so the Connect screen can tell
    /// the user why it isn't finding anything (Bluetooth off, permission
    /// denied, no Info.plist key, etc.).
    var bleStatusMessage: String? = nil

    /// Handle for the currently running simulated pour, so the UI can abort
    /// it without a stale completion firing after the user hits Cancel.
    private var dispenseTask: Task<Void, Never>?

    // MARK: - CoreBluetooth
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?
    private var peripheralsById: [UUID: CBPeripheral] = [:]
    /// True when `startScan` was called before the central reached
    /// `.poweredOn`. We retry once the state callback fires.
    private var pendingScan = false

    override private init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - Commands the UI issues

    func startScan() {
        scanning = true
        discovered = []
        peripheralsById.removeAll()
        if central.state == .poweredOn {
            beginScanning()
        } else {
            // CBCentralManager isn't ready yet (radio booting, or user hasn't
            // granted permission). Defer until centralManagerDidUpdateState.
            pendingScan = true
        }
    }

    /// Names that identify a Mocktender-compatible BLE-UART bridge. Match is
    /// case-insensitive substring, so "BT05-A", "MLT-BT05", etc. all qualify.
    private static let knownNames = ["BT05", "BT-05", "MLT-BT05", "HM-10", "HMSoft", "MT-01", "Mocktender", "JDY"]

    private func beginScanning() {
        // HM-10-clones like the BT-05 don't always include their service UUID
        // in the advertisement packet, so we scan without a service filter
        // (`nil`) and filter in the delegate by name/service. Duplicates off,
        // so we don't redraw the list on every advertisement burst.
        central.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        print("[BLE] scanForPeripherals started")
    }

    private func isRelevant(name: String?, advertisedServices: [CBUUID]?) -> Bool {
        if let services = advertisedServices, services.contains(BLEConfig.serviceUUID) {
            return true
        }
        guard let name, !name.isEmpty else { return false }
        let lower = name.lowercased()
        return Self.knownNames.contains { lower.contains($0.lowercased()) }
    }

    func stopScan() {
        if central.isScanning {
            central.stopScan()
        }
        scanning = false
    }

    func connect(to device: Discovered) {
        guard let uuid = UUID(uuidString: device.id),
              let p = peripheralsById[uuid] else {
            return
        }
        if central.isScanning {
            central.stopScan()
        }
        scanning = false
        connecting = device
        peripheral = p
        p.delegate = self
        central.connect(p, options: nil)
    }

    /// Send the recipe selector to the machine. The Atmega's USART RX ISR
    /// accepts '1'..'9' and 'A'. A future revision can also include the cup
    /// size byte; for now the machine still drives cup size locally via its
    /// load cell.
    @discardableResult
    func sendDispense(drink: Drink, cup: CupSize) -> Bool {
        guard let p = peripheral, let c = txChar else {
            lastTxError = "Not connected"
            return false
        }
        guard let ascii = drink.char.asciiValue else {
            lastTxError = "Drink has no ASCII char"
            return false
        }
        let writeType: CBCharacteristicWriteType =
            c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        p.writeValue(Data([ascii]), for: c, type: writeType)
        lastTxError = nil
        return true
    }

    func cancelDispense() {
        // The firmware ignores anything outside '1'..'9','A', so there's no
        // explicit cancel byte today. We stop the local sim and surface the
        // cancel in the UI; a future firmware change can add a cancel char.
        dispenseTask?.cancel()
        dispenseTask = nil
        dispenseProgress = 0
        activePumpId = nil
    }

    func disconnect() {
        if let p = peripheral {
            central.cancelPeripheralConnection(p)
        }
    }

    // MARK: - Atmega simulation (preview / dev harness)

    /// Drive a fake pour locally so the UI can be developed without hardware.
    /// `onComplete` only fires if the pour reaches 100% — a cancel via
    /// `cancelDispense()` (or an injected error) breaks out without calling
    /// it, so the UI never gets a stale "deliver" transition after a cancel.
    func simulateDispense(drink: Drink, cup: CupSize,
                          speed: Double = 1.0,
                          injectError: MachineError? = nil,
                          injectDisconnect: Bool = false,
                          onError: @MainActor @escaping () -> Void = {},
                          onComplete: @MainActor @escaping () -> Void) {
        dispenseTask?.cancel()
        dispenseProgress = 0
        lastError = nil
        activePumpId = nil

        dispenseTask = Task { @MainActor [weak self] in
            await self?.runSimulatedDispense(
                drink: drink, cup: cup, speed: speed,
                injectError: injectError, injectDisconnect: injectDisconnect,
                onError: onError, onComplete: onComplete
            )
        }
    }

    @MainActor
    private func runSimulatedDispense(drink: Drink, cup: CupSize,
                                      speed: Double,
                                      injectError: MachineError?,
                                      injectDisconnect: Bool,
                                      onError: @MainActor @escaping () -> Void,
                                      onComplete: @MainActor @escaping () -> Void) async {

        // Total pour time mirrors firmware/src/states.c::calculateTime():
        //   time_ms = volume_ml * 75 / 2  =>  37.5 ms per mL
        // i.e. the 26.67 mL/s flow rate declared in firmware/include/config.h
        // (`FLOWRATE_X100 = 2667`). `speed` is a dev-only tweak; on hardware
        // it's pinned at 1.0×.
        //
        // The machine takes a beat between receiving the recipe char and the
        // first pump spinning up (UART RX → ISR latch → main-loop transition
        // → pump enable). We model that with a 1.5 s pump-init pause during
        // which `dispenseProgress` stays at 0 and no pump is active — gives
        // the UI a calmer "getting ready" moment instead of jumping straight
        // into the percentage counter.
        let msPerMl = 75.0 / 2.0    // 37.5
        let pumpInitMs = 350.0 / max(0.1, speed)
        let totalMs = max(100.0, Double(cup.ml) * msPerMl / max(0.1, speed))
        let stepMs: Double = 33

        // Pump-init pause — progress visibly idles at 0 while the
        // machine wakes up.
        let initSteps = Int(pumpInitMs / stepMs)
        for _ in 0..<initSteps {
            try? await Task.sleep(for: .milliseconds(Int(stepMs)))
            if Task.isCancelled { return }
        }

        let start = Date()

        let sequence: [(pump: String, endPct: Double)] = {
            var acc: [(String, Double)] = []
            var running = 0.0
            for pump in Catalog.pumps {
                if let pct = drink.ratios[pump.id], pct > 0 {
                    running += Double(pct)
                    acc.append((pump.id, running))
                }
            }
            return acc
        }()

        let errorAt: Double? = {
            switch injectError {
            case .cupRemoved: return 38
            case .lowLiquid:  return 62
            default:          return injectDisconnect ? 25 : nil
            }
        }()

        var firedDisconnect = false
        while dispenseProgress < 1.0 {
            try? await Task.sleep(for: .milliseconds(Int(stepMs)))
            if Task.isCancelled { return }
            let elapsed = Date().timeIntervalSince(start) * 1000
            let p = min(1.0, elapsed / totalMs)
            dispenseProgress = p

            for i in bottles.indices {
                if let pct = drink.ratios[bottles[i].id], pct > 0 {
                    let drain = (Double(pct) / 100.0) * Double(cup.ml) * (stepMs / totalMs)
                    bottles[i].remaining = max(0, bottles[i].remaining - drain)
                }
            }

            let cur = sequence.first { (p * 100) < $0.endPct }
            activePumpId = cur?.pump

            if let errAt = errorAt, p * 100 >= errAt {
                if injectDisconnect {
                    if !firedDisconnect {
                        firedDisconnect = true
                        isConnected = false
                        bleLostDuringDispense = true
                    }
                } else if let e = injectError {
                    lastError = e
                    onError()
                    return
                }
            }
        }

        activePumpId = nil
        onComplete()
    }

    // MARK: - Atmega simulation helpers (used by tweaks panel)
    func setSimulatedCupSize(_ size: CupSize) { cupSize = size }
    func refill(pumpId: String) {
        if let idx = bottles.firstIndex(where: { $0.id == pumpId }) {
            bottles[idx].remaining = 1000
        }
    }
    func reportCupRemoved() {
        // Atmega tray load-cell reports tray empty.
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("[BLE] central state =", central.state.rawValue)
        switch central.state {
        case .poweredOn:
            bleStatusMessage = nil
            if pendingScan {
                pendingScan = false
                beginScanning()
            }
        case .poweredOff:
            bleStatusMessage = "Bluetooth is off — turn it on in Settings."
            isConnected = false; scanning = false
            peripheral = nil; txChar = nil
        case .unauthorized:
            bleStatusMessage = "Bluetooth permission denied. Enable it in Settings → Mocktender → Bluetooth, and make sure NSBluetoothAlwaysUsageDescription is in Info.plist."
            isConnected = false; scanning = false
        case .unsupported:
            bleStatusMessage = "This device doesn't support BLE."
            isConnected = false; scanning = false
        case .resetting:
            bleStatusMessage = "Bluetooth resetting…"
        case .unknown:
            bleStatusMessage = "Initializing Bluetooth…"
        @unknown default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let resolvedName = peripheral.name ?? advName
        let advServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]

        // Show only Mocktender-compatible bridges. Drops AirPods, Apple
        // Watches, neighbors' smart bulbs, etc.
        guard isRelevant(name: resolvedName, advertisedServices: advServices) else {
            return
        }

        let name = resolvedName ?? "BT-05 (\(peripheral.identifier.uuidString.prefix(4)))"
        print("[BLE] match name=\(name) rssi=\(RSSI) services=\(advServices?.description ?? "—")")

        peripheralsById[peripheral.identifier] = peripheral

        let new = Discovered(
            id: peripheral.identifier.uuidString,
            name: name,
            rssi: RSSI.intValue,
            paired: false
        )
        if let idx = discovered.firstIndex(where: { $0.id == new.id }) {
            // Only update if RSSI changed by more than ±3 dBm — avoids
            // re-rendering the list on every advertisement.
            if abs(discovered[idx].rssi - new.rssi) >= 3 {
                discovered[idx] = new
            }
        } else {
            discovered.append(new)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connecting = nil
        peripheral.discoverServices([BLEConfig.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        connecting = nil
        lastTxError = "Failed to connect: \(error?.localizedDescription ?? "unknown")"
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        // Drop in the middle of a pour → silent until cup is removed,
        // per the design (see RootView). Otherwise, just clear connected.
        if dispenseProgress > 0 && dispenseProgress < 1 {
            bleLostDuringDispense = true
        }
        isConnected = false
        self.peripheral = nil
        self.txChar = nil
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            lastTxError = "Service discovery failed: \(error?.localizedDescription ?? "no services")"
            return
        }
        for s in services where s.uuid == BLEConfig.serviceUUID {
            peripheral.discoverCharacteristics([BLEConfig.txCharacteristicUUID], for: s)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let chars = service.characteristics else {
            lastTxError = "Characteristic discovery failed: \(error?.localizedDescription ?? "")"
            return
        }
        for c in chars where c.uuid == BLEConfig.txCharacteristicUUID {
            txChar = c
            isConnected = true
            lastTxError = nil
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            lastTxError = "Write failed: \(error.localizedDescription)"
        }
    }
}
