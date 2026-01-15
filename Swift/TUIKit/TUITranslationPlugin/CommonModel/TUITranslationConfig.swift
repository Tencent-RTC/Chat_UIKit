import Foundation
import TIMCommon

class TUITranslationConfig: NSObject {
    static let shared: TUITranslationConfig = {
        let instance = TUITranslationConfig()
        return instance
    }()
    
    /**
     * Translation target language code.
     */
    var targetLanguageCode: String? {
        didSet {
            guard let targetLanguageCode = targetLanguageCode, !targetLanguageCode.isEmpty else { return }
            if oldValue == targetLanguageCode { return }
            targetLanguageName = languageDict[targetLanguageCode]
            UserDefaults.standard.set(targetLanguageCode, forKey: kTransaltionTargetLanguageCode)
            UserDefaults.standard.synchronize()
        }
    }
    
    /**
     * Translation target language name.
     */
    private(set) var targetLanguageName: String?
    
    /**
     * Auto translate received messages.
     */
    var autoTranslateEnabled: Bool = false {
        didSet {
            if oldValue == autoTranslateEnabled { return }
            UserDefaults.standard.set(autoTranslateEnabled, forKey: kAutoTranslateEnabled)
            UserDefaults.standard.synchronize()
        }
    }
    
    /**
     * Show bilingual mode (original text + translation).
     * When true: show both original and translated text
     * When false: hide original text and show only translation
     */
    var showBilingualEnabled: Bool = true {
        didSet {
            if oldValue == showBilingualEnabled { return }
            UserDefaults.standard.set(showBilingualEnabled, forKey: kShowBilingualEnabled)
            UserDefaults.standard.synchronize()
        }
    }
    
    override private init() {
        super.init()
        loadSavedLanguage()
        loadAutoTranslateSetting()
        loadShowBilingualSetting()
    }
    
    private func loadAutoTranslateSetting() {
        autoTranslateEnabled = UserDefaults.standard.bool(forKey: kAutoTranslateEnabled)
    }
    
    private func loadShowBilingualSetting() {
        if UserDefaults.standard.object(forKey: kShowBilingualEnabled) != nil {
            showBilingualEnabled = UserDefaults.standard.bool(forKey: kShowBilingualEnabled)
        } else {
            showBilingualEnabled = true
        }
    }
    
    private func loadSavedLanguage() {
        if let lang = UserDefaults.standard.string(forKey: kTransaltionTargetLanguageCode), !lang.isEmpty {
            targetLanguageCode = lang
        } else {
            targetLanguageCode = defalutTargetLanguageCode()
            targetLanguageName = languageDict[targetLanguageCode ?? ""]
        }
    }
    
    private func defalutTargetLanguageCode() -> String {
        let currentAppLanguage = TUIGlobalization.getPreferredLanguage() ?? ""
        if currentAppLanguage == "zh-Hans" || currentAppLanguage == "zh-Hant" {
            return "zh"
        } else {
            return "en"
        }
    }
    
    private var languageDict: [String: String] {
        return [
            "zh": "简体中文",
            "zh-TW": "繁體中文",
            "en": "English",
            "ja": "日本語",
            "ko": "한국어",
            "fr": "Français",
            "es": "Español",
            "it": "Italiano",
            "de": "Deutsch",
            "tr": "Türkçe",
            "ru": "Русский",
            "pt": "Português",
            "vi": "Tiếng Việt",
            "id": "Bahasa Indonesia",
            "th": "ภาษาไทย",
            "ms": "Bahasa Melayu",
            "hi": "हिन्दी"
        ]
    }
    
    private let kTransaltionTargetLanguageCode = "translation_target_language_code"
    private let kAutoTranslateEnabled = "translation_auto_translate_enabled"
    private let kShowBilingualEnabled = "translation_show_bilingual_enabled"
}
