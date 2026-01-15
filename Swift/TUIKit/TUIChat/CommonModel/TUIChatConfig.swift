import Foundation
import TIMCommon
import TUICore

public enum TUIChatRegisterCustomMessageStyleType: UInt {
    case classic = 0
    case minimalist = 1
}

public struct TUIChatInputBarMoreMenuItem: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let none = TUIChatInputBarMoreMenuItem([])
    public static let customMessage = TUIChatInputBarMoreMenuItem(rawValue: 1 << 0)
    public static let takePhoto = TUIChatInputBarMoreMenuItem(rawValue: 1 << 1)
    public static let recordVideo = TUIChatInputBarMoreMenuItem(rawValue: 1 << 2)
    public static let album = TUIChatInputBarMoreMenuItem(rawValue: 1 << 3)
    public static let file = TUIChatInputBarMoreMenuItem(rawValue: 1 << 4)
    public static let room = TUIChatInputBarMoreMenuItem(rawValue: 1 << 5)
    public static let poll = TUIChatInputBarMoreMenuItem(rawValue: 1 << 6)
    public static let groupNote = TUIChatInputBarMoreMenuItem(rawValue: 1 << 7)
    public static let videoCall = TUIChatInputBarMoreMenuItem(rawValue: 1 << 8)
    public static let audioCall = TUIChatInputBarMoreMenuItem(rawValue: 1 << 9)
}

public protocol TUIChatInputBarConfigDataSource: AnyObject {
    /**
     *  Implement this method to hide items in more menu of the specified model.
     */
    func shouldHideItems(of model: TUIChatConversationModel) -> TUIChatInputBarMoreMenuItem
    /**
     *  Implement this method to add new items to the more menu of the specified model only for the classic version.
     */
    func shouldAddNewItemsToMoreMenu(of model: TUIChatConversationModel) -> [TUIInputMoreCellData]?
    /**
     *  Implement this method to add new items to the more list of the specified model only for the minimalist version.
     */
    func shouldAddNewItemsToMoreList(of model: TUIChatConversationModel) -> [TUICustomActionSheetItem]?
}

extension TUIChatInputBarConfigDataSource {
    func shouldHideItems(of model: TUIChatConversationModel) -> TUIChatInputBarMoreMenuItem {
        return TUIChatInputBarMoreMenuItem.none
    }

    func shouldAddNewItems(of model: TUIChatConversationModel) -> [TUICustomActionSheetItem]? {
        return nil
    }
}

@objc public protocol TUIChatShortcutViewDataSource: AnyObject {
    /**
     *  Customized items in shortcut view.
     */
    @objc optional func items(of model: TUIChatConversationModel) -> [TUIChatShortcutMenuCellData]
    /**
     *  Background color of shortcut view.
     */
    @objc optional func backgroundColor(of model: TUIChatConversationModel) -> UIColor
    /**
     *  View height of shortcut view.
     */
    @objc optional func height(of model: TUIChatConversationModel) -> CGFloat
}

extension TUIChatShortcutViewDataSource {
    func items(of model: TUIChatConversationModel) -> [TUIChatShortcutMenuCellData]? {
        return nil
    }

    func backgroundColor(of model: TUIChatConversationModel) -> UIColor {
        return UIColor.tui_color(withHex: "#EBF0F6")
    }

    func height(of model: TUIChatConversationModel) -> CGFloat {
        return 46.0
    }
}

public class TUIChatConfig: NSObject {
    public static let shared = TUIChatConfig()

    public weak var inputBarDataSource: TUIChatInputBarConfigDataSource?
    public weak var shortcutViewDataSource: TUIChatShortcutViewDataSource?

    public var msgNeedReadReceipt = false
    public var enableVideoCall = true
    public var enableAudioCall = true
    public var enableWelcomeCustomMessage = true
    public var enablePopMenuEmojiReactAction = true
    public var enablePopMenuReplyAction = true
    public var enablePopMenuReferenceAction = true
    public var enablePopMenuPinAction = true
    public var enablePopMenuRecallAction = true
    public var enablePopMenuTranslateAction = true
    public var enablePopMenuConvertAction = true
    public var enablePopMenuForwardAction = true
    public var enablePopMenuSelectAction = true
    public var enablePopMenuCopyAction = true
    public var enablePopMenuDeleteAction = true
    public var enablePopMenuInfoAction = true
    public var enablePopMenuAudioPlaybackAction = true
    public var enablePopMenuTextToVoiceAction = true
    public var enableTypingStatus = true
    public var enableMainPageInputBar = true
    public var backgroudColor: UIColor?
    public var backgroudImage: UIImage?
    public var enableFloatWindowForCall = true
    public var enableMultiDeviceForCall = false
    public var enableIncomingBanner = true
    public var enableVirtualBackgroundForCall = false
    public var timeIntervalForMessageRecall: UInt = 120
    public var maxAudioRecordDuration: CGFloat = 60
    public var maxVideoRecordDuration: CGFloat = 15
    public var showRoomButton = true
    public var showPollButton = true
    public var showGroupNoteButton = true
    public var showRecordVideoButton = true
    public var showTakePhotoButton = true
    public var showAlbumButton = true
    public var showFileButton = true

    private var _eventConfig: TUIChatEventConfig?
    public var eventConfig: TUIChatEventConfig {
        if _eventConfig == nil {
            _eventConfig = TUIChatEventConfig()
        }
        return _eventConfig!
    }

    public func chatContextEmojiDetailGroups() -> [TUIFaceGroup]? {
        guard let service = TIMCommonMediator.shared.getObject(for: TUIEmojiMeditorProtocol.self) as? TUIEmojiMeditorProtocol,
              let groups = service.getChatContextEmojiDetailGroups() as? [TUIFaceGroup]
        else {
            return nil
        }
        return groups
    }
}

public protocol TUIChatEventListener: AnyObject {
    func onUserIconClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool
    func onUserIconLongClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool
    func onMessageClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool
    func onMessageLongClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool
}

extension TUIChatEventListener {
    func onUserIconClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool { return false }
    func onUserIconLongClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool { return false }
    func onMessageClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool { return false }
    func onMessageLongClicked(_ view: UIView, messageCellData: TUIMessageCellData) -> Bool { return false }
}

public class TUIChatEventConfig: NSObject {
    public weak var chatEventListener: TUIChatEventListener?
}

extension TUIChatConfig {
    func registerCustomMessage(businessID: String, messageCellClassName cellName: String, messageCellDataClassName cellDataName: String) {
        registerCustomMessage(businessID: businessID, messageCellClassName: cellName, messageCellDataClassName: cellDataName, styleType: .classic)
    }

    func registerCustomMessage(businessID: String, messageCellClassName cellName: String, messageCellDataClassName cellDataName: String, styleType: TUIChatRegisterCustomMessageStyleType) {
        guard !businessID.isEmpty, !cellName.isEmpty, !cellDataName.isEmpty else {
            print("registerCustomMessage Error, check info")
            return
        }
        let serviceName: String
        if styleType == .classic {
            serviceName = "TUICore_TUIChatService"
        } else {
            serviceName = "TUICore_TUIChatService_Minimalist"
        }
        TUICore.callService(serviceName, method: "TUICore_TUIChatService_AppendCustomMessageMethod", param: [
            "businessID": businessID,
            "TMessageCell_Name": cellName,
            "TMessageCell_Data_Name": cellDataName
        ])
    }
}
