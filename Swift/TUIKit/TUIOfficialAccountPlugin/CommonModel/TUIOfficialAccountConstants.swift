import Foundation

// MARK: - Business ID
public let OfficialAccountBusinessID = "official_account"
// Must match Android: BUSINESS_ID_OFFICIAL_ACCOUNT = "official_account_tweet"
public let OfficialAccountMessageBusinessID = "official_account_tweet"

// MARK: - Notification Names
public let TUIOfficialAccountFollowChangedNotification = Notification.Name("TUIOfficialAccountFollowChangedNotification")
public let TUIOfficialAccountInfoUpdatedNotification = Notification.Name("TUIOfficialAccountInfoUpdatedNotification")

// MARK: - TUICore Service Keys
public struct TUIOfficialAccountServiceKey {
    public static let serviceName = "TUIOfficialAccountService"
    public static let showOfficialAccountListMethod = "showOfficialAccountList"
    public static let showOfficialAccountInfoMethod = "showOfficialAccountInfo"
    public static let getOfficialAccountInfoMethod = "getOfficialAccountInfo"
}

// MARK: - TUICore Extension Keys
public struct TUIOfficialAccountExtensionKey {
    public static let conversationListExtensionID = "TUICore_TUIConversationExtension_OfficialAccountExtensionID"
    public static let contactListExtensionID = "TUICore_TUIContactExtension_OfficialAccountExtensionID"
}

// MARK: - Parameter Keys
public struct TUIOfficialAccountParamKey {
    public static let navigationController = "navigationController"
    public static let officialAccountID = "officialAccountID"
    public static let officialAccountInfo = "officialAccountInfo"
    public static let isFromChatPage = "isFromChatPage"
}

// MARK: - Follow Status
public enum TUIOfficialAccountFollowStatus: Int {
    case notFollowed = 0
    case followed = 1
}

// MARK: - Account Type
public enum TUIOfficialAccountType: Int {
    case normal = 0
    case verified = 1
    case enterprise = 2
}

// MARK: - Message Type
public enum TUIOfficialAccountMessageType: Int {
    case text = 0
    case image = 1
    case richText = 2
    case link = 3
}
