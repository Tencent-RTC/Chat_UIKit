import TIMCommon
import TUICore
import UIKit

class TUIMergeMessageListController_Minimalist: UITableViewController, TUIMessageCellDelegate, TUIMessageBaseDataProviderDataSource, TUINotificationProtocol {
    weak var delegate: TUIBaseMessageControllerDelegate_Minimalist?
    var mergerElem: V2TIMMergerElem?
    var willCloseCallback: (() -> Void)?
    var conversationData: TUIChatConversationModel?
    var parentPageDataProvider: TUIMessageDataProvider?
    
    private var imMsgs: [V2TIMMessage]? = []
    private var uiMsgs: [TUIMessageCellData]? = []

    lazy var stylesCache: [AnyHashable: Any] = [:]

    lazy var msgDataProvider: TUIMessageSearchDataProvider = {
        let provider = TUIMessageSearchDataProvider()
        provider.dataSource = self
        return provider
    }()

    lazy var messageCellConfig: TUIMessageCellConfig_Minimalist = .init()
    
    // MARK: - Life cycle

    override init(style: UITableView.Style = .plain) {
        super.init(style: style)
        TUICore.registerEvent("TUICore_TUIPluginNotify",
                              subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey",
                              object: self)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        uiMsgs = []
        loadMessages()
        setupViews()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        willCloseCallback?()
    }
    
    // MARK: - Setup views and data

    private func loadMessages() {
        mergerElem?.downloadMergerMessage { [weak self] msgs in
            guard let self = self else { return }
            self.imMsgs = msgs
            self.getMessages(msgs)
        } fail: { _, _ in }
    }
    
    private func getMessages(_ msgs: [V2TIMMessage]?) {
        guard let msgs = msgs else { return }
        let uiMsgs = transUIMsgFromIMMsg(msgs)
        msgDataProvider.preProcessMessage(uiMsgs) { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if !uiMsgs.isEmpty {
                    self.uiMsgs?.insert(contentsOf: uiMsgs, at: 0)
                    msgDataProvider.uiMsgs = uiMsgs
                    self.tableView.reloadData()
                    self.tableView.layoutIfNeeded()
                }
            }
        }
    }
    
    private func transUIMsgFromIMMsg(_ msgs: [V2TIMMessage]) -> [TUIMessageCellData] {
        var uiMsgs: [TUIMessageCellData] = []
        for msg in msgs {
            if let data = delegate?.onNewMessage(nil, message: msg) {
                var layout = TUIMessageCellLayout.incomingMessageLayout
                if data.isKind(of: TUITextMessageCellData.self) || data.isKind(of: TUIReferenceMessageCellData.self) {
                    layout = TUIMessageCellLayout.incomingTextMessageLayout
                } else if data.isKind(of: TUIVoiceMessageCellData.self) {
                    layout = TUIMessageCellLayout.incomingVoiceMessageLayout
                }
                data.cellLayout = layout
                data.direction = .incoming
                data.innerMessage = msg
                uiMsgs.append(data)
                continue
            }
            
            if let data = TUIMessageDataProvider.convertToCellData(from: msg) {
                var layout = TUIMessageCellLayout.incomingMessageLayout
                if data.isKind(of: TUITextMessageCellData.self) {
                    layout = TUIMessageCellLayout.incomingTextMessageLayout
                } else if data.isKind(of: TUIReplyMessageCellData.self) || data.isKind(of: TUIReferenceMessageCellData.self) {
                    layout = TUIMessageCellLayout.incomingTextMessageLayout
                    if let textData = data as? TUIReferenceMessageCellData {
                        textData.textColor = TUISwift.tuiChatDynamicColor("chat_text_message_receive_text_color", defaultColor: "#000000")
                        textData.showRevokedOriginMessage = true
                    }
                } else if data.isKind(of: TUIVoiceMessageCellData.self) {
                    if let voiceData = data as? TUIVoiceMessageCellData {
                        voiceData.cellLayout = TUIMessageCellLayout.incomingVoiceMessageLayout
                        voiceData.voiceTop = 10
                        msg.localCustomInt = 1
                    }
                    layout = TUIMessageCellLayout.incomingVoiceMessageLayout
                }
                data.cellLayout = layout
                data.direction = .incoming
                data.innerMessage = msg
                data.showName = false
                uiMsgs.append(data)
            }
        }
        for cellData in uiMsgs {
            TUIMessageDataProvider.updateUIMsgStatus(cellData, uiMsgArray: uiMsgs)
        }
        return uiMsgs
    }
    
    private func setupViews() {
        title = TUISwift.timCommonLocalizableString("TUIKitRelayChatHistory")
        tableView.scrollsToTop = false
        tableView.estimatedRowHeight = 0
        tableView.separatorStyle = .none
        tableView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_controller_bg_color", defaultColor: "#FFFFFF")
        tableView.contentInset = UIEdgeInsets(top: 5, left: 0, bottom: 0, right: 0)
        messageCellConfig.bindTableView(tableView)
        
        var image = TUISwift.timCommonDynamicImage("nav_back_img", defaultImage: UIImage.safeImage(TUISwift.timCommonImagePath("nav_back")))
        image = image.withRenderingMode(.alwaysOriginal)
        image = image.rtlImageFlippedForRightToLeftLayoutDirection()
        let backButton = UIButton(type: .custom)
        backButton.setImage(image, for: .normal)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
    }
    
    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uiMsgs?.count ?? 0
    }
    
    static var screenWidth: CGFloat = 0
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if TUIMergeMessageListController_Minimalist.screenWidth == 0 {
            TUIMergeMessageListController_Minimalist.screenWidth = TUISwift.screen_Width()
        }
        guard let uiMsgs = uiMsgs else { return 0 }
        if indexPath.row < uiMsgs.count {
            let cellData = uiMsgs[indexPath.row]
            let height = messageCellConfig.getHeightFromMessageCellData(cellData)
            return height
        } else {
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let uiMsgs = uiMsgs, indexPath.row < uiMsgs.count else { return UITableViewCell() }
        let data = uiMsgs[indexPath.row]
        data.showCheckBox = false
        if let cell = delegate?.onShowMessageData(nil, data: data) {
            cell.delegate = self
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: data.reuseId, for: indexPath) as? TUIMessageCell ?? TUIMessageCell()
        cell.delegate = self
        cell.fill(with: uiMsgs[indexPath.row])
        return cell
    }
    
    // MARK: - TUIMessageCellDelegate

    func onSelectMessage(_ cell: TUIMessageCell) {
        if let data = cell.messageData, let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onMessageClicked(cell, messageCellData: data), result == true {
            return
        }
        
        switch cell {
        case let imageCell as TUIImageMessageCell_Minimalist:
            showImageMessage(imageCell)
        case let voiceCell as TUIVoiceMessageCell_Minimalist:
            playVoiceMessage(voiceCell)
        case let videoCell as TUIVideoMessageCell_Minimalist:
            showVideoMessage(videoCell)
        case let fileCell as TUIFileMessageCell_Minimalist:
            showFileMessage(fileCell)
        case let mergeCell as TUIMergeMessageCell_Minimalist:
            let mergeVc = TUIMergeMessageListController_Minimalist()
            mergeVc.mergerElem = mergeCell.mergeData?.mergerElem
            mergeVc.delegate = delegate
            mergeVc.conversationData = conversationData
            navigationController?.pushViewController(mergeVc, animated: true)
        case let linkCell as TUILinkCell_Minimalist:
            showLinkMessage(linkCell)
        case let replyCell as TUIReplyMessageCell_Minimalist:
            showReplyMessage(replyCell)
        case let referenceCell as TUIReferenceMessageCell_Minimalist:
            showReplyMessage(referenceCell)
        default:
            break
        }
        delegate?.onSelectMessageContent(nil, cell: cell)
    }
    
    func onJumpToRepliesDetailPage(_ data: TUIMessageCellData) {
    }
    
    func scrollToLocateMessage(_ locateMessage: V2TIMMessage, matchKeyword msgAbstract: String) {
        guard let uiMsgs = uiMsgs else { return }
        var offsetY: CGFloat = 0
        var index = 0
        for uiMsg in uiMsgs {
            if uiMsg.innerMessage?.msgID == locateMessage.msgID {
                break
            }
            offsetY += uiMsg.height(ofWidth: TUISwift.screen_Width())
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
        
        highlightKeyword(msgAbstract, locateMessage: locateMessage)
    }
    
    private func highlightKeyword(_ keyword: String, locateMessage: V2TIMMessage) {
        guard let cellData = uiMsgs?.first(where: { $0.msgID == locateMessage.msgID }) else { return }
        
        var time: TimeInterval = 0.5
        if cellData.isKind(of: TUITextMessageCellData.self) {
            time = 2
        }
        
        DispatchQueue.main.async {
            let indexPath = IndexPath(row: self.uiMsgs?.firstIndex(of: cellData) ?? 0, section: 0)
            cellData.highlightKeyword = keyword
            if let cell = self.tableView.cellForRow(at: indexPath) as? TUIMessageCell {
                cell.fill(with: cellData)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            let indexPath = IndexPath(row: self.uiMsgs?.firstIndex(of: cellData) ?? 0, section: 0)
            cellData.highlightKeyword = nil
            if let cell = self.tableView.cellForRow(at: indexPath) as? TUIMessageCell {
                cell.fill(with: cellData)
            }
        }
    }
    
    private func showReplyMessage<T: TUIBubbleMessageCell_Minimalist>(_ cell: T) {
        TUITool.applicationKeywindow()?.endEditing(true)

        var originMsgID = ""
        var msgAbstract = ""

        if let replyCell = cell as? TUIReplyMessageCell_Minimalist, let cellData = replyCell.replyData {
            originMsgID = cellData.originMsgID ?? ""
            msgAbstract = cellData.msgAbstract ?? ""
        } else if let referenceCell = cell as? TUIReferenceMessageCell_Minimalist, let cellData = referenceCell.referenceData {
            originMsgID = cellData.originMsgID ?? ""
            msgAbstract = cellData.msgAbstract ?? ""
        }

        guard !originMsgID.isEmpty else {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitReplyMessageNotFoundOriginMessage"))
            return
        }

        msgDataProvider.findMessages(msgIDs: [originMsgID], callback: { [weak self] success, _, msgs in
            guard let self else { return }
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

            let existed = checkIfMessageExistsInLocal(message)
            if !existed {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitReplyMessageNotFoundOriginMessage"))
                return
            }
            self.scrollToLocateMessage(message, matchKeyword: msgAbstract)
        })
    }
    
    private func checkIfMessageExistsInLocal(_ locateMessage: V2TIMMessage) -> Bool {
        guard let uiMsgs = uiMsgs else { return false }
        for uiMsg in uiMsgs {
            if uiMsg.innerMessage?.msgID == locateMessage.msgID {
                return true
            }
        }
        return false
    }
    
    private func showImageMessage(_ cell: TUIImageMessageCell_Minimalist) {
        guard let msg = cell.messageData?.innerMessage else { return }
        let frame = cell.thumb.convert(cell.thumb.bounds, to: TUITool.applicationKeywindow())
        let mediaView = TUIMediaView_Minimalist(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
        mediaView.setThumb(cell.thumb, frame: frame)
        mediaView.setCurMessage(msg, allMessages: imMsgs ?? [])
        TUITool.applicationKeywindow()?.addSubview(mediaView)
    }
    
    private func playVoiceMessage(_ cell: TUIVoiceMessageCell_Minimalist) {
        guard let uiMsgs = uiMsgs else { return }
        for index in 0..<uiMsgs.count {
            if !uiMsgs[index].isKind(of: TUIVoiceMessageCellData.self) {
                continue
            }
            if let uiMsg = uiMsgs[index] as? TUIVoiceMessageCellData {
                if uiMsg == cell.voiceData {
                    uiMsg.playVoiceMessage()
                    cell.voiceReadPoint.isHidden = true
                } else {
                    uiMsg.stopVoiceMessage()
                }
            }
        }
    }
    
    private func showVideoMessage(_ cell: TUIVideoMessageCell_Minimalist) {
        guard let msg = cell.messageData?.innerMessage else { return }
        let frame = cell.thumb.convert(cell.thumb.bounds, to: TUITool.applicationKeywindow())
        let mediaView = TUIMediaView_Minimalist(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
        mediaView.setThumb(cell.thumb, frame: frame)
        mediaView.setCurMessage(msg, allMessages: imMsgs ?? [])
        TUITool.applicationKeywindow()?.addSubview(mediaView)
    }
    
    private func showFileMessage(_ cell: TUIFileMessageCell_Minimalist) {
        let fileData = cell.fileData
        if !(fileData?.isLocalExist() ?? false) {
            fileData?.downloadFile()
            return
        }
        
        let fileVC = TUIFileViewController_Minimalist()
        fileVC.data = cell.fileData
        navigationController?.pushViewController(fileVC, animated: true)
    }
    
    private func showLinkMessage(_ cell: TUILinkCell_Minimalist?) {
        if let link = cell?.customData?.link {
            UIApplication.shared.open(URL(string: link) ?? URL(fileURLWithPath: ""), options: [:], completionHandler: nil)
        }
    }
    
    private func bubbleImage() -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 40)
        UIGraphicsBeginImageContext(rect.size)
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(rect)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img ?? UIImage()
    }
    
    // MARK: - TUIMessageBaseDataProviderDataSource
    
    func dataProviderDataSourceWillChange(_ dataProvider: TUIMessageBaseDataProvider) {}
    
    func dataProviderDataSourceChange(_ dataProvider: TUIMessageBaseDataProvider, withType type: TUIMessageBaseDataProviderDataSourceChangeType, atIndex index: UInt, animation: Bool) {}
    
    func dataProviderDataSourceDidChange(_ dataProvider: TUIMessageBaseDataProvider) {
        tableView.reloadData()
    }
    
    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, onRemoveHeightCache cellData: TUIMessageCellData) {
        messageCellConfig.removeHeightCacheOfMessageCellData(cellData)
    }
    
    // MARK: - TUINotificationProtocol

    func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_DidChangePluginViewSubKey" {
            if let data = param?["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data"] as? TUIMessageCellData,
               let msgID = data.innerMessage?.msgID
            {
                messageCellConfig.removeHeightCacheOfMessageCellData(data)
                reloadAndScrollToBottomOfMessage(msgID, section: 0)
            }
        }
    }
    
    private func reloadAndScrollToBottomOfMessage(_ messageID: String, section: Int) {
        DispatchQueue.main.async {
            self.reloadCellOfMessage(messageID, section: section)
//            DispatchQueue.main.async {
//                self.scrollCellToBottomOfMessage(messageID, section: section)
//            }
        }
    }
    
    private func reloadCellOfMessage(_ messageID: String, section: Int) {
        guard let indexPath = indexPathOf(messageID, section: section) else { return }
        UIView.performWithoutAnimation {
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [indexPath], with: .none)
            }
        }
    }
    
    private func scrollCellToBottomOfMessage(_ messageID: String, section: Int) {
        guard let indexPath = indexPathOf(messageID, section: section) else { return }
        let cellRect = tableView.rectForRow(at: indexPath)
        let tableViewRect = tableView.bounds
        let isBottomInvisible = cellRect.origin.y < tableViewRect.maxY && cellRect.maxY > tableViewRect.maxY
        if isBottomInvisible {
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
    }
    
    private func indexPathOf(_ messageID: String, section: Int) -> IndexPath? {
        guard let uiMsgs = uiMsgs else { return nil }
        for i in 0..<uiMsgs.count {
            let data = uiMsgs[i]
            if data.innerMessage?.msgID == messageID {
                return IndexPath(row: i, section: section)
            }
        }
        return nil
    }
}
