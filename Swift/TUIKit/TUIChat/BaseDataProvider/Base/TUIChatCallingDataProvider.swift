import Foundation
import ImSDK_Plus
import TIMCommon
import TUICore

typealias TUIChatMessageID = String
typealias TUIChatCallingJsonData = [String: Any]

// 通话协议类型
enum TUICallProtocolType: Int {
    case unknown = 0
    case send = 1
    case accept = 2
    case reject = 3
    case cancel = 4
    case hangup = 5
    case timeout = 6
    case lineBusy = 7
    case switchToAudio = 8
    case switchToAudioConfirm = 9
}

// 通话流媒体类型
enum TUICallStreamMediaType: Int {
    case unknown = 0
    case voice = 1
    case video = 2
}

// 通话参与者类型
enum TUICallParticipantType: Int {
    case unknown = 0
    case c2c = 1
    case group = 2
}

// 参与者角色
enum TUICallParticipantRole: Int {
    case unknown = 0
    case caller = 1
    case callee = 2
}

// 语音视频通话消息方向
enum TUICallMessageDirection: Int {
    case incoming = 0
    case outgoing = 1
}

protocol TUIChatCallingInfoProtocol: NSObjectProtocol {
    // 语音视频通话的协议类型
    var protocolType: TUICallProtocolType { get }

    // 语音视频通话的流媒体类型
    var streamMediaType: TUICallStreamMediaType { get }

    // 语音视频通话的参与类型，支持一对一和群组
    var participantType: TUICallParticipantType { get }

    // 语音视频通话的参与角色类型，支持主叫和被叫
    var participantRole: TUICallParticipantRole { get }

    // 是否从聊天页面的历史记录中排除，支持 TUIChat 7.1 及以后版本
    var excludeFromHistory: Bool { get }

    // 语音视频通话消息的显示文本
    var content: String { get }

    // 语音视频通话消息的显示方向
    var direction: TUICallMessageDirection { get }

    // 是否在通话历史中显示未读点
    var showUnreadPoint: Bool { get }

    // 是否使用接收者的头像
    var isUseReceiverAvatar: Bool { get }

    var participantIDList: [String] { get }
}

// TUIChat 中语音视频通话消息的样式
enum TUIChatCallingMessageAppearance: Int {
    case details = 0
    case simplify = 1
}

protocol TUIChatCallingDataProtocol {
    // 设置 TUIChat 中语音视频通话消息的样式
    func setCallingMessageStyle(_ style: TUIChatCallingMessageAppearance)

    // 基于当前语音视频通话消息重拨（通常用于在聊天页面点击通话历史后重拨）
    func redialFromMessage(_ innerMessage: V2TIMMessage)

    // 解析语音视频通话消息
    func isCallingMessage(_ innerMessage: V2TIMMessage, callingInfo: inout TUIChatCallingInfoProtocol?) -> Bool
}

class TUIChatCallingInfo: NSObject, TUIChatCallingInfoProtocol {
    var msgID: TUIChatMessageID = ""
    var jsonData: TUIChatCallingJsonData?
    var signalingInfo: V2TIMSignalingInfo?
    var innerMessage: V2TIMMessage?
    var style: TUIChatCallingMessageAppearance?

    // MARK: - TUIChatCallingInfoProtocol

    var protocolType: TUICallProtocolType {
        guard let jsonData = jsonData, let signalingInfo = signalingInfo, let _ = innerMessage else {
            return .unknown
        }

        var type: TUICallProtocolType = .unknown

        switch signalingInfo.actionType {
        case .invite:
            if let data = jsonData["data"] as? [String: Any], let cmd = data["cmd"] as? String {
                switch cmd {
                case "switchToAudio":
                    type = .switchToAudio
                case "hangup":
                    type = .hangup
                case "videoCall", "audioCall":
                    type = .send
                default:
                    type = .unknown
                }
            } else if jsonData["call_end"] is NSNumber {
                type = .hangup
            } else {
                type = .send
            }
        case .cancel_Invite:
            type = .cancel
        case .accept_Invite:
            if let data = jsonData["data"] as? [String: Any], let cmd = data["cmd"] as? String {
                type = (cmd == "switchToAudio") ? .switchToAudioConfirm : .accept
            } else {
                type = .accept
            }
        case .reject_Invite:
            type = (jsonData["line_busy"] != nil) ? .lineBusy : .reject
        case .invite_Timeout:
            type = .timeout
        default:
            type = .unknown
        }
        return type
    }

    var streamMediaType: TUICallStreamMediaType {
        let protocolType = self.protocolType
        if protocolType == .unknown {
            return .unknown
        }

        var type: TUICallStreamMediaType = .unknown
        if let callType = jsonData?["call_type"] as? NSNumber {
            if callType.intValue == 1 {
                type = .voice
            } else if callType.intValue == 2 {
                type = .video
            }
        }

        if protocolType == .send, let data = jsonData?["data"] as? [String: Any], let cmd = data["cmd"] as? String {
            if cmd == "audioCall" {
                type = .voice
            } else if cmd == "videoCall" {
                type = .video
            }
        } else if protocolType == .switchToAudio || protocolType == .switchToAudioConfirm {
            type = .video
        }

        return type
    }

    var participantType: TUICallParticipantType {
        if protocolType == .unknown {
            return .unknown
        }

        return (signalingInfo?.groupID?.count ?? 0 > 0) ? .group : .c2c
    }

    var participantRole: TUICallParticipantRole {
        return (caller() == TUILogin.getUserID()) ? .caller : .callee
    }

    var excludeFromHistory: Bool {
        if style == .simplify {
            return protocolType != .unknown && innerMessage?.isExcludedFromLastMessage == true && innerMessage?.isExcludedFromUnreadCount == true
        } else {
            return false
        }
    }

    var content: String {
        return (style == .simplify) ? contentForSimplifyAppearance() : contentForDetailsAppearance()
    }

    var direction: TUICallMessageDirection {
        return (style == .simplify) ? directionForSimplifyAppearance() : directionForDetailsAppearance()
    }

    var showUnreadPoint: Bool {
        if excludeFromHistory {
            return false
        }
        return (innerMessage?.localCustomInt == 0) && (participantRole == .callee) && (participantType == .c2c) &&
            (protocolType == .cancel || protocolType == .timeout || protocolType == .lineBusy)
    }

    var isUseReceiverAvatar: Bool {
        return (style == .simplify) ? isUseReceiverAvatarForSimplifyAppearance() : isUseReceiverAvatarForDetailsAppearance()
    }

    var participantIDList: [String] {
        var arrayM: [String] = []
        if let inviter = signalingInfo?.inviter {
            arrayM.append(inviter)
        }
        if let inviteeList = signalingInfo?.inviteeList as? [String] {
            arrayM.append(contentsOf: inviteeList)
        }
        return arrayM
    }

    func caller() -> String {
        var callerID: String? = nil
        if let data = jsonData?["data"] as? [String: Any], let inviter = data["inviter"] as? String {
            callerID = inviter
        }
        return callerID ?? TUILogin.getUserID()!
    }

    // MARK: - Details style

    func contentForDetailsAppearance() -> String {
        let protocolType = self.protocolType
        let isGroup = (participantType == .group)

        if protocolType == .unknown {
            return TUISwift.timCommonLocalizableString("TUIkitSignalingUnrecognlize")
        }

        var display = TUISwift.timCommonLocalizableString("TUIkitSignalingUnrecognlize")
        let showName = TUIMessageBaseDataProvider.getShowName(innerMessage)

        switch protocolType {
        case .send:
            display = isGroup ? String(format: TUISwift.timCommonLocalizableString("TUIKitSignalingNewGroupCallFormat"), showName)
                : TUISwift.timCommonLocalizableString("TUIKitSignalingNewCall")
        case .accept:
            display = isGroup ? String(format: TUISwift.timCommonLocalizableString("TUIKitSignalingHangonCallFormat"), showName)
                : TUISwift.timCommonLocalizableString("TUIkitSignalingHangonCall")
        case .reject:
            display = isGroup ? String(format: TUISwift.timCommonLocalizableString("TUIKitSignalingDeclineFormat"), showName)
                : TUISwift.timCommonLocalizableString("TUIkitSignalingDecline")
        case .cancel:
            display = isGroup ? String(format: TUISwift.timCommonLocalizableString("TUIkitSignalingCancelGroupCallFormat"), showName)
                : TUISwift.timCommonLocalizableString("TUIkitSignalingCancelCall")
        case .hangup:
            let duration = (jsonData?["call_end"] as? NSNumber)?.uintValue ?? 0
            display = isGroup
                ? TUISwift.timCommonLocalizableString("TUIKitSignalingFinishGroupChat")
                : String(format: "%@:%02d:%02d", TUISwift.timCommonLocalizableString("TUIKitSignalingFinishConversationAndTimeFormat"), duration / 60, duration % 60)
        case .timeout:
            var mutableContent = ""
            if isGroup {
                for invitee in signalingInfo?.inviteeList ?? [] {
                    mutableContent.append("\"\(invitee)\"、")
                }
                if !mutableContent.isEmpty {
                    mutableContent.removeLast()
                }
            }
            mutableContent.append(TUISwift.timCommonLocalizableString("TUIKitSignalingNoResponse"))
            display = mutableContent
        case .lineBusy:
            display = isGroup ? String(format: TUISwift.timCommonLocalizableString("TUIKitSignalingBusyFormat"), showName)
                : TUISwift.timCommonLocalizableString("TUIKitSignalingCallBusy")
        case .switchToAudio:
            display = TUISwift.timCommonLocalizableString("TUIKitSignalingSwitchToAudio")
        case .switchToAudioConfirm:
            display = TUISwift.timCommonLocalizableString("TUIKitSignalingComfirmSwitchToAudio")
        default:
            break
        }

        return rtlString(display)
    }

    func directionForDetailsAppearance() -> TUICallMessageDirection {
        return (innerMessage?.isSelf == true) ? .outgoing : .incoming
    }

    func isUseReceiverAvatarForDetailsAppearance() -> Bool {
        return false
    }

    // MARK: - Simplify style

    func contentForSimplifyAppearance() -> String {
        if excludeFromHistory {
            return ""
        }

        let participantType = self.participantType
        let protocolType = self.protocolType
        let isCaller = (participantRole == .caller)

        var display: String? = nil
        let showName = TUIMessageBaseDataProvider.getShowName(innerMessage)

        if participantType == .c2c {
            switch protocolType {
            case .reject:
                display = isCaller ? TUISwift.tuiChatLocalizableString("TUIChatCallRejectInCaller") : TUISwift.tuiChatLocalizableString("TUIChatCallRejectInCallee")
            case .cancel:
                display = isCaller ? TUISwift.tuiChatLocalizableString("TUIChatCallCancelInCaller") : TUISwift.tuiChatLocalizableString("TUIChatCallCancelInCallee")
            case .hangup:
                let duration = (jsonData?["call_end"] as? NSNumber)?.intValue ?? 0
                display = String(format: "%@:%02d:%02d", TUISwift.tuiChatLocalizableString("TUIChatCallDurationFormat"), duration / 60, duration % 60)
            case .timeout:
                display = isCaller ? TUISwift.tuiChatLocalizableString("TUIChatCallTimeoutInCaller") : TUISwift.tuiChatLocalizableString("TUIChatCallTimeoutInCallee")
            case .lineBusy:
                display = isCaller ? TUISwift.tuiChatLocalizableString("TUIChatCallLinebusyInCaller") : TUISwift.tuiChatLocalizableString("TUIChatCallLinebusyInCallee")
            case .send:
                display = TUISwift.tuiChatLocalizableString("TUIChatCallSend")
            case .accept:
                display = TUISwift.tuiChatLocalizableString("TUIChatCallAccept")
            case .switchToAudio:
                display = TUISwift.tuiChatLocalizableString("TUIChatCallSwitchToAudio")
            case .switchToAudioConfirm:
                display = TUISwift.tuiChatLocalizableString("TUIChatCallConfirmSwitchToAudio")
            default:
                display = TUISwift.tuiChatLocalizableString("TUIChatCallUnrecognized")
            }
        } else if participantType == .group {
            switch protocolType {
            case .send:
                display = String(format: TUISwift.tuiChatLocalizableString("TUIChatGroupCallSendFormat"), showName)
            case .cancel, .hangup:
                display = TUISwift.tuiChatLocalizableString("TUIChatGroupCallEnd")
            case .timeout, .lineBusy:
                var mutableContent = ""
                for invitee in signalingInfo?.inviteeList ?? [] {
                    mutableContent.append("\"\(invitee)\"、")
                }
                if !mutableContent.isEmpty {
                    mutableContent.removeLast()
                }
                mutableContent.append(TUISwift.tuiChatLocalizableString("TUIChatGroupCallNoAnswer"))
                display = mutableContent
            case .reject:
                display = String(format: TUISwift.tuiChatLocalizableString("TUIChatGroupCallRejectFormat"), showName)
            case .accept:
                display = String(format: TUISwift.tuiChatLocalizableString("TUIChatGroupCallAcceptFormat"), showName)
            case .switchToAudio:
                display = String(format: TUISwift.tuiChatLocalizableString("TUIChatGroupCallSwitchToAudioFormat"), showName)
            case .switchToAudioConfirm:
                display = String(format: TUISwift.tuiChatLocalizableString("TUIChatGroupCallConfirmSwitchToAudioFormat"), showName)
            default:
                display = TUISwift.tuiChatLocalizableString("TUIChatCallUnrecognized")
            }
        } else {
            display = TUISwift.tuiChatLocalizableString("TUIChatCallUnrecognized")
        }
        return rtlString(display ?? "")
    }

    func directionForSimplifyAppearance() -> TUICallMessageDirection {
        return (participantRole == .caller) ? .outgoing : .incoming
    }

    func isUseReceiverAvatarForSimplifyAppearance() -> Bool {
        return (direction == .outgoing) ? !(innerMessage?.isSelf ?? false) : (innerMessage?.isSelf ?? false)
    }

    // MARK: - Utils

    func convertProtocolTypeToString(_ type: TUICallProtocolType) -> String {
        let dict: [TUICallProtocolType: String] = [
            .send: "TUICallProtocolTypeSend",
            .accept: "TUICallProtocolTypeAccept",
            .reject: "TUICallProtocolTypeReject",
            .cancel: "TUICallProtocolTypeCancel",
            .hangup: "TUICallProtocolTypeHangup",
            .timeout: "TUICallProtocolTypeTimeout",
            .lineBusy: "TUICallProtocolTypeLineBusy",
            .switchToAudio: "TUICallProtocolTypeSwitchToAudio",
            .switchToAudioConfirm: "TUICallProtocolTypeSwitchToAudioConfirm"
        ]
        return dict[type] ?? "unknown"
    }
}

class TUIChatCallingDataProvider: NSObject, TUIChatCallingDataProtocol {
    var style: TUIChatCallingMessageAppearance
    var callingCache: NSCache<AnyObject, AnyObject>

    override init() {
        self.style = .simplify
        self.callingCache = NSCache<AnyObject, AnyObject>()
    }

    func setCallingMessageStyle(_ style: TUIChatCallingMessageAppearance) {
        self.style = style
    }

    func redialFromMessage(_ innerMessage: V2TIMMessage) {
        guard let userID = innerMessage.userID else { return }
        var param: [String: Any]?
        var callingInfo: TUIChatCallingInfoProtocol?
        if isCallingMessage(innerMessage, callingInfo: &callingInfo) {
            if callingInfo?.streamMediaType == .voice {
                param = [
                    "TUICore_TUICallingService_ShowCallingViewMethod_UserIDsKey": [userID],
                    "TUICore_TUICallingService_ShowCallingViewMethod_CallTypeKey": "0"
                ]
            } else if callingInfo?.streamMediaType == .video {
                param = [
                    "TUICore_TUICallingService_ShowCallingViewMethod_UserIDsKey": [userID],
                    "TUICore_TUICallingService_ShowCallingViewMethod_CallTypeKey": "1"
                ]
            }
            if let param = param {
                TUICore.callService("TUICore_TUICallingService", method: "TUICore_TUICallingService_ShowCallingViewMethod", param: param)
            }
        }
    }

    func isCallingMessage(_ innerMessage: V2TIMMessage, callingInfo: inout TUIChatCallingInfoProtocol?) -> Bool {
        if let item = callingInfoForMesssage(innerMessage) {
            callingInfo = item
            return true
        } else {
            callingInfo = nil
            return false
        }
    }

    func callingInfoForMesssage(_ innerMessage: V2TIMMessage) -> TUIChatCallingInfo? {
        let msgID = innerMessage.msgID
        if let item = callingCache.object(forKey: msgID as AnyObject) as? TUIChatCallingInfo {
            item.innerMessage = innerMessage
            return item
        }

        guard let info = V2TIMManager.sharedInstance().getSignallingInfo(msg: innerMessage), let data = info.data?.data(using: .utf8) else {
            return nil
        }

        guard let param = try? JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? [String: Any],
              let businessID = param["businessID"] as? String,
              businessID == "av_call" || businessID == "rtc_call"
        else {
            return nil
        }

        let item = TUIChatCallingInfo()
        item.style = style
        item.signalingInfo = info
        item.jsonData = param
        item.innerMessage = innerMessage
        callingCache.setObject(item as AnyObject, forKey: msgID as AnyObject)
        return item
    }
}
