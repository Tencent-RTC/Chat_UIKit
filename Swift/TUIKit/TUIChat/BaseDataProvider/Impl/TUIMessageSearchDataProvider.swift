import Foundation
import ImSDK_Plus
import TIMCommon

typealias LoadSearchMsgSucceedBlock = (Bool, Bool, [TUIMessageCellData]) -> Void
typealias LoadMsgSucceedBlock = (Bool, Bool, Bool, [TUIMessageCellData]) -> Void

class TUIMessageSearchDataProvider: TUIMessageDataProvider {
    private var loadSearchMsgSucceedBlock: LoadSearchMsgSucceedBlock?
    private var loadMsgSucceedBlock: LoadMsgSucceedBlock?
    var isOlderNoMoreMsg = false
    var isNewerNoMoreMsg = false
    private var msgForOlderGet: V2TIMMessage?
    private var msgForNewerGet: V2TIMMessage?

    func loadMessageWithSearchMsg(searchMsg: V2TIMMessage?, searchSeq: UInt64, conversation: TUIChatConversationModel, succeedBlock: @escaping LoadSearchMsgSucceedBlock, failBlock: @escaping (Int, String) -> Void) {
        if isLoadingData {
            failBlock(Int(ERR_SUCC.rawValue), "refreshing")
            return
        }
        isLoadingData = true
        isOlderNoMoreMsg = false
        isNewerNoMoreMsg = false
        loadSearchMsgSucceedBlock = succeedBlock

        let group = DispatchGroup()
        var olders: [V2TIMMessage] = []
        var newers: [V2TIMMessage] = []
        var isOldLoadFail = false
        var isNewLoadFail = false
        var failCode = 0
        var failDesc: String?

        // Load the oldest pageCount messages starting from locating message
        group.enter()
        let oldOption = V2TIMMessageListGetOption()
        oldOption.getType = .GET_CLOUD_OLDER_MSG
        oldOption.count = UInt(pageCount)
        oldOption.groupID = conversation.groupID
        oldOption.userID = conversation.userID
        if let searchMsg = searchMsg {
            oldOption.lastMsg = searchMsg
        } else {
            oldOption.lastMsgSeq = UInt(searchSeq)
        }
        V2TIMManager.sharedInstance().getHistoryMessageList(option: oldOption, succ: { msgs in
            guard let msgs = msgs else { return }
            olders = msgs.reversed()
            if olders.count < self.pageCount {
                self.isOlderNoMoreMsg = true
            }
            group.leave()
        }, fail: { code, desc in
            isOldLoadFail = true
            failCode = Int(code)
            failDesc = desc
            group.leave()
        })

        // Load the latest pageCount messages starting from the locating message
        group.enter()
        let newOption = V2TIMMessageListGetOption()
        newOption.getType = .GET_CLOUD_NEWER_MSG
        newOption.count = UInt(pageCount)
        newOption.groupID = conversation.groupID
        newOption.userID = conversation.userID
        if let searchMsg = searchMsg {
            newOption.lastMsg = searchMsg
        } else {
            newOption.lastMsgSeq = UInt(searchSeq)
        }
        V2TIMManager.sharedInstance().getHistoryMessageList(option: newOption, succ: { msgs in
            guard let msgs = msgs else { return }
            newers = msgs
            if newers.count < self.pageCount {
                self.isNewerNoMoreMsg = true
            }
            group.leave()
        }, fail: { code, desc in
            isNewLoadFail = true
            failCode = Int(code)
            failDesc = desc
            group.leave()
        })

        group.notify(queue: .global(qos: .userInitiated)) {
            self.isLoadingData = false
            if isOldLoadFail || isNewLoadFail {
                DispatchQueue.main.async {
                    failBlock(failCode, failDesc ?? "")
                }
            }
            self.isFirstLoad = false

            var results: [V2TIMMessage] = []
            results.append(contentsOf: olders)
            if let searchMsg = searchMsg {
                results.append(searchMsg)
            } else if !results.isEmpty {
                results.removeLast()
            }
            results.append(contentsOf: newers)
            self.msgForOlderGet = results.first
            self.msgForNewerGet = results.last

            DispatchQueue.main.async {
                self.heightCache.removeAll()
                self.uiMsgs.removeAll()

                let msgs = Array(results.reversed())
                let uiMsgs = self.transUIMsgFromIMMsg(msgs)
                if uiMsgs.isEmpty {
                    return
                }
                self.getGroupMessageReceipts(msgs: msgs, uiMsgs: uiMsgs, succ: {
                    self.preProcessMessage(uiMsgs: uiMsgs)
                }, fail: {
                    self.preProcessMessage(uiMsgs: uiMsgs)
                })
            }
        }
    }

    func loadMessageWithIsRequestOlderMsg(orderType: Bool, conversation: TUIChatConversationModel, succeedBlock: @escaping LoadMsgSucceedBlock, failBlock: @escaping (Int, String) -> Void) {
        isLoadingData = true
        loadMsgSucceedBlock = succeedBlock

        let requestCount = pageCount
        let option = V2TIMMessageListGetOption()
        option.userID = conversation.userID
        option.groupID = conversation.groupID
        option.getType = orderType ? .GET_CLOUD_OLDER_MSG : .GET_CLOUD_NEWER_MSG
        option.count = UInt(requestCount)
        option.lastMsg = orderType ? msgForOlderGet : msgForNewerGet

        V2TIMManager.sharedInstance().getHistoryMessageList(option: option, succ: { msgs in
            guard var msgs = msgs else { return }
            if !orderType {
                msgs.reverse()
            }

            let isLastest = (self.msgForNewerGet == nil) && (self.msgForOlderGet == nil) && orderType
            if orderType {
                self.msgForOlderGet = msgs.last
                if self.msgForNewerGet == nil {
                    self.msgForNewerGet = msgs.first
                }
            } else {
                if self.msgForOlderGet == nil {
                    self.msgForOlderGet = msgs.last
                }
                self.msgForNewerGet = msgs.first
            }

            if msgs.count < requestCount {
                if orderType {
                    self.isOlderNoMoreMsg = true
                } else {
                    self.isNewerNoMoreMsg = true
                }
            }

            if isLastest {
                self.isNewerNoMoreMsg = true
            }

            var uiMsgs = self.transUIMsgFromIMMsg(msgs)
            if uiMsgs.isEmpty {
                self.loadMsgSucceedBlock?(self.isOlderNoMoreMsg, self.isNewerNoMoreMsg, self.isFirstLoad, uiMsgs)
                return
            }

            // Add media placeholder cell data
            if let conversationID = self.conversationModel?.conversationID, !conversationID.isEmpty {
                let tasks = TUIChatMediaSendingManager.shared.findPlaceHolderList(byConversationID: conversationID)
                for task in tasks {
                    if let placeHolderCellData = task.placeHolderCellData {
                        uiMsgs.append(placeHolderCellData)
                    }
                }
            }

            self.getGroupMessageReceipts(msgs: msgs, uiMsgs: uiMsgs, succ: {
                self.preProcessMessage(uiMsgs: uiMsgs, orderType: orderType)
            }, fail: {
                self.preProcessMessage(uiMsgs: uiMsgs, orderType: orderType)
            })
        }, fail: { _, _ in
            self.isLoadingData = false
        })
    }

    func getGroupMessageReceipts(msgs: [V2TIMMessage], uiMsgs: [TUIMessageCellData], succ: (() -> Void)?, fail: (() -> Void)?) {
        V2TIMManager.sharedInstance().getMessageReadReceipts(messageList: msgs, succ: { receiptList in
            guard let receiptList = receiptList else { return }
            print("getGroupMessageReceipts succeed, receiptList: \(String(describing: receiptList))")
            var dict: [String: V2TIMMessageReceipt] = [:]
            for receipt in receiptList {
                if let msgID = receipt.msgID {
                    dict[msgID] = receipt
                }
            }
            for data in uiMsgs {
                if let msgID = data.msgID, let receipt = dict[msgID] {
                    data.messageReceipt = receipt
                }
            }

            succ?()
        }, fail: { code, desc in
            print("getGroupMessageReceipts failed, code: \(code), desc: \(String(describing: desc))")
            fail?()
        })
    }

    func preProcessMessage(uiMsgs: [TUIMessageCellData]) {
        preProcessMessage(uiMsgs, callback: { [weak self] in
            guard let self else { return }
            self.addUIMsgs(uiMsgs)
            self.loadSearchMsgSucceedBlock?(self.isOlderNoMoreMsg, self.isNewerNoMoreMsg, self.uiMsgs)
        })
    }

    func preProcessMessage(uiMsgs: [TUIMessageCellData], orderType: Bool) {
        preProcessMessage(uiMsgs, callback: { [weak self] in
            guard let self else { return }
            if orderType {
                let indexSet = IndexSet(integersIn: 0 ..< uiMsgs.count)
                self.insertUIMsgs(uiMsgs, atIndexes: indexSet)
            } else {
                self.addUIMsgs(uiMsgs)
            }

            self.loadMsgSucceedBlock?(self.isOlderNoMoreMsg, self.isNewerNoMoreMsg, self.isFirstLoad, uiMsgs)

            self.isLoadingData = false
            self.isFirstLoad = false
        })
    }

    func removeAllSearchData() {
        uiMsgs.removeAll()
        isNewerNoMoreMsg = false
        isOlderNoMoreMsg = false
        isFirstLoad = true
        msgForNewerGet = nil
        msgForOlderGet = nil
        loadSearchMsgSucceedBlock = nil
    }

    func findMessages(msgIDs: [String], callback: ((Bool, String, [V2TIMMessage]?) -> Void)?) {
        V2TIMManager.sharedInstance().findMessages(messageIDList: msgIDs, succ: { msgs in
            guard let msgs = msgs else { return }
            callback?(true, "", msgs)
        }, fail: { _, desc in
            callback?(false, desc ?? "", nil)
        })
    }

    // MARK: - V2TIMAdvancedMsgListener

    override func onRecvNewMessage(msg: V2TIMMessage) {
        if !isNewerNoMoreMsg {
            return
        }
        if dataSource?.isDataSourceConsistent() == false {
            isNewerNoMoreMsg = false
            return
        }
        super.onRecvNewMessage(msg: msg)
    }
}
