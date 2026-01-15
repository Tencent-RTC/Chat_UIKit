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
        let msg = data.innerMessage
        guard msg?.elemType == .ELEM_TYPE_TEXT else {
            return
        }
        
        // Get @ user's nickname by userID.
        let atUserIDs = msg?.groupAtUserList as? [String]
        if atUserIDs == nil || atUserIDs?.count == 0 {
            // There's not any @user info.
            translateMessage(data, atUsers: nil, completion: completion)
            return
        }
        
        // Find @All info.
        var atUserIDsExcludingAtAll = [String]()
        let atAllIndex = NSMutableIndexSet()
        for (i, userID) in atUserIDs!.enumerated() {
            if userID != kImSDK_MesssageAtALL {
                // Exclude @All.
                atUserIDsExcludingAtAll.append(userID)
            } else {
                // Record @All's location for later restore.
                atAllIndex.add(i)
            }
        }
        
        // There's only @All info.
        if atUserIDsExcludingAtAll.isEmpty {
            let atAllNames: [String] = Array(repeating: TUISwift.timCommonLocalizableString("All"), count: atAllIndex.count)
            translateMessage(data, atUsers: atAllNames, completion: completion)
            return
        }
        
        V2TIMManager.sharedInstance().getUsersInfo(atUserIDsExcludingAtAll, succ: { infoList in
            guard let infoList = infoList else { return }
            var atUserNames = [String]()
            for userID in atUserIDsExcludingAtAll {
                if let user = infoList.first(where: { $0.userID == userID }) {
                    atUserNames.append(user.nickName ?? user.userID ?? "")
                }
            }
            // Restore @All.
            atAllIndex.enumerate { idx, _ in
                atUserNames.insert(TUISwift.timCommonLocalizableString("All"), at: idx)
            }
            translateMessage(data, atUsers: atUserNames, completion: completion)
        }, fail: { _, _ in
            translateMessage(data, atUsers: atUserIDs, completion: completion)
        })
    }
    
    static func translateMessage(_ data: TUIMessageCellData, atUsers: [String]?, completion: TUITranslateMessageCompletion?) {
        guard let msg = data.innerMessage, let textElem = msg.textElem,
              let target = TUITranslationConfig.shared.targetLanguageCode else { return }
        
        let splitResult = textElem.text?.splitTextByEmojiAndAtUsers(atUsers)
        let textArray = splitResult?[String.kSplitStringTextKey] as? [String] ?? []
        
        if textArray.isEmpty {
            // Nothing needs to be translated.
            saveTranslationResult(msg, text: textElem.text ?? "", status: .shown)
            completion?(0, "", data, TUITranslationViewStatus.shown.rawValue, textElem.text ?? "")
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
        
        // Send translate request.
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
            
            let text = String.replacedStringWithArray(splitResult?[String.kSplitStringResultKey] as? [String] ?? [],
                                                      index: splitResult?[String.kSplitStringTextIndexKey] as? [Int] ?? [],
                                                      replaceDict: result) ?? ""
            saveTranslationResult(msg, text: text, status: .shown)
            
            completion?(0, "", data, TUITranslationViewStatus.shown.rawValue, text)
        })
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
