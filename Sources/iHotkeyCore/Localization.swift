import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case system, zh, en

    public var title: String {
        switch self {
        case .system: return L("跟随系统", "System")
        case .zh: return "简体中文"
        case .en: return "English"
        }
    }
}

/// Tiny two-language localization. Kept in code (not .strings resources) so the
/// app bundle stays a single binary without SwiftPM resource-bundle quirks.
public enum Localizer {
    nonisolated(unsafe) public static var language: AppLanguage = .system

    public static var isChinese: Bool {
        switch language {
        case .zh: return true
        case .en: return false
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("zh")
        }
    }
}

@inline(__always)
public func L(_ zh: String, _ en: String) -> String {
    Localizer.isChinese ? zh : en
}
