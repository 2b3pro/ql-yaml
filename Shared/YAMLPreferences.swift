import Foundation

public final class YAMLPreferences: ObservableObject {
    public static let shared = YAMLPreferences()
    
    public static let appGroupIdentifier = "group.com.2b3pro.qlyaml"
    
    private let defaults: UserDefaults
    
    public enum Key {
        public static let theme = "yaml_theme"
        public static let fontSize = "yaml_font_size"
        public static let showLineNumbers = "yaml_show_line_numbers"
        public static let enableFolding = "yaml_enable_folding"
        public static let showIndentGuides = "yaml_show_indent_guides"
        public static let showHeader = "yaml_show_header"
        public static let tabWidth = "yaml_tab_width"
        public static let softWrapRaw = "yaml_soft_wrap_raw"
        public static let softWrapCode = "yaml_soft_wrap_code"
    }
    
    public init() {
        if let groupDefaults = UserDefaults(suiteName: YAMLPreferences.appGroupIdentifier) {
            self.defaults = groupDefaults
        } else {
            self.defaults = .standard
        }
    }
    
    public var theme: YAMLTheme {
        get {
            let str = defaults.string(forKey: Key.theme) ?? YAMLTheme.system.rawValue
            return YAMLTheme(rawValue: str) ?? .system
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.theme)
            objectWillChange.send()
        }
    }
    
    public var fontSize: Int {
        get {
            let val = defaults.integer(forKey: Key.fontSize)
            return val > 0 ? val : 13
        }
        set {
            defaults.set(newValue, forKey: Key.fontSize)
            objectWillChange.send()
        }
    }
    
    public var showLineNumbers: Bool {
        get {
            if defaults.object(forKey: Key.showLineNumbers) == nil { return true }
            return defaults.bool(forKey: Key.showLineNumbers)
        }
        set {
            defaults.set(newValue, forKey: Key.showLineNumbers)
            objectWillChange.send()
        }
    }
    
    public var enableFolding: Bool {
        get {
            if defaults.object(forKey: Key.enableFolding) == nil { return true }
            return defaults.bool(forKey: Key.enableFolding)
        }
        set {
            defaults.set(newValue, forKey: Key.enableFolding)
            objectWillChange.send()
        }
    }
    
    public var showIndentGuides: Bool {
        get {
            if defaults.object(forKey: Key.showIndentGuides) == nil { return true }
            return defaults.bool(forKey: Key.showIndentGuides)
        }
        set {
            defaults.set(newValue, forKey: Key.showIndentGuides)
            objectWillChange.send()
        }
    }
    
    public var showHeader: Bool {
        get {
            if defaults.object(forKey: Key.showHeader) == nil { return true }
            return defaults.bool(forKey: Key.showHeader)
        }
        set {
            defaults.set(newValue, forKey: Key.showHeader)
            objectWillChange.send()
        }
    }
    
    public var tabWidth: Int {
        get {
            let val = defaults.integer(forKey: Key.tabWidth)
            return val > 0 ? val : 2
        }
        set {
            defaults.set(newValue, forKey: Key.tabWidth)
            objectWillChange.send()
        }
    }
    
    public var softWrapRaw: Bool {
        get {
            if defaults.object(forKey: Key.softWrapRaw) == nil { return true }
            return defaults.bool(forKey: Key.softWrapRaw)
        }
        set {
            defaults.set(newValue, forKey: Key.softWrapRaw)
            objectWillChange.send()
        }
    }
    
    public var softWrapCode: Bool {
        get {
            if defaults.object(forKey: Key.softWrapCode) == nil { return false }
            return defaults.bool(forKey: Key.softWrapCode)
        }
        set {
            defaults.set(newValue, forKey: Key.softWrapCode)
            objectWillChange.send()
        }
    }
}
