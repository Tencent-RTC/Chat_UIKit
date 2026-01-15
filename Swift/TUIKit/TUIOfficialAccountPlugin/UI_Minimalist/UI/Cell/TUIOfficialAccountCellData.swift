import Foundation
import TIMCommon

/// Cell data for official account cell
public class TUIOfficialAccountCellData: NSObject {
    
    // MARK: - Properties
    
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
    
    /// Last message time
    public var lastMessageTime: TimeInterval = 0
    
    /// Unread count
    public var unreadCount: UInt = 0
    
    /// Last message text
    public var lastMessage: String?
    
    /// Whether current user is the owner
    public var isOwner: Bool = false
    
    /// Original account info
    public weak var accountInfo: TUIOfficialAccountInfo?
    
    // MARK: - Computed Properties
    
    /// Display name
    public var displayName: String {
        return accountName.isEmpty ? accountID : accountName
    }
    
    /// Is followed
    public var isFollowed: Bool {
        return followStatus == .followed
    }
    
    /// Is verified
    public var isVerified: Bool {
        return accountType == .verified || accountType == .enterprise
    }
    
    /// Formatted subscriber count
    public var formattedSubscriberCount: String {
        if subscriberCount >= 10000 {
            let count = Double(subscriberCount) / 10000.0
            return String(format: "%.1fw", count)
        }
        return "\(subscriberCount)"
    }
    
    /// Formatted last message time
    public var formattedLastMessageTime: String {
        guard lastMessageTime > 0 else { return "" }
        
        let date = Date(timeIntervalSince1970: lastMessageTime / 1000)
        let formatter = DateFormatter()
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return TUISwift.timCommonLocalizableString("TUIKitYesterday") ?? "Yesterday"
        } else {
            formatter.dateFormat = "MM-dd"
        }
        
        return formatter.string(from: date)
    }
    
    // MARK: - Cell Height
    
    /// Cell height
    public static let cellHeight: CGFloat = 72.0
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    /// Initialize from account info
    /// - Parameter accountInfo: Account info model
    public convenience init(accountInfo: TUIOfficialAccountInfo) {
        self.init()
        self.accountInfo = accountInfo
        self.accountID = accountInfo.accountID
        self.accountName = accountInfo.accountName
        self.faceURL = accountInfo.faceURL
        self.accountDescription = accountInfo.accountDescription
        self.accountType = accountInfo.accountType
        self.followStatus = accountInfo.followStatus
        self.subscriberCount = accountInfo.subscriberCount
        self.lastMessageTime = accountInfo.lastMessageTime
        self.unreadCount = accountInfo.unreadCount
        self.isOwner = accountInfo.isOwner
    }
    
    /// Update from account info
    /// - Parameter accountInfo: Account info model
    public func update(with accountInfo: TUIOfficialAccountInfo) {
        self.accountInfo = accountInfo
        self.accountID = accountInfo.accountID
        self.accountName = accountInfo.accountName
        self.faceURL = accountInfo.faceURL
        self.accountDescription = accountInfo.accountDescription
        self.accountType = accountInfo.accountType
        self.followStatus = accountInfo.followStatus
        self.subscriberCount = accountInfo.subscriberCount
        self.lastMessageTime = accountInfo.lastMessageTime
        self.unreadCount = accountInfo.unreadCount
        self.isOwner = accountInfo.isOwner
    }
}
