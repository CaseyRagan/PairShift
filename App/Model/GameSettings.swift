import Foundation

enum AppAppearance: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

struct GameSettings: Codable, Equatable, Sendable {
    var soundEnabled = true
    var hapticsEnabled = true
    var reduceMotion = false
    var appearance: AppAppearance = .dark
}
