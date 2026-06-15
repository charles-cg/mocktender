import SwiftUI

struct Pump: Identifiable, Hashable {
    let id: String          // "P1"…"P6"
    let code: String
    let name: String
    let short: String       // "OJ"
    let color: Color
    let light: Color
    /// Measured pump throughput in mL/s. Mirrors the per-pump
    /// `FLOWRATE_PUMPn_X100` constants in firmware/include/config.h (which
    /// store mL/s × 100). The dispense simulation derives its per-pump pour
    /// duration from this so the on-screen progress matches the machine.
    let flowRateMlPerSec: Double
    /// Per-bottle capacity in mL. Mirrors the firmware's per-pump
    /// `bottleCapacityMl[]` seed values in firmware/src/eeprom.c.
    let capacityMl: Double
}

struct Drink: Identifiable, Hashable {
    let id: Int
    let char: Character     // UART selector '0'…'9'
    let name: String
    let tagline: String
    let ratios: [String: Int]   // pump.id -> percent (sums to 100)
    let grad: [Color]            // 3-stop gradient for the orb
}

enum CupSize: String, CaseIterable, Identifiable {
    case empty, small, medium, large
    var id: String { rawValue }
    /// Maps the firmware's ASCII cup byte (`classifyCup` in
    /// firmware/src/states.c — '0'=empty, '1'=small, '2'=medium, '3'=large)
    /// to the matching `CupSize`. Anything else is treated as no cup.
    init(firmwareByte: UInt8) {
        switch firmwareByte {
        case 0x31: self = .small
        case 0x32: self = .medium
        case 0x33: self = .large
        default:   self = .empty
        }
    }
    var label: String {
        switch self {
        case .empty:  return "No cup"
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        }
    }
    /// Mirrors `getCupSize()` in firmware/src/states.c — these are the exact
    /// volumes the machine pours for each cup class.
    var ml: Int {
        switch self {
        case .empty:  return 0
        case .small:  return 120
        case .medium: return 190
        case .large:  return 240
        }
    }
    /// Internal cup-class marker used by the firmware (`classifyCup()` in
    /// firmware/src/states.c). The AVR sets this from the load cell — it is
    /// not received over BLE. Kept here for parity / future protocol use.
    var char: Character? {
        switch self {
        case .small:  return "1"
        case .medium: return "2"
        case .large:  return "3"
        case .empty:  return nil
        }
    }
    /// Lower bound in grams from `config.h`. Used by the (future) RX path
    /// to classify a weight reading the same way the firmware does. The
    /// firmware's `classifyCup()` now matches a symmetric ±CUP_TOLERANCE (30 g)
    /// band around each measured empty-cup weight, so the lower bound is
    /// `measured − tolerance` (SMALL 240.5, MED 312.5, BIG 393.8).
    var minWeightGrams: Int {
        switch self {
        case .empty:  return 0       // < CUP_PRESENT (20)
        case .small:  return 210     // SMALL_CUP − CUP_TOLERANCE (240.5 − 30)
        case .medium: return 282     // MED_CUP − CUP_TOLERANCE (312.5 − 30)
        case .large:  return 363     // BIG_CUP − CUP_TOLERANCE (393.8 − 30)
        }
    }
}

struct Bottle: Identifiable, Hashable {
    let id: String           // matches Pump.id
    var remaining: Double    // ml
    /// Per-bottle capacity in mL. Set per pump from `Pump.capacityMl`, which
    /// mirrors the firmware's per-pump `bottleCapacityMl[]` seed values in
    /// firmware/src/eeprom.c (P1 946, P2 960, P3–P5 1000, P6 750).
    var capacity: Double = 750
}

enum MachineError: Equatable {
    case cupRemoved
    case lowLiquid(pumpShort: String)
    case disconnected
}

/// Transient banner shown after the firmware completes a REFILL transition.
/// `pumpShort == nil` represents an "all bottles refilled" event (the
/// firmware's `globalPump == 6` branch in `handleRefill`).
struct RefillBannerData: Identifiable, Equatable {
    let id = UUID()
    let pumpShort: String?
}

/// In-app banner shown when a bottle's `remaining` first crosses the 15%
/// refill threshold while the app is foregrounded — replaces the system
/// notification in that case so it doesn't pop over the running UI.
struct LowBottleBannerData: Identifiable, Equatable {
    let id = UUID()
    let pumpName: String
    let pumpShort: String
}

enum Screen: Hashable {
    case connect, home, detail, dispense, deliver, bottles
}

// MARK: - Static catalog

enum Catalog {
    static let pumps: [Pump] = [
        .init(id: "P1", code: "P1", name: "Orange Juice",    short: "OJ",
              color: Color(hex: 0xFF8C2A), light: Color(hex: 0xFFC68A),
              flowRateMlPerSec: 33.33,    // FLOWRATE_PUMP1_X100 = 3333
              capacityMl: 946),
        .init(id: "P2", code: "P2", name: "Pineapple Juice", short: "PJ",
              color: Color(hex: 0xE8C612), light: Color(hex: 0xF6E47A),
              flowRateMlPerSec: 27.25,    // FLOWRATE_PUMP2_X100 = 2725
              capacityMl: 960),
        .init(id: "P3", code: "P3", name: "Cranberry Juice", short: "CJ",
              color: Color(hex: 0xD6233F), light: Color(hex: 0xF08698),
              flowRateMlPerSec: 31.13,    // FLOWRATE_PUMP3_X100 = 3113
              capacityMl: 1000),
        .init(id: "P4", code: "P4", name: "Lime Juice",      short: "LJ",
              color: Color(hex: 0x4CB951), light: Color(hex: 0xA7E0AA),
              flowRateMlPerSec: 24.47,    // FLOWRATE_PUMP4_X100 = 2447
              capacityMl: 1000),
        .init(id: "P5", code: "P5", name: "Grenadine",       short: "GR",
              color: Color(hex: 0xD14B9C), light: Color(hex: 0xED9CCB),
              flowRateMlPerSec: 22.70,    // FLOWRATE_PUMP5_X100 = 2270
              capacityMl: 1000),
        .init(id: "P6", code: "P6", name: "Tamarind Water",  short: "TW",
              color: Color(hex: 0xC1762B), light: Color(hex: 0xE0A86A),
              flowRateMlPerSec: 28.67,    // FLOWRATE_PUMP6_X100 = 2867
              capacityMl: 750),
    ]

    static func pump(_ id: String) -> Pump? { pumps.first { $0.id == id } }

    // Recipe characters match the firmware's USART RX ISR:
    //   '1'..'9' select recipes 0..8, 'A' selects recipe 9.
    // (firmware/src/interrupts.c — `if ((rx >= '1' && rx <= '9') || rx == 'A')`)
    // Order also matches the recipe[] table in firmware/src/flash.c so the
    // ratios shown in the app match what the machine actually pours.
    static let drinks: [Drink] = [
        .init(id: 0, char: "1", name: "Sunrise",         tagline: "Citrus · grenadine",
              ratios: ["P1": 55, "P4": 10, "P5": 35],
              grad: [Color(hex: 0xFFC15C), Color(hex: 0xFF7140), Color(hex: 0xD14B9C)]),
        .init(id: 1, char: "2", name: "Tropical Breeze", tagline: "Pineapple · cranberry",
              ratios: ["P2": 50, "P3": 35, "P4": 15],
              grad: [Color(hex: 0xFFE16A), Color(hex: 0xFF8E58), Color(hex: 0xD6233F)]),
        .init(id: 2, char: "3", name: "Mocktail Mule",   tagline: "Cranberry · tamarind",
              ratios: ["P3": 42, "P4": 13, "P6": 45],
              grad: [Color(hex: 0xF08698), Color(hex: 0xD6233F), Color(hex: 0xC1762B)]),
        .init(id: 3, char: "4", name: "Tropical Sunset", tagline: "Orange · pineapple",
              ratios: ["P1": 40, "P2": 40, "P5": 20],
              grad: [Color(hex: 0xFFE16A), Color(hex: 0xFF8C2A), Color(hex: 0xD14B9C)]),
        .init(id: 4, char: "5", name: "Tamarind Tropic", tagline: "Pineapple · tamarind",
              ratios: ["P2": 45, "P4": 15, "P6": 40],
              grad: [Color(hex: 0xFFE780), Color(hex: 0xE8C612), Color(hex: 0xC1762B)]),
        .init(id: 5, char: "6", name: "Paradise Punch",  tagline: "Four-juice classic",
              ratios: ["P1": 30, "P2": 30, "P3": 25, "P4": 15],
              grad: [Color(hex: 0xFFC15C), Color(hex: 0xF08C5C), Color(hex: 0xD6233F)]),
        .init(id: 6, char: "7", name: "Citrus Berry",    tagline: "Orange · cranberry",
              ratios: ["P1": 40, "P3": 40, "P4": 20],
              grad: [Color(hex: 0xFFA858), Color(hex: 0xE04A6A), Color(hex: 0xA8205E)]),
        .init(id: 7, char: "8", name: "Tamarind Berry",  tagline: "Cranberry · tamarind",
              ratios: ["P3": 48, "P5": 12, "P6": 40],
              grad: [Color(hex: 0xF08698), Color(hex: 0xC53050), Color(hex: 0x8A4E1E)]),
        .init(id: 8, char: "9", name: "Pink Lemonade",   tagline: "Bright, tart, pink",
              ratios: ["P1": 30, "P3": 30, "P4": 20, "P5": 20],
              grad: [Color(hex: 0xFFD0DE), Color(hex: 0xFF8AAE), Color(hex: 0xE04A8C)]),
        .init(id: 9, char: "A", name: "Full House",      tagline: "All six, in balance",
              ratios: ["P1": 20, "P2": 20, "P3": 20, "P4": 10, "P5": 15, "P6": 15],
              grad: [Color(hex: 0xFFD86A), Color(hex: 0xFF7A50), Color(hex: 0xC53C7C)]),
    ]
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
