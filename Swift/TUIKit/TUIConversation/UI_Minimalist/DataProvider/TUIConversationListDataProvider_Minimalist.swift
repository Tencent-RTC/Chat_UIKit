import Foundation
import TIMCommon
import TUICore

class TUIConversationListDataProvider_Minimalist: TUIConversationListBaseDataProvider {
    var lastMessageDisplayMap: [String: String]?

    override func getConversationCellClass() -> AnyClass {
        return TUIConversationCellData_Minimalist.self
    }

    override func asnycGetLastMessageDisplay(_ duplicateDataList: [TUIConversationCellData], addedDataList: [TUIConversationCellData]) {
        var allConversationList = [TUIConversationCellData]()
        allConversationList.append(contentsOf: duplicateDataList)
        allConversationList.append(contentsOf: addedDataList)

        var messageList = [V2TIMMessage]()
        for cellData in allConversationList {
            if let lastMessage = cellData.lastMessage, let _ = lastMessage.msgID {
                messageList.append(lastMessage)
            }
        }

        guard !messageList.isEmpty else {
            return
        }

        let param: [String: Any] = [TUICore_TUIChatService_AsyncGetDisplayStringMethod_MsgListKey: messageList]
        TUICore.callService(TUICore_TUIChatService_Minimalist, method: TUICore_TUIChatService_AsyncGetDisplayStringMethod, param: param) { [weak self] errorCode, _, param in
            guard let self = self else { return }
            guard errorCode == 0 else { return }

            // cache
            var dictM = self.lastMessageDisplayMap ?? [:]
            for (key, value) in param {
                if let msgID = key as? String, let displayString = value as? String {
                    dictM[msgID] = displayString
                }
            }
            self.lastMessageDisplayMap = dictM

            // Refresh if needed
            var needRefreshConvList = [TUIConversationCellData]()
            for cellData in allConversationList {
                if let lastMessage = cellData.lastMessage, let innerConversation = cellData.innerConversation, let msgID = lastMessage.msgID, param.contains(where: { $0.key as? String == msgID }) {
                    cellData.subTitle = self.getLastDisplayString(innerConversation)
                    cellData.foldSubTitle = self.getLastDisplayStringForFoldList(innerConversation)
                    needRefreshConvList.append(cellData)
                }
            }
            var conversationMap = [String: Int]()
            for item in self.conversationList {
                if let conversationID = item.conversationID {
                    conversationMap[conversationID] = self.conversationList.firstIndex(of: item) ?? -1
                }
            }
            self.handleUpdateConversationList(needRefreshConvList, positions: conversationMap)
        }
    }

    override func getDisplayStringFromService(_ msg: V2TIMMessage) -> String {
        guard let msgID = msg.msgID else { return "" }
        // from cache
        if let displayString = self.lastMessageDisplayMap?[msgID] {
            return displayString
        }

        // from TUIChat
        let param: [String: Any] = [TUICore_TUIChatService_GetDisplayStringMethod_MsgKey: msg]
        if let result = TUICore.callService(TUICore_TUIChatService_Minimalist, method: TUICore_TUIChatService_GetDisplayStringMethod, param: param) as? String {
            return result
        }
        return ""
    }

    override func getLastDisplayString(_ conv: V2TIMConversation) -> NSMutableAttributedString {
        /**
         * If has group-at message, the group-at information will be displayed first
         */
        let atStr = getGroupAtTipString(conv)
        let attributeString = NSMutableAttributedString(string: atStr)
        let attributeDict: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.d_systemRed()]
        attributeString.setAttributes(attributeDict, range: NSRange(location: 0, length: attributeString.length))

        /**
         * If there is a draft box, the draft box information will be displayed first
         */
        if !conv.draftText.isNilOrEmpty {
            let draft = NSAttributedString(string: TUISwift.timCommonLocalizableString("TUIKitMessageTypeDraftFormat"), attributes: [.foregroundColor: TUISwift.rgb(250, green: 81, blue: 81)!])
            attributeString.append(draft)

            let draftContentStr = getDraftContent(conv)
            if let draftContentStr = draftContentStr {
                let draftContent = NSAttributedString(string: draftContentStr.getLocalizableStringWithFaceContent(), attributes: [.foregroundColor: UIColor.d_systemGray()])
                attributeString.append(draftContent)
            }
        } else {
            /**
             * No drafts, show conversation lastMsg information
             */
            var lastMsgStr = ""

            /**
             * Attempt to get externally customized display information
             */
            if let delegate = delegate, delegate.responds(to: #selector(TUIConversationListDataProviderDelegate.getConversationDisplayString(_:))) {
                lastMsgStr = delegate.getConversationDisplayString!(conv) ?? ""
            }

            /**
             * If there is no external customization, get the lastMsg display information through the message module
             */
            if lastMsgStr.isEmpty, let lastMessage = conv.lastMessage {
                lastMsgStr = self.getDisplayStringFromService(lastMessage)
            }

            /**
             * If there is no lastMsg display information and no draft information, return nil directly
             */
            if lastMsgStr.isEmpty {
                return NSMutableAttributedString()
            }
            attributeString.append(NSAttributedString(string: lastMsgStr))
        }

        /**
         *
         * If do-not-disturb is set, the message do-not-disturb state is displayed
         * The default state of the meeting type group is V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE, and the UI does not process it.
         */
        if isConversationNotDisturb(conv) && conv.unreadCount > 0 {
            let unreadString = NSAttributedString(string: String(format: "[%d %@] ", conv.unreadCount, TUISwift.timCommonLocalizableString("TUIKitMessageTypeLastMsgCountFormat")))
            attributeString.insert(unreadString, at: 0)
        }

        return attributeString
    }
}