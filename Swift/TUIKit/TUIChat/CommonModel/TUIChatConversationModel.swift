
import Foundation
import UIKit

public class TUIChatConversationModel: NSObject {
    /// UniqueID for a conversation
    public var conversationID: String?
    
    /// If the conversation type is group chat, the groupID means group id
    public var groupID: String?
    
    /// Group type
    public var groupType: String?
    
    /// If the conversation type is one-to-one chat, the userID means peer user id
    public var userID: String?
    
    /// Title
    @objc public dynamic var title: String?
    
    /// The avatar of the user or group corresponding to the conversation
    @objc public dynamic var faceUrl: String?
    
    /// Image for avatar
    public var avatarImage: UIImage?
    
    /// Conversation draft
    public var draftText: String?
    
    /// Group@ message tip string
    public var atTipsStr: String?
    
    /// Sequence list of group-at message
    public var atMsgSeqs: [Int]?
    
    /// The input status of the other Side (C2C Only)
    @objc public dynamic var otherSideTyping: Bool = false
    
    /// A read receipt is required to send a message, the default is YES
    private var _msgNeedReadReceipt: Bool = true
    public var msgNeedReadReceipt: Bool {
        get {
            // AI conversations don't need read receipts
            if isAIConversation() {
                return false
            }
            return _msgNeedReadReceipt
        }
        set {
            _msgNeedReadReceipt = newValue
        }
    }
    
    /// Display the video call button, if the TUICalling component is integrated, the default is YES
    public var enableVideoCall: Bool = true
    
    /// Whether to display the audio call button, if the TUICalling component is integrated, the default is YES
    public var enableAudioCall: Bool = true
    
    /// Display custom welcome message button, default YES
    public var enableWelcomeCustomMessage: Bool = true
    
    public var enableRoom: Bool = true
    public var isLimitedPortraitOrientation: Bool = false
    public var enablePoll: Bool = true
    public var enableGroupNote: Bool = true
    public var enableTakePhoto: Bool = true
    public var enableRecordVideo: Bool = true
    public var enableAlbum: Bool = true
    public var enableFile: Bool = true
    
    public var customizedNewItemsInMoreMenu: [Any]?
    public var shortcutViewBackgroundColor: UIColor?
    public var shortcutViewHeight: CGFloat = 0.0
    public var shortcutMenuItems: [TUIChatShortcutMenuCellData]?
    
    // MARK: - AI Conversation Methods
    
    /// Check if this is an AI conversation
    /// AI conversations are identified by conversation IDs containing or starting with "@RBT#"
    public func isAIConversation() -> Bool {
        guard let conversationID = conversationID else {
            return false
        }
        return conversationID.contains("@RBT#") || conversationID.hasPrefix("@RBT#")
    }
    

}
