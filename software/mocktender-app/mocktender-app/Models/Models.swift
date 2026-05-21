import SwiftUI

struct Pump: Identifiable, Hashable {
    let id: String          // "P1"…"P6"
    let code: String
    let name: String
    let short: String       // "OJ"
    let color: Color
    let light: Color
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
        case .small:  return 100
        case .medium: return 250
        case .large:  return 400
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
    /// to classify a weight reading the same way the firmware does.
    var minWeightGrams: Int {
        switch self {
        case .empty:  return 0       // < CUP_PRESENT (20)
        case .small:  return 20      // CUP_PRESENT
        case .medium: return 100     // SMALL_CUP
        case .large:  return 300     // MED_CUP
        }
    }
}

struct Bottle: Identifiable, Hashable {
    let id: String           // matches Pump.id
    var remaining: Double    // ml, capacity = 1000
}

enum MachineError: Equatable {
    case cupRemoved
    case lowLiquid(pumpShort: String)
    case disconnected
}

enum Screen: Hashable {
    case connect, home, detail, dispense, deliver, bottles
}

// MARK: - Static catalog

enum Catalog {
    static let pumps: [Pump] = [
        .init(id: "P1", code: "P1", name: "Orange Juice",    short: "OJ",
              color: Color(hex: 0xFF8C2A), light: Color(hex: 0xFFC68A)),
        .init(id: "P2", code: "P2", name: "Pineapple Juice", short: "PJ",
              color: Color(hex: 0xE8C612), light: Color(hex: 0xF6E47A)),
        .init(id: "P3", code: "P3", name: "Cranberry Juice", short: "CJ",
              color: Color(hex: 0xD6233F), light: Color(hex: 0xF08698)),
        .init(id: "P4", code: "P4", name: "Lime Juice",      short: "LJ",
              color: Color(hex: 0x4CB951), light: Color(hex: 0xA7E0AA)),
        .init(id: "P5", code: "P5", name: "Grenadine",       short: "GR",
              color: Color(hex: 0xD14B9C), light: Color(hex: 0xED9CCB)),
        .init(id: "P6", code: "P6", name: "Ginger Syrup",    short: "GS",
              color: Color(hex: 0x9B6A3F), light: Color(hex: 0xC9A07A)),
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
        .init(id: 2, char: "3", name: "Mocktail Mule",   tagline: "Cranberry · ginger",
              ratios: ["P3": 50, "P4": 15, "P6": 35],
              grad: [Color(hex: 0xF08698), Color(hex: 0xD6233F), Color(hex: 0x9B6A3F)]),
        .init(id: 3, char: "4", name: "Tropical Sunset", tagline: "Orange · pineapple",
              ratios: ["P1": 40, "P2": 40, "P5": 20],
              grad: [Color(hex: 0xFFE16A), Color(hex: 0xFF8C2A), Color(hex: 0xD14B9C)]),
        .init(id: 4, char: "5", name: "Ginger Tropic",   tagline: "Pineapple · ginger",
              ratios: ["P2": 55, "P4": 15, "P6": 30],
              grad: [Color(hex: 0xFFE780), Color(hex: 0xE8C612), Color(hex: 0x9B6A3F)]),
        .init(id: 5, char: "6", name: "Paradise Punch",  tagline: "Four-juice classic",
              ratios: ["P1": 30, "P2": 30, "P3": 25, "P4": 15],
              grad: [Color(hex: 0xFFC15C), Color(hex: 0xF08C5C), Color(hex: 0xD6233F)]),
        .init(id: 6, char: "7", name: "Citrus Berry",    tagline: "Orange · cranberry",
              ratios: ["P1": 40, "P3": 40, "P4": 20],
              grad: [Color(hex: 0xFFA858), Color(hex: 0xE04A6A), Color(hex: 0xA8205E)]),
        .init(id: 7, char: "8", name: "Ginger Berry",    tagline: "Cranberry · ginger",
              ratios: ["P3": 55, "P5": 15, "P6": 30],
              grad: [Color(hex: 0xF08698), Color(hex: 0xC53050), Color(hex: 0x7A4A2A)]),
        .init(id: 8, char: "9", name: "Pink Lemonade",   tagline: "Bright, tart, pink",
              ratios: ["P1": 30, "P3": 30, "P4": 20, "P5": 20],
              grad: [Color(hex: 0xFFD0DE), Color(hex: 0xFF8AAE), Color(hex: 0xE04A8C)]),
        .init(id: 9, char: "A", name: "Full House",      tagline: "All six, in balance",
              ratios: ["P1": 20, "P2": 20, "P3": 20, "P4": 10, "P5": 20, "P6": 10],
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
