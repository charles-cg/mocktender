import SwiftUI
import Observation

@MainActor
@Observable
final class AppState {
    var screen: Screen = .connect
    var selectedDrink: Drink = Catalog.drinks[0]
    var palette: AeroPalette = .sky

    // Dev / Atmega harness — kept on AppState so the Tweaks panel can mutate.
    var pourSpeed: Double = 1.0
    var injectFault: InjectFault = .none

    enum InjectFault: String, CaseIterable, Identifiable {
        case none, cup, liquid, disconnect
        var id: String { rawValue }
    }
}

enum AeroPalette: String, CaseIterable, Identifiable {
    case sky, sunset, aqua, night
    var id: String { rawValue }

    var top: Color { Color(hex: top_) }
    var mid: Color { Color(hex: mid_) }
    var bot: Color { Color(hex: bot_) }
    var blob: Color {
        switch self {
        case .sky:    return Color(red: 170/255, green: 215/255, blue: 255/255, opacity: 0.45)
        case .sunset: return Color(red: 255/255, green: 180/255, blue: 200/255, opacity: 0.45)
        case .aqua:   return Color(red: 160/255, green: 225/255, blue: 210/255, opacity: 0.45)
        case .night:  return Color(red:  80/255, green: 130/255, blue: 220/255, opacity: 0.35)
        }
    }
    var isDark: Bool { self == .night }

    private var top_: UInt32 {
        switch self { case .sky, .sunset, .aqua: return 0xFFFFFF; case .night: return 0x0D1A36 }
    }
    private var mid_: UInt32 {
        switch self {
        case .sky:    return 0xF4FBFF
        case .sunset: return 0xFFF3EE
        case .aqua:   return 0xF0FBF8
        case .night:  return 0x0A1228
        }
    }
    private var bot_: UInt32 {
        switch self {
        case .sky:    return 0xEAF5FF
        case .sunset: return 0xFFE5EE
        case .aqua:   return 0xE3F6F1
        case .night:  return 0x08101F
        }
    }
}
