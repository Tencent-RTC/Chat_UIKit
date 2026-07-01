import Foundation
import TUICore

/// A selectable translation language (code + localized display name).
public struct TUIVoiceRecordLanguage {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

/// Persists the target language used by the record-transcription translation
/// feature. This is intentionally independent from the global message-translate
/// config (`TUITranslationConfig`) so toggling one never affects the other.
public final class TUIVoiceRecordTranslateConfig {
    // MARK: - Singleton

    public static let shared = TUIVoiceRecordTranslateConfig()

    private init() {}

    // MARK: - Storage

    private static let storeKeyPrefix = "voiceRecordTranslateTargetLanguage"

    private var storeKey: String {
        let loginUserID = TUILogin.getUserID() ?? "default"
        return "\(TUIVoiceRecordTranslateConfig.storeKeyPrefix)_\(loginUserID)"
    }

    /// Persisted target language code. Empty/nil means "not chosen yet".
    public var targetLanguageCode: String? {
        get {
            let value = UserDefaults.standard.string(forKey: storeKey)
            return (value?.isEmpty == false) ? value : nil
        }
        set {
            UserDefaults.standard.set(newValue, forKey: storeKey)
            UserDefaults.standard.synchronize()
        }
    }

    /// Whether a target language has already been chosen.
    public var hasTargetLanguage: Bool {
        return targetLanguageCode != nil
    }

    // MARK: - Language List

    /// Selectable languages, mirroring the message-translate plugin list.
    public let languages: [TUIVoiceRecordLanguage] = [
        TUIVoiceRecordLanguage(code: "zh", name: "简体中文"),
        TUIVoiceRecordLanguage(code: "zh-TW", name: "繁體中文"),
        TUIVoiceRecordLanguage(code: "en", name: "English"),
        TUIVoiceRecordLanguage(code: "ja", name: "日本語"),
        TUIVoiceRecordLanguage(code: "ko", name: "한국어"),
        TUIVoiceRecordLanguage(code: "fr", name: "Français"),
        TUIVoiceRecordLanguage(code: "es", name: "Español"),
        TUIVoiceRecordLanguage(code: "it", name: "Italiano"),
        TUIVoiceRecordLanguage(code: "de", name: "Deutsch"),
        TUIVoiceRecordLanguage(code: "tr", name: "Türkçe"),
        TUIVoiceRecordLanguage(code: "ru", name: "Русский"),
        TUIVoiceRecordLanguage(code: "pt", name: "Português"),
        TUIVoiceRecordLanguage(code: "vi", name: "Tiếng Việt"),
        TUIVoiceRecordLanguage(code: "id", name: "Bahasa Indonesia"),
        TUIVoiceRecordLanguage(code: "th", name: "ภาษาไทย"),
        TUIVoiceRecordLanguage(code: "ms", name: "Bahasa Melayu"),
        TUIVoiceRecordLanguage(code: "hi", name: "हिन्दी")
    ]

    /// Localized display name for a language code (falls back to the code).
    public func displayName(for code: String) -> String {
        return languages.first(where: { $0.code == code })?.name ?? code
    }
}
