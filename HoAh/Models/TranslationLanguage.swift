import Foundation
import SwiftUI

enum TranslationLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case portuguese = "pt"
    case arabic = "ar"
    case russian = "ru"

    var id: String { rawValue }

    /// Display name shown in UI. Localized strings are defined in `Localizable.strings`.
    var localizedName: LocalizedStringKey {
        switch self {
        case .english:
            return LocalizedStringKey("translation_language_english")
        case .simplifiedChinese:
            return LocalizedStringKey("translation_language_simplified_chinese")
        case .spanish:
            return LocalizedStringKey("translation_language_spanish")
        case .japanese:
            return LocalizedStringKey("translation_language_japanese")
        case .korean:
            return LocalizedStringKey("translation_language_korean")
        case .french:
            return LocalizedStringKey("translation_language_french")
        case .german:
            return LocalizedStringKey("translation_language_german")
        case .portuguese:
            return LocalizedStringKey("translation_language_portuguese")
        case .arabic:
            return LocalizedStringKey("translation_language_arabic")
        case .russian:
            return LocalizedStringKey("translation_language_russian")
        }
    }

    /// Friendly name that is provided to the AI prompt.
    var gptName: String {
        switch self {
        case .english:
            return "English"
        case .simplifiedChinese:
            return "Simplified Chinese"
        case .spanish:
            return "Spanish"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .french:
            return "French"
        case .german:
            return "German"
        case .portuguese:
            return "Portuguese"
        case .arabic:
            return "Arabic"
        case .russian:
            return "Russian"
        }
    }

    static var `default`: TranslationLanguage {
        .english
    }

    static func from(_ rawValue: String?) -> TranslationLanguage {
        guard let rawValue, let language = TranslationLanguage(rawValue: rawValue) else {
            return .default
        }
        return language
    }

    static func matchingLanguage(for rawValue: String?) -> TranslationLanguage? {
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return TranslationLanguage(rawValue: rawValue)
    }

    static func isKnownLanguage(_ rawValue: String?) -> Bool {
        matchingLanguage(for: rawValue) != nil
    }
}
