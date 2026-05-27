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
    /// Cup size as last reported by the firmware. Defaults to `.empty` — the
    /// app blocks dispense until the tray load cell confirms a real cup is
    /// present (mirrors firmware `classifyCup`).
    var cupSize: CupSize = .empty
    /// Transient banner driven by REFILL→IDLE transitions in the firmware.
    /// Surfaces which bottle (or "all") was just refilled. Cleared by a
    /// short-lived task spawned in `apply(packet:)`.
    var refillBanner: RefillBannerData? = nil
    /// In-app "bottle just hit 15%" banner. Surfaced by `NotificationManager`
    /// when the app is foregrounded (the system notification is suppressed in
    /// that case). Auto-clears after ~3 s.
    var lowBottleBanner: LowBottleBannerData? = nil
    private var lowBottleBannerTask: Task<Void, Never>?

    func surfaceLowBottleBanner(_ data: LowBottleBannerData) {
        lowBottleBannerTask?.cancel()
        lowBottleBanner = data
        lowBottleBannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if self?.lowBottleBanner?.id == data.id {
                self?.lowBottleBanner = nil
            }
        }
    }
    /// Bottles start full at the firmware's per-bottle EEPROM capacity (750 mL,
    /// see firmware/src/eeprom.c). Real `remaining` arrives from the machine's
    /// status packets — `capacity - usedMl[i]`.
    var bottles: [Bottle] = Catalog.pumps.map { Bottle(id: $0.id, remaining: 750, capacity: 750) }
    var machineState: FirmwareState = .idle
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
    /// Streaming UART parser for inbound status packets from the Atmega.
    private var packetParser = PacketParser()
    /// Last `machineState` we observed. Used to detect the IDLE→ERROR
    /// transition so we only surface the overlay once per fault — the firmware
    /// keeps re-sending the ERROR packet ~1×/s and we don't want it popping
    /// back up after the user dismisses it.
    private var previousMachineState: FirmwareState = .idle
    /// Previous packet's `usedMl[]`. Used to detect REFILL→IDLE transitions
    /// per pump (non-zero → 0) so we can show which bottle was refilled.
    private var previousUsedMl: [UInt16] = Array(repeating: 0, count: 6)
    /// True once we've consumed at least one machine packet. Until then we
    /// avoid edge-triggering anything on initial defaults vs. live state.
    private var hasSeenPacket = false
    /// Task that auto-dismisses the refill banner after a few seconds.
    private var refillBannerTask: Task<Void, Never>?

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
        let stepMs: Double = 33

        // firmware/src/states.c::handleDispense polls HX711_get_mean_units(10)
        // inside its per-pump busy-wait loop. With the HX711 at ~10 SPS a
        // single 10-sample read blocks ~1 s, so when TIMER1_COMPA_vect fires
        // the loop doesn't notice pumpBusy=0 until the in-flight read
        // finishes — average ~500 ms, worst-case ~1 s. Pure C overhead
        // between pumps (for-tick + getRecipeRatio + PORTC set + dynamicDelay
        // chain) is ~640 cycles at 8 MHz ≈ 80 µs, i.e. invisible. Modelling
        // the HX711-bound gap is what makes the bar + lights match hardware.
        let interPumpGapMs: Double = 500.0 / max(0.1, speed)

        // Pump-init pause — progress visibly idles at 0 while the
        // machine wakes up.
        let initSteps = Int(pumpInitMs / stepMs)
        for _ in 0..<initSteps {
            try? await Task.sleep(for: .milliseconds(Int(stepMs)))
            if Task.isCancelled { return }
        }

        // Per-pump segments in the order the firmware visits them (P1…P6).
        let segments: [(pumpId: String, ml: Double)] = Catalog.pumps.compactMap { p in
            guard let pct = drink.ratios[p.id], pct > 0 else { return nil }
            return (p.id, Double(pct) / 100.0 * Double(cup.ml))
        }
        let totalMl = max(1.0, Double(cup.ml))

        let errorAt: Double? = {
            switch injectError {
            case .cupRemoved: return 38
            case .lowLiquid:  return 62
            default:          return injectDisconnect ? 25 : nil
            }
        }()

        var dispensedMl: Double = 0
        var firedDisconnect = false

        for (idx, seg) in segments.enumerated() {
            activePumpId = seg.pumpId
            let segMs = max(1.0, seg.ml * msPerMl / max(0.1, speed))
            let segStart = Date()

            var segElapsed: Double = 0
            while segElapsed < segMs {
                try? await Task.sleep(for: .milliseconds(Int(stepMs)))
                if Task.isCancelled { return }
                segElapsed = Date().timeIntervalSince(segStart) * 1000
                let segFrac = min(1.0, segElapsed / segMs)
                dispenseProgress = min(1.0, (dispensedMl + segFrac * seg.ml) / totalMl)

                if let bIdx = bottles.firstIndex(where: { $0.id == seg.pumpId }) {
                    let drain = seg.ml * (stepMs / segMs)
                    bottles[bIdx].remaining = max(0, bottles[bIdx].remaining - drain)
                }

                if let errAt = errorAt, dispenseProgress * 100 >= errAt {
                    if injectDisconnect {
                        if !firedDisconnect {
                            firedDisconnect = true
                            isConnected = false
                            bleLostDuringDispense = true
                        }
                    } else if let e = injectError {
                        lastError = e
                        // Mirror the firmware: an injected fault drives the
                        // FSM into ERROR so MachineErrorScreen takes over.
                        machineState = .error
                        previousMachineState = .error
                        onError()
                        return
                    }
                }
            }

            dispensedMl += seg.ml
            dispenseProgress = min(1.0, dispensedMl / totalMl)

            // Inter-pump gap: HX711 sample-wait drains out before the next
            // pump's PORTC bit goes high. Lights off, bar holds.
            if idx < segments.count - 1 {
                activePumpId = nil
                let gapSteps = max(1, Int(interPumpGapMs / stepMs))
                for _ in 0..<gapSteps {
                    try? await Task.sleep(for: .milliseconds(Int(stepMs)))
                    if Task.isCancelled { return }
                }
            }
        }

        dispenseProgress = 1.0
        activePumpId = nil
        onComplete()
    }

    // MARK: - Atmega simulation helpers (used by tweaks panel)
    func setSimulatedCupSize(_ size: CupSize) { cupSize = size }
    func refill(pumpId: String) {
        if let idx = bottles.firstIndex(where: { $0.id == pumpId }) {
            bottles[idx].remaining = bottles[idx].capacity
        }
        NotificationManager.shared.refresh(bottles: bottles)
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
            // The HM-10/BT-05 family uses one characteristic for both TX and
            // RX. Enable notifications so the Atmega's status packets land in
            // didUpdateValueFor.
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: c)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didWriteValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error {
            lastTxError = "Write failed: \(error.localizedDescription)"
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil, let data = characteristic.value, !data.isEmpty else { return }
        let packets = packetParser.feed(data)
        guard let pkt = packets.last else { return }
        apply(packet: pkt)
    }
}

// MARK: - Inbound packet application

private extension BluetoothManager {
    func apply(packet: MachinePacket) {
        // Cup class — '0'=empty, '1'..'3'=small/medium/large. Drives the
        // CupSizeBadge, the per-drink mL math, and the Dispense gating.
        cupSize = CupSize(firmwareByte: packet.cupClass)

        // Bottles: Catalog.pumps is ordered P1…P6, which matches the firmware's
        // usedMl[0…5] / OJ-PJ-CJ-LJ-GR-GS order. Capacity is fixed at the
        // EEPROM total (750 mL); remaining = capacity - usedMl.
        for (idx, pump) in Catalog.pumps.enumerated() {
            guard let bIdx = bottles.firstIndex(where: { $0.id == pump.id }) else { continue }
            let used = Double(packet.usedMl[idx])
            let cap = bottles[bIdx].capacity
            bottles[bIdx].remaining = max(0, cap - used)
        }

        // Edge-trigger on the transition OUT of error (firmware reset
        // button → back to IDLE). Clear lastError and any stale dispense
        // routing so the next pour starts clean.
        if packet.state != .error && previousMachineState == .error {
            lastError = nil
            bleLostDuringDispense = false
        }

        // Edge-trigger on the transition INTO error so the overlay only fires
        // once per fault, not every second while the firmware re-broadcasts.
        if packet.state == .error && previousMachineState != .error {
            lastError = machineError(for: packet.errorCode)
            // A live pour is now invalid — kill the local simulation clock so
            // the progress bar stops advancing behind the overlay.
            dispenseTask?.cancel()
            dispenseTask = nil
            dispenseProgress = 0
            activePumpId = nil
        }

        // Refill detection: diff usedMl against the previous packet. Any
        // pump that just went from non-zero to zero is a refill — handleRefill
        // in firmware/src/states.c is the only code path that ever zeroes
        // usedMl (single-pump branch or globalPump == 6 / all). We don't gate
        // on the REFILL→IDLE state transition because the firmware emits the
        // REFILL packet and the IDLE packet back-to-back (~120 ms apart over
        // a single transition()→handleRefill()→transition() cycle), and the
        // HM-10 bridge sometimes coalesces or drops one of them. The diff
        // itself is the unambiguous signal.
        if hasSeenPacket {
            let cleared = (0..<6).filter { previousUsedMl[$0] > 0 && packet.usedMl[$0] == 0 }
            let banner: RefillBannerData? = {
                if cleared.count >= 2 {
                    return RefillBannerData(pumpShort: nil)
                } else if let idx = cleared.first,
                          Catalog.pumps.indices.contains(idx) {
                    return RefillBannerData(pumpShort: Catalog.pumps[idx].short)
                } else {
                    return nil
                }
            }()
            if let b = banner {
                surfaceRefillBanner(b)
            }
        }

        previousUsedMl = packet.usedMl
        previousMachineState = packet.state
        machineState = packet.state
        hasSeenPacket = true

        NotificationManager.shared.refresh(bottles: bottles)
    }

    private func surfaceRefillBanner(_ data: RefillBannerData) {
        refillBannerTask?.cancel()
        refillBanner = data
        refillBannerTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            if self?.refillBanner?.id == data.id {
                self?.refillBanner = nil
            }
        }
    }

    /// Maps firmware error codes (firmware/src/states.c) to the app's UI-level
    /// error enum.
    ///   0x01 / 0x02 / 0x03 — "no cup on the scale", raised from mid-pour /
    ///                        pre-pour / post-pour. Collapse to .cupRemoved.
    ///   0x04..0x09        — low liquid; (code - 0x04) is the pump index
    ///                        (P1..P6) that would have run dry.
    private func machineError(for code: UInt8) -> MachineError {
        switch code {
        case 0x01, 0x02, 0x03:
            return .cupRemoved
        case 0x04...0x09:
            let pumpIdx = Int(code - 0x04)
            let short = Catalog.pumps.indices.contains(pumpIdx)
                ? Catalog.pumps[pumpIdx].short
                : "?"
            return .lowLiquid(pumpShort: short)
        default:
            return .cupRemoved
        }
    }
}
