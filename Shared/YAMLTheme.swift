import Foundation

public enum YAMLTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case github = "github"
    case xcode = "xcode"
    case monokai = "monokai"
    case dracula = "dracula"
    case solarized = "solarized"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .system: return "System (Adaptive)"
        case .github: return "GitHub"
        case .xcode: return "Xcode"
        case .monokai: return "Monokai"
        case .dracula: return "Dracula"
        case .solarized: return "Solarized"
        }
    }
    
    public var isDarkOnly: Bool {
        switch self {
        case .monokai, .dracula: return true
        default: return false
        }
    }
}
