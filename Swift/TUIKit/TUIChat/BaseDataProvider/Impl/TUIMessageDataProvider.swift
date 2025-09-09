import AVFoundation
import Foundation
import TIMCommon
import TUICore

let MaxReEditMessageDelay: Double = 2 * 60

protocol TUIMessageDataProviderDataSource: TUIMessageBaseDataProviderDataSource {
    static func onGetCustomMessageCellDataClass(businessID: String) -> TUIMessageCellDataDelegate.Type?
}

extension TUIMessageDataProviderDataSource {
    static func onGetCustomMessageCellDataClass(businessID: String) -> TUIMessageCellDataDelegate.Type? { return nil }
}

class TUIMessageDataProvider: TUIMessageBaseDataProvider {
    static var gDataSourceClass: TUIMessageDataProviderDataSource.Type? = nil

    deinit {
        TUIMessageDataProvider.gCallingDataProvider = nil
    }

    static func setDataSourceClass(_ dataSourceClass: TUIMessageDataProviderDataSource.Type) {
        gDataSourceClass = dataSourceClass
    }

    override class func convertToCellData(from message: V2TIMMessage) -> TUIMessageCellData? {
        var data = parseMessageCellDataFromMessageStatus(message)
        if data == nil {
            data = parseMessageCellDataFromMessageCustomData(message)
        }
        if data == nil {
            data = parseMessageCellDataFromMessageElement(message)
        }

        if let data = data {
            fillPropertyToCellData(data, ofMessage: message)
        } else {
            print("current message will be ignored in chat page, msg:\(message)")
        }

        return data
    }

    static func parseMessageCellDataFromMessageStatus(_ message: V2TIMMessage) -> TUIMessageCellData? {
        var data: TUIMessageCellData? = nil
        if message.status == .MSG_STATUS_LOCAL_REVOKED {
            data = getRevokeCellData(message)
        }
        return data
    }

    static func parseMessageCellDataFromMessageCustomData(_ message: V2TIMMessage) -> TUIMessageCellData? {
        var data: TUIMessageCellData? = nil
        if message.isContainsCloudCustom(of: .messageReply) {
            data = TUIReplyMessageCellData.getCellData(message: message)
        } else if message.isContainsCloudCustom(of: .messageReference) {
            data = TUIReferenceMessageCellData.getCellData(message: message)
        }
        return data
    }

    static func parseMessageCellDataFromMessageElement(_ message: V2TIMMessage) -> TUIMessageCellData? {
        var data: TUIMessageCellData? = nil
        switch message.elemType {
        case .ELEM_TYPE_TEXT:
            data = TUITextMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_IMAGE:
            data = TUIImageMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_SOUND:
            data = TUIVoiceMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_VIDEO:
            data = TUIVideoMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_FILE:
            data = TUIFileMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_FACE:
            data = TUIFaceMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_GROUP_TIPS:
            data = getSystemCellData(message)
        case .ELEM_TYPE_MERGER:
            data = TUIMergeMessageCellData.getCellData(message: message)
        case .ELEM_TYPE_CUSTOM:
            data = getCustomMessageCellData(message)
        default:
            data = getUnsupportedCellData(message)
        }
        return data
    }

    static func fillPropertyToCellData(_ data: TUIMessageCellData, ofMessage message: V2TIMMessage) {
        data.innerMessage = message
        if let groupID = message.groupID, !message.isSelf && !(data is TUISystemMessageCellData) {
            data.showName = true
        }
        switch message.status {
        case .MSG_STATUS_SEND_SUCC:
            data.status = .success
        case .MSG_STATUS_SEND_FAIL:
            data.status = .fail
        case .MSG_STATUS_SENDING:
            data.status = .sending
        default:
            break
        }

        if let msgID = message.msgID, !msgID.isEmpty {
            let uploadProgress = TUIMessageProgressManager.shared.uploadProgress(forMessage: msgID)
            let downloadProgress = TUIMessageProgressManager.shared.downloadProgress(forMessage: msgID)
            if var data = data as? TUIMessageCellDataFileUploadProtocol {
                data.uploadProgress = UInt(uploadProgress)
            }
            if var data = data as? TUIMessageCellDataFileDownloadProtocol {
                data.downloadProgress = UInt(downloadProgress)
                data.isDownloading = (downloadProgress != 0) && (downloadProgress != 100)
            }
        }

        if message.isContainsCloudCustom(of: .messageReplies) {
            message.doThingsInContainsCloudCustom(of: .messageReplies) { isContains, obj in
                if isContains {
                    if data is TUISystemMessageCellData || data is TUIJoinGroupMessageCellData {
                        data.showMessageModifyReplies = false
                    } else {
                        data.showMessageModifyReplies = true
                    }
                    if let dic = obj as? [String: Any] {
                        let typeStr = TUICloudCustomDataTypeCenter.convertType2String(.messageReplies) ?? ""
                        if let messageReplies = dic[typeStr] as? [String: Any],
                           let repliesArr = messageReplies["replies"] as? [[String: Any]]
                        {
                            data.messageModifyReplies = repliesArr
                        }
                    }
                }
            }
        }
    }

    static func getCustomMessageCellData(_ message: V2TIMMessage) -> TUIMessageCellData? {
        var data: TUIMessageCellData? = nil
        var callingInfo: TUIChatCallingInfoProtocol? = nil
        if callingDataProvider.isCallingMessage(message, callingInfo: &callingInfo) {
            if let callingInfo = callingInfo {
                if callingInfo.excludeFromHistory {
                    data = nil
                } else {
                    data = getCallingCellData(callingInfo)
                    if data == nil {
                        data = getUnsupportedCellData(message)
                    }
                }
            } else {
                data = getUnsupportedCellData(message)
            }
            return data
        }

        var businessID: String? = nil
        var excludeFromHistory = false

        if let signalingInfo = V2TIMManager.sharedInstance().getSignallingInfo(msg: message) {
            excludeFromHistory = message.isExcludedFromLastMessage && message.isExcludedFromUnreadCount
            businessID = getSignalingBusinessID(signalingInfo)
        } else {
            excludeFromHistory = false
            businessID = getCustomBusinessID(message)
        }

        if excludeFromHistory {
            return nil
        }

        if let businessID = businessID, !businessID.isEmpty {
            if let gDataSourceClass = gDataSourceClass,
               let cellDataClass = gDataSourceClass.onGetCustomMessageCellDataClass(businessID: businessID)
            {
                let data = cellDataClass.getCellData(message: message)
                if data.shouldHide() {
                    return nil
                } else {
                    data.reuseId = businessID
                    return data
                }
            }
            if businessID.contains("customerServicePlugin") {
                return nil
            }
            if businessID.contains("IgnoreMessage") {
                return nil
            }
            return getUnsupportedCellData(message)
        } else {
            return getUnsupportedCellData(message)
        }
    }

    static func getUnsupportedCellData(_ message: V2TIMMessage) -> TUIMessageCellData {
        let cellData = TUITextMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        cellData.content = TUISwift.timCommonLocalizableString("TUIKitNotSupportThisMessage")
        cellData.reuseId = "TTextMessageCell"
        return cellData
    }

    static func getSystemCellData(_ message: V2TIMMessage) -> TUISystemMessageCellData? {
        guard let tip = message.groupTipsElem else { return nil }
        var opUserName = ""
        var opUserID = ""
        if let opMember = tip.opMember {
            opUserName = getOpUserName(opMember)
            opUserID = opMember.userID ?? ""
        }
        var userNameList = [String]()
        var userIDList = [String]()
        if let memberList = tip.memberList {
            userNameList = getUserNameList(memberList)
            userIDList = getUserIDList(memberList)
        }
        if tip.type == .GROUP_TIPS_TYPE_JOIN ||
            tip.type == .GROUP_TIPS_TYPE_INVITE ||
            tip.type == .GROUP_TIPS_TYPE_KICKED ||
            tip.type == .GROUP_TIPS_TYPE_GROUP_INFO_CHANGE ||
            tip.type == .GROUP_TIPS_TYPE_QUIT ||
            tip.type == .GROUP_TIPS_TYPE_PINNED_MESSAGE_ADDED ||
            tip.type == .GROUP_TIPS_TYPE_PINNED_MESSAGE_DELETED
        {
            let joinGroupData = TUIJoinGroupMessageCellData(direction: .incoming)
            joinGroupData.content = getDisplayString(message: message) ?? ""
            joinGroupData.opUserName = opUserName
            joinGroupData.opUserID = opUserID
            joinGroupData.userNameList = userNameList
            joinGroupData.userIDList = userIDList
            joinGroupData.reuseId = "TJoinGroupMessageCell"
            return joinGroupData
        } else {
            let sysdata = TUISystemMessageCellData(direction: .incoming)
            sysdata.content = getDisplayString(message: message) ?? ""
            sysdata.reuseId = "TSystemMessageCell"
            if !(sysdata.content?.isEmpty ?? true) {
                return sysdata
            }
        }
        return nil
    }

    override class func getRevokeCellData(_ message: V2TIMMessage) -> TUISystemMessageCellData? {
        let revoke = TUISystemMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        revoke.reuseId = "TSystemMessageCell"
        revoke.content = getRevokeDispayString(message)
        revoke.innerMessage = message
        let revokerInfo = message.revokerInfo
        if message.isSelf {
            if message.elemType == .ELEM_TYPE_TEXT && abs(Date().timeIntervalSince(message.timestamp ?? Date())) < MaxReEditMessageDelay {
                if let revokerInfo = revokerInfo, revokerInfo.userID != message.sender {
                    revoke.supportReEdit = false
                } else {
                    revoke.supportReEdit = true
                }
            }
        } else if let groupID = message.groupID, !groupID.isEmpty {
            let userName = TUIMessageDataProvider.getShowName(message)
            let joinGroupData = TUIJoinGroupMessageCellData(direction: .incoming)
            joinGroupData.content = getRevokeDispayString(message)
            joinGroupData.opUserID = message.sender
            joinGroupData.opUserName = userName
            joinGroupData.reuseId = "TJoinGroupMessageCell"
            return joinGroupData
        }
        return revoke
    }

    override class func getSystemMsgFromDate(_ date: Date) -> TUIMessageCellData? {
        let system = TUISystemMessageCellData(direction: .outgoing)
        system.content = TUITool.convertDate(toStr: date)
        system.reuseId = "TSystemMessageCell"
        system.type = TUISystemMessageType.date
        return system
    }

    static func asyncGetDisplayString(_ messageList: [V2TIMMessage], callback: (([String: String]) -> Void)?) {
        guard let callback = callback else { return }

        var originDisplayMap = [String: String]()
        var cellDataList = [TUIMessageCellData]()
        for message in messageList {
            if let cellData = convertToCellData(from: message) {
                cellDataList.append(cellData)
            }

            let displayString = getDisplayString(message: message)
            if let msgID = message.msgID {
                originDisplayMap[msgID] = displayString
            }
        }

        if cellDataList.isEmpty {
            callback([:])
            return
        }

        let provider = TUIMessageDataProvider()
        let additionUserIDList = provider.getUserIDListForAdditionalUserInfo(cellDataList)
        if additionUserIDList.isEmpty {
            callback([:])
            return
        }

        var result = [String: String]()
        provider.requestForAdditionalUserInfo(cellDataList) {
            for cellData in cellDataList {
                for (key, obj) in cellData.additionalUserInfoResult {
                    let str = "{\(key)}"
                    var showName = ""
                    if let nameCard = obj.nameCard, !nameCard.isEmpty {
                        showName = nameCard
                    } else if let friendMark = obj.friendRemark, !friendMark.isEmpty {
                        showName = friendMark
                    } else if let nickName = obj.nickName, !nickName.isEmpty {
                        showName = nickName
                    } else if !obj.userID.isEmpty {
                        showName = obj.userID
                    }

                    if let msgID = cellData.msgID,
                       var displayString = originDisplayMap[msgID], displayString.contains(str)
                    {
                        displayString = displayString.replacingOccurrences(of: str, with: showName)
                        result[msgID] = displayString
                    }

                    callback(result)
                }
            }
        }
    }

    override public class func getDisplayString(message: V2TIMMessage) -> String? {
        let hasRiskContent = message.hasRiskContent
        let isRevoked = (message.status == .MSG_STATUS_LOCAL_REVOKED)
        if hasRiskContent && !isRevoked {
            return TUISwift.timCommonLocalizableString("TUIKitMessageDisplayRiskContent")
        }
        var str = parseDisplayStringFromMessageStatus(message)
        if str == nil {
            str = parseDisplayStringFromMessageElement(message)
        }

        if str == nil {
            print("current message will be ignored in chat page or conversation list page, msg:\(message)")
        }
        return str
    }

    static func parseDisplayStringFromMessageStatus(_ message: V2TIMMessage) -> String? {
        var str: String? = nil
        if message.status == .MSG_STATUS_LOCAL_REVOKED {
            str = getRevokeDispayString(message)
        }
        return str
    }

    static func parseDisplayStringFromMessageElement(_ message: V2TIMMessage) -> String? {
        var str: String? = nil
        switch message.elemType {
        case .ELEM_TYPE_TEXT:
            str = TUITextMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_IMAGE:
            str = TUIImageMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_SOUND:
            str = TUIVoiceMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_VIDEO:
            str = TUIVideoMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_FILE:
            str = TUIFileMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_FACE:
            str = TUIFaceMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_MERGER:
            str = TUIMergeMessageCellData.getDisplayString(message: message)
        case .ELEM_TYPE_GROUP_TIPS:
            str = getGroupTipsDisplayString(message)
        case .ELEM_TYPE_CUSTOM:
            str = getCustomDisplayString(message)
        default:
            str = TUISwift.timCommonLocalizableString("TUIKitMessageTipsUnsupportCustomMessage")
        }
        return str
    }

    static func getCustomDisplayString(_ message: V2TIMMessage) -> String? {
        var str: String? = nil
        var callingInfo: TUIChatCallingInfoProtocol? = nil
        if callingDataProvider.isCallingMessage(message, callingInfo: &callingInfo) {
            if let callingInfo = callingInfo {
                if callingInfo.excludeFromHistory {
                    str = nil
                } else {
                    let content: String? = callingInfo.content
                    str = content ?? TUISwift.timCommonLocalizableString("TUIKitMessageTipsUnsupportCustomMessage")
                }
            } else {
                str = TUISwift.timCommonLocalizableString("TUIKitMessageTipsUnsupportCustomMessage")
            }
            return str
        }

        var businessID: String? = nil
        var excludeFromHistory = false

        if let signalingInfo = V2TIMManager.sharedInstance().getSignallingInfo(msg: message) {
            excludeFromHistory = message.isExcludedFromLastMessage && message.isExcludedFromUnreadCount
            businessID = getSignalingBusinessID(signalingInfo)
        } else {
            excludeFromHistory = false
            businessID = getCustomBusinessID(message)
        }

        if excludeFromHistory {
            return nil
        }

        if let businessID = businessID, !businessID.isEmpty {
            if let gDataSourceClass = gDataSourceClass,
               let cellDataClass = gDataSourceClass.onGetCustomMessageCellDataClass(businessID: businessID)
            {
                let data = cellDataClass.getDisplayString(message: message)
                return data
            }
            if businessID.contains("customerServicePlugin") {
                return nil
            }
            if businessID.contains("IgnoreMessage") {
                return nil
            }
            return TUISwift.timCommonLocalizableString("TUIKitMessageTipsUnsupportCustomMessage")
        } else {
            return TUISwift.timCommonLocalizableString("TUIKitMessageTipsUnsupportCustomMessage")
        }
    }

    override func processQuoteMessage(_ uiMsgs: [TUIMessageCellData]) {
        if uiMsgs.isEmpty {
            return
        }

        let concurrentQueue = DispatchQueue.global(qos: .default)
        let group = DispatchGroup()

        concurrentQueue.async(group: group) {
            for cellData in uiMsgs {
                guard let myData = cellData as? TUIReplyMessageCellData else { continue }

                myData.onFinish = {
                    DispatchQueue.main.async {
                        if let index = self.uiMsgs.firstIndex(of: myData) {
                            UIView.performWithoutAnimation {
                                self.dataSource?.dataProviderDataSourceWillChange(self)
                                self.dataSource?.dataProviderDataSourceChange(self, withType: .reload, atIndex: UInt(index), animation: false)
                                self.dataSource?.dataProviderDataSourceDidChange(self)
                            }
                        }
                    }
                }
                group.enter()
                self.loadOriginMessage(from: myData) {
                    group.leave()
                    DispatchQueue.main.async {
                        if let index = self.uiMsgs.firstIndex(of: myData) {
                            UIView.performWithoutAnimation {
                                self.dataSource?.dataProviderDataSourceWillChange(self)
                                self.dataSource?.dataProvider(self, onRemoveHeightCache: myData)
                                self.dataSource?.dataProviderDataSourceChange(self, withType: .reload, atIndex: UInt(index), animation: false)
                                self.dataSource?.dataProviderDataSourceDidChange(self)
                            }
                        }
                    }
                }
            }
        }

        group.notify(queue: DispatchQueue.main) {
            // complete
        }
    }

    override func deleteUIMsgs(_ uiMsgArray: [TUIMessageCellData], SuccBlock succ: V2TIMSucc?, FailBlock fail: V2TIMFail?) {
        var uiMsgList = [TUIMessageCellData]()
        var imMsgList = [V2TIMMessage]()
        for uiMsg in uiMsgArray {
            if uiMsgs.contains(uiMsg) {
                uiMsgList.append(uiMsg)
                if let msg = uiMsg.innerMessage {
                    imMsgList.append(msg)
                }

                var index = uiMsgs.firstIndex(of: uiMsg)!
                index -= 1
                if index >= 0 && index < uiMsgs.count, let systemCellData = uiMsgs[index] as? TUISystemMessageCellData, systemCellData.type == .date {
                    uiMsgList.append(systemCellData)
                }
            }
        }

        if imMsgList.count == 0 {
            fail?(Int32(ERR_INVALID_PARAMETERS.rawValue), "not found uiMsgs")
            return
        }

        TUIMessageDataProvider.deleteMessages(imMsgList, succ: {
            self.dataSource?.dataProviderDataSourceWillChange(self)
            for uiMsg in uiMsgList {
                if let index = self.uiMsgs.firstIndex(of: uiMsg) {
                    self.dataSource?.dataProviderDataSourceChange(self, withType: .delete, atIndex: UInt(index), animation: true)
                }
            }
            self.removeUIMsgList(uiMsgList)
            self.dataSource?.dataProviderDataSourceDidChange(self)
            succ?()
        }, fail: fail)
    }

    override func removeUIMsgList(_ cellDatas: [TUIMessageCellData]) {
        for uiMsg in cellDatas {
            removeUIMsg(uiMsg)
        }
    }

    static func getCustomBusinessID(_ message: V2TIMMessage) -> String? {
        guard let customElem = message.customElem else { return nil }
        guard let data = customElem.data else { return nil }
        do {
            if let param = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                if let businessID = param["businessID"] as? String, !businessID.isEmpty {
                    return businessID
                } else if param.keys.contains("customerServicePlugin"), let src = param["src"] as? String, !src.isEmpty {
                    return "\("customerServicePlugin")\(src)"
                } else if param.keys.contains("chatbotPlugin") {
                    // Handle chatbot plugin messages
                    if let srcValue = param["src"] as? Double, srcValue == 22 {
                        return "IgnoreMessage"
                    }
                    return "chatbotPlugin"
                }
            }
        } catch {
            print("parse customElem data error: \(error)")
        }
        return nil
    }

    static func getSignalingBusinessID(_ signalInfo: V2TIMSignalingInfo) -> String? {
        guard let data = signalInfo.data else { return nil }
        do {
            if let param = try JSONSerialization.jsonObject(with: data.data(using: .utf8)!, options: .allowFragments) as? [String: Any], let businessID = param["businessID"] as? String {
                return businessID
            }
        } catch {
            print("parse customElem data error: \(error)")
        }
        return nil
    }

    static var gCallingDataProvider: TUIChatCallingDataProvider?
    static var callingDataProvider: TUIChatCallingDataProvider {
        if gCallingDataProvider == nil {
            gCallingDataProvider = TUIChatCallingDataProvider()
        }
        return gCallingDataProvider!
    }

    static func getCallingCellData(_ callingInfo: TUIChatCallingInfoProtocol) -> TUIMessageCellData? {
        let direction: TMsgDirection = callingInfo.direction == TUICallMessageDirection.incoming ? .incoming : .outgoing

        if callingInfo.participantType == .c2c {
            let cellData = TUITextMessageCellData(direction: direction)
            cellData.isAudioCall = callingInfo.streamMediaType == .voice
            cellData.isVideoCall = callingInfo.streamMediaType == .video
            cellData.content = callingInfo.content
            cellData.isCaller = callingInfo.participantRole == .caller
            cellData.showUnreadPoint = callingInfo.showUnreadPoint
            cellData.isUseMsgReceiverAvatar = callingInfo.isUseReceiverAvatar
            cellData.reuseId = "TTextMessageCell"
            return cellData
        } else if callingInfo.participantType == .group {
            let cellData = TUISystemMessageCellData(direction: direction)
            cellData.content = callingInfo.content
            cellData.replacedUserIDList = callingInfo.participantIDList
            cellData.reuseId = "TSystemMessageCell"
            return cellData
        } else {
            return nil
        }
    }
}
