import Foundation
import TIMCommon

/// Utility for parsing official account messages (matches Android OfficialAccountMessageParser)
public class TUIOfficialAccountMessageParser {
    
    // MARK: - Singleton
    
    public static let shared = TUIOfficialAccountMessageParser()
    
    private static let TAG = "TUIOfficialAccountMessageParser"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Parse V2TIMMessage custom data to dictionary
    /// - Parameter message: V2TIMMessage to parse
    /// - Returns: Parsed dictionary, or nil if not a valid official account message
    public static func parseMessageData(_ message: V2TIMMessage?) -> [String: Any]? {
        guard let message = message else {
            debugLog("parseMessageData fail: message is nil")
            return nil
        }
        
        guard let customElem = message.customElem,
              let data = customElem.data,
              !data.isEmpty else {
            debugLog("parseMessageData fail: customElem or data is empty")
            return nil
        }
        
        guard let rawDict = TUITool.jsonData2Dictionary(data) else {
            debugLog("parseMessageData fail: cannot convert data to dictionary")
            return nil
        }
        
        // Check business ID
        guard let businessID = rawDict["businessID"] as? String,
              businessID == OfficialAccountMessageBusinessID else {
            debugLog("parseMessageData fail: business id not match")
            return nil
        }
        
        // Convert [AnyHashable: Any] to [String: Any]
        var dict: [String: Any] = [:]
        for (key, value) in rawDict {
            if let stringKey = key as? String {
                dict[stringKey] = value
            }
        }
        
        return dict
    }
    
    /// Check if message is an official account message
    /// - Parameter message: V2TIMMessage to check
    /// - Returns: True if message is from official account
    public static func isOfficialAccountMessage(_ message: V2TIMMessage?) -> Bool {
        return parseMessageData(message) != nil
    }
    
    // MARK: - Helper Methods
    
    private static func debugLog(_ message: String) {
        #if DEBUG
        print("[\(TAG)] \(message)")
        #endif
    }
}

