import Foundation
import UIKit

public enum TMsgStatus: UInt {
    case initStatus = 0
    case sending
    case sending2
    case success
    case fail
}

public enum TMsgDirection: UInt {
    case incoming
    case outgoing
}

public enum TMsgSource: UInt {
    case unknown = 0
    case onlinePush
    case getHistory
}

public protocol TUIMessageCellDataDelegate: AnyObject {
    static func getCellData(message: V2TIMMessage) -> TUIMessageCellData
    static func getDisplayString(message: V2TIMMessage) -> String
}

open class TUIMessageCellData: TUICommonCellData, TUIMessageCellDataDelegate {
    open class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        return TUIMessageCellData(direction: .incoming)
    }

    open class func getDisplayString(message: V2TIMMessage) -> String {
        return ""
    }

    open func getReplyQuoteViewDataClass() -> AnyClass? {
        return nil
    }

    open func getReplyQuoteViewClass() -> AnyClass? {
        return nil
    }

    private var _msgID: String?
    public var msgID: String? {
        get {
            return _msgID ?? innerMessage?.msgID
        }
        set {
            _msgID = newValue
        }
    }

    private var _identifier: String?
    public var identifier: String? {
        get {
            return _identifier ?? innerMessage?.sender
        }
        set {
            _identifier = newValue
        }
    }

    public var senderName: String {
        return innerMessage?.nameCard ?? innerMessage?.friendRemark ?? innerMessage?.nickName ?? innerMessage?.sender ?? ""
    }

    private var _avatarUrl: URL?
    @objc public dynamic var avatarUrl: URL? {
        get {
            return _avatarUrl ?? URL(string: innerMessage?.faceURL ?? "")
        }
        set {
            _avatarUrl = newValue
        }
    }

    public var isUseMsgReceiverAvatar: Bool = false
    public var showName: Bool = false
    public var showAvatar: Bool = true
    public var sameToNextMsgSender: Bool = false
    public var showCheckBox: Bool = false
    public var selected: Bool = false
    public var atUserList: [String] = []
    public var direction: TMsgDirection = .incoming
    public var status: TMsgStatus = .initStatus
    public var source: TMsgSource = .unknown
    public var innerMessage: V2TIMMessage?
    public var cellLayout: TUIMessageCellLayout?
    public var showReadReceipt: Bool = true
    public var showMessageTime: Bool = false
    public var showMessageModifyReplies: Bool = false
    public var highlightKeyword: String?
    public var messageReceipt: V2TIMMessageReceipt?
    public var messageModifyReplies: [[String: Any]]?
    public var messageContainerAppendSize: CGSize = .zero
    public var bottomContainerSize: CGSize = .zero
    public var topContainerSize: CGSize = .zero
    /// Extra top offset for container when nameLabel is too long and would overlap with topContainer
    public var topContainerInsetTop: CGFloat = 0
    public var placeHolder: TUIMessageCellData?
    @objc public dynamic var videoTranscodingProgress: CGFloat = 0.0
    public var additionalUserInfoResult: [String: TUIRelationUserModel] = [:]

    public init(direction: TMsgDirection) {
        self.direction = direction
        self.status = .initStatus
        self.source = .unknown
        self.showReadReceipt = true
        self.sameToNextMsgSender = false
        self.showAvatar = true
        self.cellLayout = TUIMessageCellData.cellLayout(direction: direction)
        self.additionalUserInfoResult = [:]
        super.init()
    }

    static func cellLayout(direction: TMsgDirection) -> TUIMessageCellLayout {
        if direction == .incoming {
            return TUIMessageCellLayout.incomingMessageLayout
        } else {
            return TUIMessageCellLayout.outgoingMessageLayout
        }
    }

    open func canForward() -> Bool {
        return true
    }

    open func canLongPress() -> Bool {
        return true
    }

    open func shouldHide() -> Bool {
        return false
    }

    open func customReloadCell(withNewMsg: V2TIMMessage) -> Bool {
        return false
    }

    public var msgStatusSize: CGSize {
        if let innerMessage = innerMessage, showReadReceipt && innerMessage.needReadReceipt &&
            (innerMessage.userID != nil || innerMessage.groupID != nil)
        {
            if direction == .outgoing {
                return CGSize(width: 54, height: 14)
            } else {
                return CGSize(width: 38, height: 14)
            }
        } else {
            // The community type does not require read receipt markers, only the time is needed.
            return CGSize(width: 26, height: 14)
        }
    }

    open func requestForAdditionalUserInfo() -> [String] {
        return []
    }
}

public protocol TUIMessageCellDataFileUploadProtocol {
    var uploadProgress: UInt { get set }
}

public protocol TUIMessageCellDataFileDownloadProtocol {
    var downloadProgress: UInt { get set }
    var isDownloading: Bool { get set }
}

open class TUIBubbleMessageCellData: TUIMessageCellData {}
