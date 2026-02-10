import Foundation
import TIMCommon
import TUICore
import TUIChat

enum TUITranslationViewStatus: Int {
    case unknown = 0
    case hidden = 1
    case loading = 2
    case shown = 3
    case securityStrike = 4
}

typealias TUITranslateMessageCompletion = (Int, String, TUIMessageCellData, Int, String) -> Void

class TUITranslationDataProvider: NSObject, TUINotificationProtocol, V2TIMAdvancedMsgListener {
    private static let kKeyTranslationText = "translation"
    private static let kKeyTranslationViewStatus = "translation_view_status"
    private static let kKeyShouldHideOriginalText = "translation_hide_original"
    private static let kKeyUserRequestedShowOriginal = "translation_user_show_original"
    
    static let shared = TUITranslationDataProvider()
    
    override private init() {
        super.init()
        registerMessageListener()
    }
    
    private func registerMessageListener() {
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: self)
    }
    
    deinit {
        V2TIMManager.sharedInstance().removeAdvancedMsgListener(listener: self)
    }
    
    // MARK: - V2TIMAdvancedMsgListener
    
    func onRecvNewMessage(msg: V2TIMMessage) {
        guard TUITranslationConfig.shared.autoTranslateEnabled,
              msg.elemType == .ELEM_TYPE_TEXT,
              !msg.isSelf else {
            return
        }
        
        // Auto translate received message after a short delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.autoTranslateReceivedMessage(msg)
        }
    }
    
    private func autoTranslateReceivedMessage(_ message: V2TIMMessage) {
        // Create a temporary cellData for translation
        let cellData = TUIMessageCellData(direction: TMsgDirection.incoming)

        cellData.innerMessage = message
        
        TUITranslationDataProvider.translateMessage(cellData) { _, _, _, _, _ in
            // Notify UI to refresh the translation view
            let param: [String: Any] = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData]
            TUICore.notifyEvent("TUICore_TUIPluginNotify",
                                subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey",
                                object: nil,
                                param: param)
        }
    }
    
    // MARK: - Public

    static func translateMessage(_ data: TUIMessageCellData, completion: TUITranslateMessageCompletion?) {
        translateMessage(data, atUsers: nil, completion: completion)
    }
    
    static func translateMessage(_ data: TUIMessageCellData, atUsers: [String]?, completion: TUITranslateMessageCompletion?) {
        guard let msg = data.innerMessage, let textElem = msg.textElem,
              let target = TUITranslationConfig.shared.targetLanguageCode else { return }
        
        let originalText = textElem.text ?? ""
        
        // Split text into @mentions, emojis, and translatable text (without fetching user info)
        let splitResult = splitTextByAtMentionAndEmoji(originalText)
        let textArray = splitResult.textArray
        
        if textArray.isEmpty {
            // Nothing needs to be translated (only @mentions and emoji)
            saveTranslationResult(msg, text: originalText, status: .shown)
            completion?(0, "", data, TUITranslationViewStatus.shown.rawValue, originalText)
            return
        }
        
        let dict = TUITool.jsonData2Dictionary(msg.localCustomData) as? [String: Any]
        let translatedText = dict?[kKeyTranslationText] as? String
        
        if let translatedText = translatedText, !translatedText.isEmpty {
            saveTranslationResult(msg, text: translatedText, status: .shown)
            completion?(0, "", data, TUITranslationViewStatus.shown.rawValue, translatedText)
        } else {
            saveTranslationResult(msg, text: "", status: .loading)
            completion?(0, "", data, TUITranslationViewStatus.loading.rawValue, "")
        }
        
        // Send translate request
        V2TIMManager.sharedInstance().translateText(sourceTextList: textArray, sourceLanguage: "", targetLanguage: target, completion: { code, desc, result in
            guard let result = result else { return }
            if code != 0 || result.count == 0 {
                if code == 30007 {
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TranslateLanguageNotSupport"))
                } else {
                    TUITool.makeToastError(Int(code), msg: desc)
                }
                
                saveTranslationResult(msg, text: "", status: .hidden)
                completion?(Int(code), desc ?? "", data, TUITranslationViewStatus.hidden.rawValue, "")
                return
            }
            
            // Rebuild text with translations, keeping @mentions and emoji
            let translatedText = rebuildTextWithTranslations(parts: splitResult.parts, textArray: textArray, translations: result)
            saveTranslationResult(msg, text: translatedText, status: .shown)
            
            completion?(0, "", data, TUITranslationViewStatus.shown.rawValue, translatedText)
        })
    }
    
    // MARK: - Helper Methods for Text Splitting
    
    private enum PartType {
        case mention  // @xxx format
        case emoji    // Both TUIKit [xxx] and Unicode emoji
        case text     // Normal translatable text
    }
    
    private static func splitTextByAtMentionAndEmoji(_ text: String) -> (parts: [(type: PartType, content: String)], textArray: [String]) {
        var parts: [(type: PartType, content: String)] = []
        var textArray: [String] = []
        
        // Step 1: Find all @mention ranges (@xxx followed by space)
        let atPattern = "@[^ ]+ "
        let atRegex = try? NSRegularExpression(pattern: atPattern, options: [])
        let atMatches = atRegex?.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) ?? []
        
        var currentIndex = text.startIndex
        
        for atMatch in atMatches {
            guard let matchRange = Range(atMatch.range, in: text) else { continue }
            
            // Process text before @mention
            if currentIndex < matchRange.lowerBound {
                let beforeText = String(text[currentIndex..<matchRange.lowerBound])
                processTextWithEmoji(beforeText, parts: &parts, textArray: &textArray)
            }
            
            // Add @mention as is
            let mentionText = String(text[matchRange])
            parts.append((type: .mention, content: mentionText))
            
            currentIndex = matchRange.upperBound
        }
        
        // Process remaining text after last @mention
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            processTextWithEmoji(remainingText, parts: &parts, textArray: &textArray)
        }
        
        return (parts, textArray)
    }
    
    private static func processTextWithEmoji(_ text: String, parts: inout [(type: PartType, content: String)], textArray: inout [String]) {
        // Find all emoji ranges (TUIKit custom emoji + Unicode emoji)
        var emojiRanges: [NSRange] = []
        
        // TUIKit custom emoji: [xxx]
        let customEmojiPattern = String.getRegexEmoji()
        if let customRegex = try? NSRegularExpression(pattern: customEmojiPattern, options: .caseInsensitive) {
            let matches = customRegex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            if let faceGroup = TIMConfig.shared.faceGroups?.first {
                for match in matches {
                    let substring = (text as NSString).substring(with: match.range)
                    if let faces = faceGroup.faces, faces.contains(where: { $0.name == substring || $0.localizableName == substring }) {
                        emojiRanges.append(match.range)
                    }
                }
            }
        }
        
        // Unicode emoji
        let unicodeEmojiPattern = String.unicodeEmojiReString()
        if let unicodeRegex = try? NSRegularExpression(pattern: unicodeEmojiPattern, options: .caseInsensitive) {
            let matches = unicodeRegex.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length))
            emojiRanges.append(contentsOf: matches.map { $0.range })
        }
        
        // Sort emoji ranges by location
        emojiRanges.sort { $0.location < $1.location }
        
        // Split text by emoji ranges
        var currentPos = 0
        let nsText = text as NSString
        
        for emojiRange in emojiRanges {
            // Add text before emoji
            if currentPos < emojiRange.location {
                let textContent = nsText.substring(with: NSRange(location: currentPos, length: emojiRange.location - currentPos))
                if !textContent.isEmpty {
                    parts.append((type: .text, content: textContent))
                    textArray.append(textContent)
                }
            }
            
            // Add emoji
            let emojiContent = nsText.substring(with: emojiRange)
            parts.append((type: .emoji, content: emojiContent))
            
            currentPos = emojiRange.location + emojiRange.length
        }
        
        // Add remaining text
        if currentPos < nsText.length {
            let textContent = nsText.substring(from: currentPos)
            if !textContent.isEmpty {
                parts.append((type: .text, content: textContent))
                textArray.append(textContent)
            }
        }
    }
    
    private static func rebuildTextWithTranslations(parts: [(type: PartType, content: String)], textArray: [String], translations: [String: String]) -> String {
        var result = ""
        var textIndex = 0
        
        for part in parts {
            switch part.type {
            case .mention, .emoji:
                // Keep @mention and emoji as is
                result += part.content
            case .text:
                // Replace with translation
                if textIndex < textArray.count {
                    result += translations[textArray[textIndex]] ?? part.content
                    textIndex += 1
                }
            }
        }
        
        return result
    }
    
    static func saveTranslationResult(_ message: V2TIMMessage, text: String, status: TUITranslationViewStatus) {
        if !text.isEmpty {
            saveToLocalCustomData(ofMessage: message, key: kKeyTranslationText, value: text)
        }
        saveToLocalCustomData(ofMessage: message, key: kKeyTranslationViewStatus, value: status.rawValue)
    }
    
    static func saveToLocalCustomData(ofMessage message: V2TIMMessage, key: String, value: Any) {
        guard !key.isEmpty else { return }
        var dict = TUITool.jsonData2Dictionary(message.localCustomData) as? [String: Any] ?? [:]
        dict[key] = value
        message.localCustomData = TUITool.dictionary2JsonData(dict)
    }
    
    static func shouldShowTranslation(_ message: V2TIMMessage) -> Bool {
        guard let localCustomData = message.localCustomData, !localCustomData.isEmpty else { return false }
        let dict = TUITool.jsonData2Dictionary(localCustomData) as? [String: Any]
        let status = dict?[kKeyTranslationViewStatus] as? Int ?? TUITranslationViewStatus.hidden.rawValue
        let hiddenStatus: [Int] = [TUITranslationViewStatus.unknown.rawValue, TUITranslationViewStatus.hidden.rawValue]
        return !hiddenStatus.contains(status) || status == TUITranslationViewStatus.loading.rawValue
    }
    
    static func getTranslationText(_ message: V2TIMMessage) -> String? {
        if message.hasRiskContent {
            return TUISwift.timCommonLocalizableString("TUIKitMessageTypeSecurityStrikeTranslate")
        }
        guard let localCustomData = message.localCustomData, !localCustomData.isEmpty else { return nil }
        let dict = TUITool.jsonData2Dictionary(localCustomData) as? [String: Any]
        return dict?[kKeyTranslationText] as? String
    }
    
    static func getTranslationStatus(_ message: V2TIMMessage) -> TUITranslationViewStatus {
        if message.hasRiskContent {
            return .securityStrike
        }
        guard let localCustomData = message.localCustomData, !localCustomData.isEmpty else { return .unknown }
        let dict = TUITool.jsonData2Dictionary(localCustomData) as? [String: Any]
        let status = dict?[kKeyTranslationViewStatus] as? Int ?? TUITranslationViewStatus.unknown.rawValue
        return TUITranslationViewStatus(rawValue: status) ?? .unknown
    }
    
    // MARK: - Original Text Visibility Control
    
    /// Get whether original text should be hidden from localCustomData
    static func shouldHideOriginalText(_ message: V2TIMMessage) -> Bool {
        guard let localCustomData = message.localCustomData, !localCustomData.isEmpty else { return false }
        let dict = TUITool.jsonData2Dictionary(localCustomData) as? [String: Any]
        return dict?[kKeyShouldHideOriginalText] as? Bool ?? false
    }
    
    /// Save shouldHideOriginalText to localCustomData
    static func setShouldHideOriginalText(_ shouldHide: Bool, for message: V2TIMMessage) {
        saveToLocalCustomData(ofMessage: message, key: kKeyShouldHideOriginalText, value: shouldHide)
    }
    
    /// Get whether user manually requested to show original text from localCustomData
    static func userRequestedShowOriginal(_ message: V2TIMMessage) -> Bool {
        guard let localCustomData = message.localCustomData, !localCustomData.isEmpty else { return false }
        let dict = TUITool.jsonData2Dictionary(localCustomData) as? [String: Any]
        return dict?[kKeyUserRequestedShowOriginal] as? Bool ?? false
    }
    
    /// Save userRequestedShowOriginal to localCustomData
    static func setUserRequestedShowOriginal(_ requested: Bool, for message: V2TIMMessage) {
        saveToLocalCustomData(ofMessage: message, key: kKeyUserRequestedShowOriginal, value: requested)
    }
    
    /// Clear visibility state when hiding translation
    static func clearVisibilityState(_ message: V2TIMMessage) {
        var dict = TUITool.jsonData2Dictionary(message.localCustomData) as? [String: Any] ?? [:]
        dict.removeValue(forKey: kKeyShouldHideOriginalText)
        dict.removeValue(forKey: kKeyUserRequestedShowOriginal)
        message.localCustomData = TUITool.dictionary2JsonData(dict)
    }
}
