import Foundation
import TUICore

/// Setting type for conversation-level text-to-voice features
@objc public enum TUITextToVoiceSettingType: Int {
    /// Auto convert text to voice
    case autoTextToVoice = 0
}

/// Voice selection setting for conversation
public struct TUITextToVoiceConversationVoiceSetting: Codable {
    public let voiceId: String
    public let voiceName: String
    
    public init(voiceId: String, voiceName: String) {
        self.voiceId = voiceId
        self.voiceName = voiceName
    }
}

/// Manages per-conversation text-to-voice settings
/// Priority: Conversation setting > Global setting
public class TUITextToVoiceConversationConfig: NSObject {
    
    // MARK: - Singleton
    
    @objc public static let shared = TUITextToVoiceConversationConfig()
    
    // MARK: - Constants
    
    private let userDefaultsKeyPrefix = "TUITextToVoice_Conversation"
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods (Type-specific)
    
    /// Get setting for specific conversation and type
    /// - Parameters:
    ///   - conversationID: Conversation ID (e.g., "c2c_userID" or "group_groupID")
    ///   - type: Setting type
    /// - Returns: nil if not set (use global), true/false if explicitly set
    @objc public func getSetting(for conversationID: String, type: TUITextToVoiceSettingType) -> NSNumber? {
        guard !conversationID.isEmpty else { return nil }
        let map = getConversationMap(for: type)
        if let value = map[conversationID] {
            return NSNumber(value: value)
        }
        return nil
    }
    
    /// Set setting for specific conversation and type
    /// - Parameters:
    ///   - enabled: Whether the feature is enabled for this conversation
    ///   - conversationID: Conversation ID
    ///   - type: Setting type
    @objc public func setSetting(_ enabled: Bool, for conversationID: String, type: TUITextToVoiceSettingType) {
        guard !conversationID.isEmpty else { return }
        var map = getConversationMap(for: type)
        map[conversationID] = enabled
        saveConversationMap(map, for: type)
        
        // Notify change
        NotificationCenter.default.post(
            name: NSNotification.Name("TUITextToVoiceConversationConfigChanged"),
            object: nil,
            userInfo: ["conversationID": conversationID, "type": type.rawValue, "enabled": enabled]
        )
    }
    
    /// Remove setting for conversation (fall back to global)
    /// - Parameters:
    ///   - conversationID: Conversation ID
    ///   - type: Setting type
    @objc public func removeSetting(for conversationID: String, type: TUITextToVoiceSettingType) {
        guard !conversationID.isEmpty else { return }
        var map = getConversationMap(for: type)
        map.removeValue(forKey: conversationID)
        saveConversationMap(map, for: type)
        
        // Notify change
        NotificationCenter.default.post(
            name: NSNotification.Name("TUITextToVoiceConversationConfigChanged"),
            object: nil,
            userInfo: ["conversationID": conversationID, "type": type.rawValue, "removed": true]
        )
    }
    
    /// Check if feature should be enabled for conversation (considering priority)
    /// Priority: Conversation setting > Global setting
    /// - Parameters:
    ///   - conversationID: Conversation ID
    ///   - type: Setting type
    ///   - globalEnabled: Global setting value
    /// - Returns: Whether the feature should be enabled
    @objc public func shouldEnable(for conversationID: String, type: TUITextToVoiceSettingType, globalEnabled: Bool) -> Bool {
        if let conversationSetting = getSetting(for: conversationID, type: type) {
            return conversationSetting.boolValue
        }
        return globalEnabled
    }
    
    /// Check if conversation has explicit setting (not using global)
    /// - Parameters:
    ///   - conversationID: Conversation ID
    ///   - type: Setting type
    /// - Returns: true if conversation has explicit setting
    @objc public func hasExplicitSetting(for conversationID: String, type: TUITextToVoiceSettingType) -> Bool {
        return getSetting(for: conversationID, type: type) != nil
    }
    
    // MARK: - Private Methods
    
    private func getStorageKey(for type: TUITextToVoiceSettingType) -> String {
        let loginUserID = TUILogin.getUserID() ?? "default"
        let typeSuffix: String
        switch type {
        case .autoTextToVoice:
            typeSuffix = "TextToVoice"
        }
        return "\(userDefaultsKeyPrefix)_\(typeSuffix)_\(loginUserID)"
    }
    
    private func getConversationMap(for type: TUITextToVoiceSettingType) -> [String: Bool] {
        let key = getStorageKey(for: type)
        guard let dict = UserDefaults.standard.dictionary(forKey: key) as? [String: Bool] else {
            return [:]
        }
        return dict
    }
    
    private func saveConversationMap(_ map: [String: Bool], for type: TUITextToVoiceSettingType) {
        let key = getStorageKey(for: type)
        UserDefaults.standard.set(map, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    // MARK: - Voice Selection Methods
    
    private var voiceSelectionStorageKey: String {
        let loginUserID = TUILogin.getUserID() ?? "default"
        return "\(userDefaultsKeyPrefix)_VoiceSelection_\(loginUserID)"
    }
    
    /// Get voice selection for specific conversation
    /// - Parameter conversationID: Conversation ID
    /// - Returns: Voice setting if set, nil if using global
    public func getVoiceSetting(for conversationID: String) -> TUITextToVoiceConversationVoiceSetting? {
        guard !conversationID.isEmpty else { return nil }
        let map = getVoiceSelectionMap()
        return map[conversationID]
    }
    
    /// Set voice selection for specific conversation
    /// - Parameters:
    ///   - voiceId: Voice ID
    ///   - voiceName: Voice name
    ///   - conversationID: Conversation ID
    public func setVoiceSetting(voiceId: String, voiceName: String, for conversationID: String) {
        guard !conversationID.isEmpty else { return }
        var map = getVoiceSelectionMap()
        map[conversationID] = TUITextToVoiceConversationVoiceSetting(voiceId: voiceId, voiceName: voiceName)
        saveVoiceSelectionMap(map)
        
        // Notify change
        NotificationCenter.default.post(
            name: NSNotification.Name("TUITextToVoiceConversationConfigChanged"),
            object: nil,
            userInfo: ["conversationID": conversationID, "voiceId": voiceId, "voiceName": voiceName]
        )
    }
    
    /// Remove voice selection for conversation (fall back to global)
    /// - Parameter conversationID: Conversation ID
    public func removeVoiceSetting(for conversationID: String) {
        guard !conversationID.isEmpty else { return }
        var map = getVoiceSelectionMap()
        map.removeValue(forKey: conversationID)
        saveVoiceSelectionMap(map)
        
        // Notify change
        NotificationCenter.default.post(
            name: NSNotification.Name("TUITextToVoiceConversationConfigChanged"),
            object: nil,
            userInfo: ["conversationID": conversationID, "voiceRemoved": true]
        )
    }
    
    /// Get effective voice ID for conversation
    /// Priority: Conversation setting > Global setting
    /// - Parameters:
    ///   - conversationID: Conversation ID
    ///   - globalVoiceId: Global voice ID
    /// - Returns: Effective voice ID
    public func getEffectiveVoiceId(for conversationID: String, globalVoiceId: String) -> String {
        if let setting = getVoiceSetting(for: conversationID) {
            return setting.voiceId
        }
        return globalVoiceId
    }
    
    /// Get effective voice name for conversation
    /// Priority: Conversation setting > Global setting
    /// - Parameters:
    ///   - conversationID: Conversation ID
    ///   - globalVoiceName: Global voice name
    /// - Returns: Effective voice name
    public func getEffectiveVoiceName(for conversationID: String, globalVoiceName: String) -> String {
        if let setting = getVoiceSetting(for: conversationID) {
            return setting.voiceName
        }
        return globalVoiceName
    }
    
    /// Check if conversation has explicit voice setting
    /// - Parameter conversationID: Conversation ID
    /// - Returns: true if conversation has explicit voice setting
    public func hasExplicitVoiceSetting(for conversationID: String) -> Bool {
        return getVoiceSetting(for: conversationID) != nil
    }
    
    /// Get display voice name for conversation settings UI
    /// Shows "Follow Global" if no explicit setting, otherwise shows the voice name
    /// - Parameter conversationID: Conversation ID
    /// - Returns: Display name for UI
    public func getDisplayVoiceName(for conversationID: String) -> String {
        if let setting = getVoiceSetting(for: conversationID) {
            if setting.voiceId.isEmpty {
                return TUITextToVoiceConfig.defaultVoiceName
            }
            return setting.voiceName
        }
        return TUITextToVoiceConfig.followGlobalVoiceName
    }
    
    private func getVoiceSelectionMap() -> [String: TUITextToVoiceConversationVoiceSetting] {
        guard let data = UserDefaults.standard.data(forKey: voiceSelectionStorageKey),
              let map = try? JSONDecoder().decode([String: TUITextToVoiceConversationVoiceSetting].self, from: data) else {
            return [:]
        }
        return map
    }
    
    private func saveVoiceSelectionMap(_ map: [String: TUITextToVoiceConversationVoiceSetting]) {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: voiceSelectionStorageKey)
            UserDefaults.standard.synchronize()
        }
    }
}
