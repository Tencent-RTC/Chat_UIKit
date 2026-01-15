import Foundation
import TIMCommon

/// Official Account information model
public class TUIOfficialAccountInfo: NSObject, NSCopying {
    /// Account ID
    public var accountID: String = ""
    
    /// Account name
    public var accountName: String = ""
    
    /// Account avatar URL
    public var faceURL: String?
    
    /// Account description
    public var accountDescription: String?
    
    /// Account type
    public var accountType: TUIOfficialAccountType = .normal
    
    /// Follow status
    public var followStatus: TUIOfficialAccountFollowStatus = .notFollowed
    
    /// Subscriber count
    public var subscriberCount: UInt = 0
    
    /// Introduction text
    public var introduction: String?
    
    /// Custom data
    public var customData: [String: Any]?
    
    /// Last message time
    public var lastMessageTime: TimeInterval = 0
    
    /// Unread message count
    public var unreadCount: UInt = 0
    
    /// Owner user ID
    public var ownerUserID: String = ""
    
    /// Whether the current user is the owner of this account
    public var isOwner: Bool = false
    
    /// Whether the account is verified
    public var isVerified: Bool {
        return accountType == .verified || accountType == .enterprise
    }
    
    /// Whether the current user has followed this account
    public var isFollowed: Bool {
        return followStatus == .followed
    }
    
    public override init() {
        super.init()
    }
    
    /// Initialize from dictionary
    /// - Parameter dict: Dictionary containing account info
    public convenience init?(dict: [String: Any]?) {
        guard let dict = dict else { return nil }
        self.init()
        
        self.accountID = dict["accountID"] as? String ?? ""
        self.accountName = dict["accountName"] as? String ?? ""
        self.faceURL = dict["faceURL"] as? String
        self.accountDescription = dict["description"] as? String
        self.accountType = TUIOfficialAccountType(rawValue: dict["accountType"] as? Int ?? 0) ?? .normal
        self.followStatus = TUIOfficialAccountFollowStatus(rawValue: dict["followStatus"] as? Int ?? 0) ?? .notFollowed
        self.subscriberCount = dict["subscriberCount"] as? UInt ?? 0
        self.introduction = dict["introduction"] as? String
        self.customData = dict["customData"] as? [String: Any]
        self.lastMessageTime = dict["lastMessageTime"] as? TimeInterval ?? 0
        self.unreadCount = dict["unreadCount"] as? UInt ?? 0
    }
    
    /// Initialize from V2TIMMessage custom element
    /// - Parameter message: V2TIMMessage containing official account info
    public convenience init?(message: V2TIMMessage?) {
        guard let message = message,
              let customElem = message.customElem,
              let data = customElem.data else {
            return nil
        }
        
        guard let rawDict = TUITool.jsonData2Dictionary(data) else {
            return nil
        }
        
        // Convert [AnyHashable: Any] to [String: Any]
        var dict: [String: Any] = [:]
        for (key, value) in rawDict {
            if let stringKey = key as? String {
                dict[stringKey] = value
            }
        }
        
        self.init(dict: dict)
    }
    
    public func copy(with zone: NSZone? = nil) -> Any {
        let copy = TUIOfficialAccountInfo()
        copy.accountID = accountID
        copy.accountName = accountName
        copy.faceURL = faceURL
        copy.accountDescription = accountDescription
        copy.accountType = accountType
        copy.followStatus = followStatus
        copy.subscriberCount = subscriberCount
        copy.introduction = introduction
        copy.customData = customData
        copy.lastMessageTime = lastMessageTime
        copy.unreadCount = unreadCount
        copy.ownerUserID = ownerUserID
        copy.isOwner = isOwner
        return copy
    }
    
    /// Convert to dictionary
    /// - Returns: Dictionary representation of the account info
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "accountID": accountID,
            "accountName": accountName,
            "accountType": accountType.rawValue,
            "followStatus": followStatus.rawValue,
            "subscriberCount": subscriberCount,
            "lastMessageTime": lastMessageTime,
            "unreadCount": unreadCount
        ]
        
        if let faceURL = faceURL {
            dict["faceURL"] = faceURL
        }
        if let accountDescription = accountDescription {
            dict["description"] = accountDescription
        }
        if let introduction = introduction {
            dict["introduction"] = introduction
        }
        if let customData = customData {
            dict["customData"] = customData
        }
        
        return dict
    }
}

// MARK: - Display Helpers
extension TUIOfficialAccountInfo {
    /// Get display name with fallback
    public var displayName: String {
        if !accountName.isEmpty {
            return accountName
        }
        return accountID
    }
    
    /// Get formatted subscriber count string
    public var formattedSubscriberCount: String {
        if subscriberCount >= 10000 {
            let count = Double(subscriberCount) / 10000.0
            return String(format: "%.1fw", count)
        }
        return "\(subscriberCount)"
    }
}
