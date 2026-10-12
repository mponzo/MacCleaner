import Foundation
import SwiftUI

/// App language: system default, or forced English / Italian.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case english
    case italian

    var id: String { rawValue }

    /// ISO code for `.lproj`, or `nil` to follow the Mac language.
    var localizationCode: String? {
        switch self {
        case .system: return nil
        case .english: return "en"
        case .italian: return "it"
        }
    }

    var menuTitleKey: String {
        switch self {
        case .system: return "settings.language.system"
        case .english: return "settings.language.english"
        case .italian: return "settings.language.italian"
        }
    }
}

/// Localized strings from the package resource bundle, honoring the in-app language preference.
enum L10n {
    /// Set from `AppPreferences`; `nil` = system language.
    static var overrideCode: String?

    static var bundle: Bundle {
        guard let code = overrideCode,
              let path = Bundle.module.path(forResource: code, ofType: "lproj"),
              let localized = Bundle(path: path)
        else {
            return .module
        }
        return localized
    }

    static var locale: Locale {
        if let code = overrideCode {
            return Locale(identifier: code)
        }
        return .current
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: key, bundle: bundle)
    }

    /// Dynamic keys such as `category.userCaches.title`.
    static func string(key: String) -> String {
        String(localized: String.LocalizationValue(stringLiteral: key), bundle: bundle)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key: key)
        return String(format: format, locale: locale, arguments: arguments)
    }

    static func apply(_ language: AppLanguage) {
        overrideCode = language.localizationCode
    }
}

extension Text {
    /// Localized text from the package resource bundle (respects language override).
    init(l10n key: String) {
        self.init(L10n.string(key: key))
    }
}

extension Label where Title == Text, Icon == Image {
    init(l10n key: String, systemImage: String) {
        self.init(L10n.string(key: key), systemImage: systemImage)
    }
}
