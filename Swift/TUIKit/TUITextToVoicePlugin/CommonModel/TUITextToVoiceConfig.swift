import Foundation
import TIMCommon
import TUICore

/// Custom voice item model
public struct TUICustomVoiceItem: Equatable {
    public let voiceId: String
    public let name: String
    public let isDefault: Bool
    
    public init(voiceId: String, name: String, isDefault: Bool = false) {
        self.voiceId = voiceId
        self.name = name
        self.isDefault = isDefault
    }
    
    public static func == (lhs: TUICustomVoiceItem, rhs: TUICustomVoiceItem) -> Bool {
        return lhs.voiceId == rhs.voiceId
    }
}

class TUITextToVoiceConfig: NSObject {
    private static let kAutoTextToVoiceEnabled = "auto_text_to_voice_enabled"
    private static let kSelectedVoiceId = "selected_voice_id"
    private static let kSelectedVoiceName = "selected_voice_name"
    
    /// Default voice name for empty voiceId
    static var defaultVoiceName: String {
        return TUISwift.timCommonLocalizableString("VoiceDefault")
    }
    
    /// Follow global voice name (for conversation-level display)
    static var followGlobalVoiceName: String {
        return TUISwift.timCommonLocalizableString("VoiceFollowGlobal")
    }
    
    /// System voice list (built-in voices)
    static var systemVoiceList: [TUICustomVoiceItem] {
        return [
            TUICustomVoiceItem(voiceId: "male-kefu-xiaoxu", name: TUISwift.timCommonLocalizableString("VoiceXiaoxuMale"), isDefault: true),
            TUICustomVoiceItem(voiceId: "female-kefu-xiaomei", name: TUISwift.timCommonLocalizableString("VoiceXiaomeiFemale"), isDefault: true),
            TUICustomVoiceItem(voiceId: "female-kefu-xiaoxin", name: TUISwift.timCommonLocalizableString("VoiceXiaoxinFemale"), isDefault: true),
            TUICustomVoiceItem(voiceId: "female-kefu-xiaoyue", name: TUISwift.timCommonLocalizableString("VoiceXiaoyueFemale"), isDefault: true)
        ]
    }
    
    /// Default voice list (includes "Default" option + system voices)
    static var defaultVoiceList: [TUICustomVoiceItem] {
        var list = [TUICustomVoiceItem(voiceId: "", name: defaultVoiceName, isDefault: true)]
        list.append(contentsOf: systemVoiceList)
        return list
    }
    
    static let shared: TUITextToVoiceConfig = {
        let instance = TUITextToVoiceConfig()
        return instance
    }()
    
    /// Current logged-in user ID
    private var currentUserID: String {
        return TUILogin.getUserID() ?? ""
    }
    
    /// Generate user-specific key
    private func userKey(_ baseKey: String) -> String {
        let userID = currentUserID
        if userID.isEmpty {
            return baseKey
        }
        return "\(userID)_\(baseKey)"
    }
    
    /**
     * 文字消息自动转语音
     * Auto convert text messages to voice.
     */
    var autoTextToVoiceEnabled: Bool {
        get {
            return UserDefaults.standard.bool(forKey: userKey(TUITextToVoiceConfig.kAutoTextToVoiceEnabled))
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userKey(TUITextToVoiceConfig.kAutoTextToVoiceEnabled))
            UserDefaults.standard.synchronize()
        }
    }
    
    /**
     * 当前选中的音色ID
     * Currently selected voice ID.
     */
    var selectedVoiceId: String {
        get {
            return UserDefaults.standard.string(forKey: userKey(TUITextToVoiceConfig.kSelectedVoiceId)) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userKey(TUITextToVoiceConfig.kSelectedVoiceId))
            UserDefaults.standard.synchronize()
        }
    }
    
    /**
     * 当前选中的音色名称
     * Currently selected voice name.
     */
    var selectedVoiceName: String {
        get {
            return UserDefaults.standard.string(forKey: userKey(TUITextToVoiceConfig.kSelectedVoiceName)) ?? TUITextToVoiceConfig.defaultVoiceName
        }
        set {
            UserDefaults.standard.set(newValue, forKey: userKey(TUITextToVoiceConfig.kSelectedVoiceName))
            UserDefaults.standard.synchronize()
        }
    }
    
    override init() {
        super.init()
    }
    
    /// Get display name for current selected voice
    func getSelectedVoiceDisplayName() -> String {
        if selectedVoiceId.isEmpty {
            return TUITextToVoiceConfig.defaultVoiceName
        }
        // Look up localized name from system voice list by voiceId
        if let systemVoice = TUITextToVoiceConfig.systemVoiceList.first(where: { $0.voiceId == selectedVoiceId }) {
            return systemVoice.name
        }
        // For custom voices, return stored name
        if selectedVoiceName.isEmpty {
            return TUITextToVoiceConfig.defaultVoiceName
        }
        return selectedVoiceName
    }
}
