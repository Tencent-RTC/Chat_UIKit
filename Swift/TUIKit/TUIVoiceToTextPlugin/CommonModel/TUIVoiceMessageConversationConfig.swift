import Foundation

/// Setting types for voice message features (VoiceToText Plugin)
public enum TUIVoiceMessageSettingType: String {
    case autoPlayVoice = "autoPlayVoice"
    case autoVoiceToText = "autoVoiceToText"
}

/// Conversation-level configuration for voice message features
/// Manages per-conversation settings for auto-play and voice-to-text
public class TUIVoiceMessageConversationConfig {
    
    // MARK: - Singleton
    
    public static let shared = TUIVoiceMessageConversationConfig()
    
    // MARK: - Properties
    
    /// Storage key prefix for UserDefaults
    private let storageKeyPrefix = "TUIVoiceMessage_ConversationConfig_"
    
    /// In-memory cache for settings
    private var settingsCache: [String: [String: Any]] = [:]
    
    // MARK: - Initialization
    
    private init() {
        loadAllSettings()
    }
    
    // MARK: - Public Methods
    
    /// Get setting for a specific conversation and type
    /// Returns nil if no explicit setting exists (should use global setting)
    public func getSetting(for conversationID: String, type: TUIVoiceMessageSettingType) -> NSNumber? {
        guard let conversationSettings = settingsCache[conversationID],
              let value = conversationSettings[type.rawValue] as? Bool
        else { return nil }
        return NSNumber(value: value)
    }
    
    /// Set setting for a specific conversation and type
    public func setSetting(_ value: Bool, for conversationID: String, type: TUIVoiceMessageSettingType) {
        var conversationSettings = settingsCache[conversationID] ?? [:]
        conversationSettings[type.rawValue] = value
        settingsCache[conversationID] = conversationSettings
        saveSettings(for: conversationID)
    }
    
    /// Remove setting for a specific conversation and type (revert to global)
    public func removeSetting(for conversationID: String, type: TUIVoiceMessageSettingType) {
        guard var conversationSettings = settingsCache[conversationID] else { return }
        conversationSettings.removeValue(forKey: type.rawValue)
        if conversationSettings.isEmpty {
            settingsCache.removeValue(forKey: conversationID)
            UserDefaults.standard.removeObject(forKey: storageKeyPrefix + conversationID)
        } else {
            settingsCache[conversationID] = conversationSettings
            saveSettings(for: conversationID)
        }
    }
    
    /// Check if conversation has explicit setting for a type
    public func hasExplicitSetting(for conversationID: String, type: TUIVoiceMessageSettingType) -> Bool {
        return getSetting(for: conversationID, type: type) != nil
    }
    
    /// Get effective setting value considering conversation-level override
    /// Returns true if should enable the feature
    public func shouldEnable(for conversationID: String, type: TUIVoiceMessageSettingType, globalEnabled: Bool) -> Bool {
        if let conversationSetting = getSetting(for: conversationID, type: type) {
            return conversationSetting.boolValue
        }
        return globalEnabled
    }
    
    // MARK: - Private Methods
    
    private func loadAllSettings() {
        let defaults = UserDefaults.standard
        let allKeys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(storageKeyPrefix) }
        
        for key in allKeys {
            let conversationID = String(key.dropFirst(storageKeyPrefix.count))
            if let data = defaults.dictionary(forKey: key) {
                settingsCache[conversationID] = data
            }
        }
    }
    
    private func saveSettings(for conversationID: String) {
        guard let settings = settingsCache[conversationID] else { return }
        UserDefaults.standard.set(settings, forKey: storageKeyPrefix + conversationID)
    }
}
