import TIMCommon
import TUICore
import UIKit

class TUIMessageController_Minimalist: TUIBaseMessageController_Minimalist, TUIChatSmallTongueViewDelegate_Minimalist {
    var bottomIndicatorView: UIActivityIndicatorView?
    var locateGroupMessageSeq: UInt64 = 0
    var tongueView: TUIChatSmallTongueView_Minimalist?
    lazy var receiveMsgs: [TUIMessageCellData] = .init()
    weak var backgroudView: UIImageView?
    var highlightKeyword: String?
    var locateMessage: V2TIMMessage?
    var C2CIncomingLastMsg: V2TIMMessage?

    var messageSearchDataProvider: TUIMessageSearchDataProvider? {
        return messageDataProvider as? TUIMessageSearchDataProvider
    }

    override var conversationData: TUIChatConversationModel? {
        didSet {
            messageDataProvider = TUIMessageSearchDataProvider(conversationModel: conversationData ?? TUIChatConversationModel())
            messageDataProvider?.dataSource = self
            messageDataProvider?.mergeAdjacentMsgsFromTheSameSender = true
            if locateMessage != nil {
                loadAndScrollToLocateMessages(scrollToBoom: false, isHighlight: true)
            } else {
                messageSearchDataProvider?.removeAllSearchData()
                loadMessages(order: true)
            }
            loadGroupInfo()
        }
    }

    // MARK: Life Cycle

    override init(style: UITableView.Style = .plain) {
        super.init(style: style)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        bottomIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: Int(tableView.frame.size.width), height: Int(TMessageController_Header_Height)))
        bottomIndicatorView?.style = .medium
        tableView.tableFooterView = bottomIndicatorView
        tableView.backgroundColor = .clear

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)

        DispatchQueue.main.async {
            if let atMsgSeqs = self.conversationData?.atMsgSeqs, atMsgSeqs.count > 0 {
                let tongue = TUIChatSmallTongue_Minimalist()
                tongue.type = .someoneAt
                tongue.parentView = self.view.superview
                tongue.atMsgSeqs = atMsgSeqs
                TUIChatSmallTongueManager_Minimalist.showTongue(tongue, delegate: self)
            }
        }
    }

    deinit {
        TUIChatSmallTongueManager_Minimalist.removeTongue()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        TUIChatSmallTongueManager_Minimalist.hideTongue(false)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        TUIChatSmallTongueManager_Minimalist.hideTongue(true)
    }

    // MARK: Notification

    @objc func keyboardWillShow() {
        if !(messageSearchDataProvider?.isNewerNoMoreMsg ?? false) {
            messageSearchDataProvider?.removeAllSearchData()
            tableView.reloadData()
            loadMessages(order: true)
        }
    }

    // MARK: Override

    override func willShowMediaMessage(_ cell: TUIMessageCell) {
        TUIChatSmallTongueManager_Minimalist.hideTongue(true)
    }

    override func didCloseMediaMessage(_ cell: TUIMessageCell) {
        TUIChatSmallTongueManager_Minimalist.hideTongue(false)
    }

    override func onDeleteMessage(_ cell: TUIMessageCell) {
        guard let cellData = cell.messageData else { return }
        let vc = UIAlertController(title: nil, message: TUISwift.timCommonLocalizableString("ConfirmDeleteMessage"), preferredStyle: .actionSheet)
        vc.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Delete"), style: .destructive, handler: { [weak self] _ in
            guard let self else { return }
            self.messageDataProvider?.deleteUIMsgs([cellData], SuccBlock: {
                self.updateAtMeTongue(cellData)
            }, FailBlock: { _, desc in
                assertionFailure(desc ?? "")
            })
        }))
        vc.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(vc, animated: true, completion: nil)
    }

    func updateAtMeTongue(_ deleteCellData: TUIMessageCellData) {
        guard let conversationData = conversationData else { return }
        if let deleteSeq = deleteCellData.innerMessage?.seq,
           var atMsgSeqs = conversationData.atMsgSeqs, atMsgSeqs.contains(Int(deleteSeq))
        {
            atMsgSeqs.removeAll { $0 == Int(deleteSeq) }
            if atMsgSeqs.count > 0 {
                let tongue = TUIChatSmallTongue_Minimalist()
                tongue.type = .someoneAt
                tongue.parentView = view.superview
                tongue.atMsgSeqs = atMsgSeqs
                TUIChatSmallTongueManager_Minimalist.showTongue(tongue, delegate: self)
            } else {
                TUIChatSmallTongueManager_Minimalist.removeTongue(type: .someoneAt)
            }
        }
    }

    // UIScrollViewDelegate
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        if scrollView.contentOffset.y <= CGFloat(TMessageController_Header_Height) && !(messageSearchDataProvider?.isOlderNoMoreMsg ?? false) {
            if !(indicatorView?.isAnimating ?? false) {
                indicatorView?.startAnimating()
            }
        } else if isScrollToBottomIndicatorViewY(scrollView) {
            if !(messageSearchDataProvider?.isNewerNoMoreMsg ?? false) && !(bottomIndicatorView?.isAnimating ?? false) {
                bottomIndicatorView?.startAnimating()
            }
            if isInVC {
                TUIChatSmallTongueManager_Minimalist.removeTongue(type: .scrollToBoom)
                TUIChatSmallTongueManager_Minimalist.removeTongue(type: .receiveNewMsg)
            }
        } else if isInVC && receiveMsgs.count == 0 && tableView.contentSize.height - tableView.contentOffset.y >= TUISwift.screen_Height() * 2.0 {
            let point = scrollView.panGestureRecognizer.translation(in: scrollView)
            if point.y > 0 {
                let tongue = TUIChatSmallTongue_Minimalist()
                tongue.type = .scrollToBoom
                tongue.parentView = view.superview
                TUIChatSmallTongueManager_Minimalist.showTongue(tongue, delegate: self)
            }
        } else if isInVC && tableView.contentSize.height - tableView.contentOffset.y >= 20 {
            TUIChatSmallTongueManager_Minimalist.removeTongue(type: .someoneAt)
        } else {
            if !(indicatorView?.isAnimating ?? false) {
                indicatorView?.stopAnimating()
            }
            if !(bottomIndicatorView?.isAnimating ?? false) {
                bottomIndicatorView?.stopAnimating()
            }
        }
    }

    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        super.scrollViewDidEndDecelerating(scrollView)
        if scrollView.contentOffset.y <= CGFloat(TMessageController_Header_Height) && !(messageSearchDataProvider?.isOlderNoMoreMsg ?? false) {
            loadMessages(order: true)
        } else if isScrollToBottomIndicatorViewY(scrollView) && !(messageSearchDataProvider?.isNewerNoMoreMsg ?? false) {
            loadMessages(order: false)
        }
    }

    func isScrollToBottomIndicatorViewY(_ scrollView: UIScrollView) -> Bool {
        return scrollView.contentOffset.y + tableView.frame.size.height + 2 > scrollView.contentSize.height - (indicatorView?.frame.size.height ?? 0)
    }

    // MARK: Private Methods

    func loadAndScrollToLocateMessages(scrollToBoom: Bool, isHighlight: Bool) {
        if locateMessage == nil && locateGroupMessageSeq == 0 {
            return
        }
        guard let messageSearchDataProvider = messageSearchDataProvider, let conversationData = conversationData else { return }
        messageSearchDataProvider.loadMessageWithSearchMsg(searchMsg: locateMessage, searchSeq: locateGroupMessageSeq, conversation: conversationData, succeedBlock: { [weak self] _, _, _ in
            guard let self else { return }
            self.indicatorView?.stopAnimating()
            self.bottomIndicatorView?.stopAnimating()
            self.indicatorView?.frame.size.height = 0
            self.bottomIndicatorView?.frame.size.height = 0
            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()

            DispatchQueue.main.async {
                self.scrollToLocateMessage(scrollToBoom)
                if isHighlight {
                    self.fillCellHighlightKeyword()
                }
            }
        }, failBlock: { _, _ in })
    }

    func scrollToLocateMessage(_ scrollToBoom: Bool) {
        guard let uiMsgs = messageSearchDataProvider?.uiMsgs else { return }
        var offsetY = CGFloat(0)
        var index = 0
        for uiMsg in uiMsgs {
            if isLocateMessage(uiMsg) {
                break
            }
            offsetY += getHeightFromMessageCellData(uiMsg)
            index += 1
        }

        if index == uiMsgs.count {
            return
        }

        offsetY -= tableView.frame.size.height / 2.0
        if offsetY <= CGFloat(TMessageController_Header_Height) {
            offsetY = CGFloat(TMessageController_Header_Height) + 0.1
        }

        if offsetY > CGFloat(TMessageController_Header_Height) {
            tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .middle, animated: true)
        }
    }

    func fillCellHighlightKeyword() {
        guard let uiMsgs = messageSearchDataProvider?.uiMsgs else { return }
        guard let cellData = uiMsgs.first(where: { isLocateMessage($0) }) else { return }
        if cellData.innerMessage?.elemType == V2TIMElemType.ELEM_TYPE_GROUP_TIPS {
            return
        }

        DispatchQueue.main.async {
            var indexPath = IndexPath(row: uiMsgs.firstIndex(of: cellData)!, section: 0)
            cellData.highlightKeyword = (self.highlightKeyword?.isEmpty ?? true) ? "hightlight" : self.highlightKeyword
            if let cell = self.tableView.cellForRow(at: indexPath) as? TUIMessageCell {
                cell.fill(with: cellData)
                cell.layoutSubviews()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                indexPath = IndexPath(row: uiMsgs.firstIndex(of: cellData)!, section: 0)
                cellData.highlightKeyword = nil
                if let cell = self.tableView.cellForRow(at: indexPath) as? TUIMessageCell {
                    cell.fill(with: cellData)
                    cell.layoutSubviews()
                }
            }
        }
    }

    func isLocateMessage(_ uiMsg: TUIMessageCellData) -> Bool {
        if let locateMessage = locateMessage {
            if uiMsg.innerMessage?.msgID == locateMessage.msgID {
                return true
            }
        } else {
            if let groupID = conversationData?.groupID, !groupID.isEmpty,
               let seq = uiMsg.innerMessage?.seq, seq == locateGroupMessageSeq
            {
                return true
            }
        }
        return false
    }

    func loadMessages(order: Bool) {
        guard let dataProvider = messageSearchDataProvider, let conversationData = conversationData, !dataProvider.isLoadingData else { return }
        if order && dataProvider.isOlderNoMoreMsg {
            indicatorView?.stopAnimating()
            return
        }
        if !order && dataProvider.isNewerNoMoreMsg {
            bottomIndicatorView?.stopAnimating()
            return
        }

        dataProvider.loadMessageWithIsRequestOlderMsg(orderType: order, conversation: conversationData, succeedBlock: { [weak self] isOlderNoMoreMsg, isNewerNoMoreMsg, isFirstLoad, newUIMsgs in
            guard let self else { return }
            self.indicatorView?.stopAnimating()
            self.bottomIndicatorView?.stopAnimating()
            self.indicatorView?.frame.size.height = isOlderNoMoreMsg ? 0 : CGFloat(TMessageController_Header_Height)
            self.bottomIndicatorView?.frame.size.height = isNewerNoMoreMsg ? 0 : CGFloat(TMessageController_Header_Height)

            self.tableView.reloadData()
            self.tableView.layoutIfNeeded()

            for (_, obj) in newUIMsgs.enumerated().reversed() {
                if obj.direction == .incoming {
                    self.C2CIncomingLastMsg = obj.innerMessage
                    break
                }
            }

            if isFirstLoad {
                self.scrollToBottom(false)
                self.restoreAITypingMessageIfNeeded()
            } else {
                if order {
                    let index = newUIMsgs.count > 0 ? newUIMsgs.count - 1 : 0
                    if dataProvider.uiMsgs.count > 0 {
                        self.tableView.scrollToRow(at: IndexPath(row: index, section: 0), at: .top, animated: false)
                    }
                }
            }
        }, failBlock: { _, _ in })
    }

    override func showReplyMessage<T: TUIBubbleMessageCell_Minimalist>(_ cell: T) {
        var originMsgID = ""
        var msgAbstract = ""
        if let replyCell = cell as? TUIReplyMessageCell_Minimalist {
            let cellData = replyCell.replyData
            originMsgID = cellData?.messageRootID ?? ""
            msgAbstract = cellData?.msgAbstract ?? ""
        } else if let referenceCell = cell as? TUIReferenceMessageCell_Minimalist {
            let cellData = referenceCell.referenceData
            originMsgID = cellData?.originMsgID ?? ""
            msgAbstract = cellData?.msgAbstract ?? ""
        }

        guard let dataProvider = messageDataProvider as? TUIMessageSearchDataProvider else { return }
        dataProvider.findMessages(msgIDs: [originMsgID]) { [weak self] success, _, msgs in
            guard let self = self else { return }

            if !success {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitReplyMessageNotFoundOriginMessage"))
                return
            }

            guard let message = msgs?.first else {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitReplyMessageNotFoundOriginMessage"))
                return
            }

            if message.status == .MSG_STATUS_HAS_DELETED || message.status == .MSG_STATUS_LOCAL_REVOKED {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitReplyMessageNotFoundOriginMessage"))
                return
            }

            if cell is TUIReplyMessageCell_Minimalist {
                self.jumpDetailPageByMessage(message)
            } else if cell is TUIReferenceMessageCell_Minimalist {
                self.locateAssignMessage(message, matchKeyWord: msgAbstract)
            }
        }
    }

    func jumpDetailPageByMessage(_ message: V2TIMMessage) {
        guard let uiMsgs = messageDataProvider?.transUIMsgFromIMMsg([message]), uiMsgs.count > 0 else {
            return
        }
        messageDataProvider?.preProcessMessage(uiMsgs) { [weak self] in
            guard let self else { return }
            for cellData in uiMsgs {
                if cellData.innerMessage?.msgID == message.msgID {
                    self.onJumpToRepliesDetailPage(cellData)
                    return
                }
            }
        }
    }

    func locateAssignMessage(_ message: V2TIMMessage?, matchKeyWord: String) {
        guard let message = message else { return }
        locateMessage = message
        highlightKeyword = matchKeyWord

        let memoryExist = messageDataProvider?.uiMsgs.contains(where: { $0.innerMessage?.msgID == message.msgID }) ?? false
        if memoryExist {
            scrollToLocateMessage(false)
            fillCellHighlightKeyword()
            return
        }

        let provider = messageDataProvider as? TUIMessageSearchDataProvider
        provider?.isNewerNoMoreMsg = false
        provider?.isOlderNoMoreMsg = false
        loadAndScrollToLocateMessages(scrollToBoom: false, isHighlight: true)
    }

    func findMessages(_ msgIDs: [String], callback: ((Bool, String, [V2TIMMessage]?) -> Void)?) {
        (messageDataProvider as? TUIMessageSearchDataProvider)?.findMessages(msgIDs: msgIDs, callback: callback)
    }

    // MARK: - TUIMessageBaseDataProviderDataSource

    override func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, receiveNewUIMsg uiMsg: TUIMessageCellData) {
        super.dataProvider(dataProvider, receiveNewUIMsg: uiMsg)
        if isInVC && tableView.contentSize.height - tableView.contentOffset.y >= TUISwift.screen_Height() * 2.0 {
            receiveMsgs.append(uiMsg)
            let tongue = TUIChatSmallTongue_Minimalist()
            tongue.type = .receiveNewMsg
            tongue.parentView = view.superview
            tongue.unreadMsgCount = receiveMsgs.count
            TUIChatSmallTongueManager_Minimalist.showTongue(tongue, delegate: self)
        }

        if isInVC {
            C2CIncomingLastMsg = uiMsg.innerMessage
        }
    }

    override func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, receiveRevokeUIMsg uiMsg: TUIMessageCellData) {
        super.dataProvider(dataProvider, receiveRevokeUIMsg: uiMsg)
        if receiveMsgs.contains(uiMsg) {
            if let index = receiveMsgs.firstIndex(of: uiMsg) {
                receiveMsgs.remove(at: index)
            }
            let tongue = TUIChatSmallTongue_Minimalist()
            tongue.type = .receiveNewMsg
            tongue.parentView = view.superview
            tongue.unreadMsgCount = receiveMsgs.count
            if tongue.unreadMsgCount != 0 {
                TUIChatSmallTongueManager_Minimalist.showTongue(tongue, delegate: self)
            } else {
                TUIChatSmallTongueManager_Minimalist.removeTongue(type: .receiveNewMsg)
            }
        }

        if let uiMsg = uiMsg as? TUIReplyMessageCellData,
           let messageRootID = uiMsg.messageRootID
        {
            let revokeMsgID = uiMsg.msgID
            (messageDataProvider as? TUIMessageSearchDataProvider)?.findMessages(msgIDs: [messageRootID], callback: { [weak self] success, _, msgs in
                guard self != nil else { return }

                if success, let message = msgs?.first {
                    TUIChatModifyMessageHelper.shared.modifyMessage(message, revokeMsgID: revokeMsgID)
                }
            })
        }

        for cellData in messageDataProvider?.uiMsgs ?? [] {
            if let replyMessageData = cellData as? TUIReplyMessageCellData, replyMessageData.originMessage?.msgID == uiMsg.msgID {
                messageDataProvider?.processQuoteMessage([replyMessageData])
            }
        }
    }

    // MARK: - TUIChatSmallTongueViewDelegate

    func onChatSmallTongueClick(_ tongue: TUIChatSmallTongue_Minimalist) {
        switch tongue.type {
        case .scrollToBoom:
            messageDataProvider?.getLastMessage(true, succ: { [weak self] message in
                guard let self = self else { return }
                self.locateMessage = message
                for cellData in self.messageDataProvider?.uiMsgs ?? [] {
                    if self.isLocateMessage(cellData) {
                        self.scrollToLocateMessage(true)
                        return
                    }
                }
                self.loadAndScrollToLocateMessages(scrollToBoom: true, isHighlight: false)
            }, fail: { _, _ in })
        case .receiveNewMsg:
            TUIChatSmallTongueManager_Minimalist.removeTongue(type: .receiveNewMsg)
            if let cellData = receiveMsgs.first {
                locateMessage = cellData.innerMessage
                scrollToLocateMessage(true)
                fillCellHighlightKeyword()
            }
            receiveMsgs.removeAll()
        case .someoneAt:
            TUIChatSmallTongueManager_Minimalist.removeTongue(type: .someoneAt)
            conversationData?.atMsgSeqs?.removeAll()
            locateGroupMessageSeq = UInt64(tongue.atMsgSeqs.first ?? 0)
            for cellData in messageDataProvider?.uiMsgs ?? [] {
                if isLocateMessage(cellData) {
                    scrollToLocateMessage(true)
                    fillCellHighlightKeyword()
                    return
                }
            }
            loadAndScrollToLocateMessages(scrollToBoom: true, isHighlight: true)
        default:
            break
        }
    }
}
