import ImSDK_Plus
import TIMCommon
import TUICore
import UIKit

public class TUIBaseMessageController: UITableViewController, TUIMessageCellDelegate, TUIJoinGroupMessageCellDelegate, TUIMessageProgressManagerDelegate, TUIMessageDataProviderDataSource, TIMPopActionProtocol, TUINotificationProtocol {
    var groupRoleChanged: ((V2TIMGroupMemberRole) -> Void)?
    var pinGroupMessageChanged: (([V2TIMMessage]) -> Void)?
    weak var delegate: TUIBaseMessageControllerDelegate?
    var isInVC: Bool = false
    var isMsgNeedReadReceipt: Bool = false

    var messageDataProvider: TUIMessageDataProvider?
    var menuUIMsg: TUIMessageCellData?
    var reSendUIMsg: TUIMessageCellData?
    var chatPopMenu: TUIChatPopMenu?
    var conversationData: TUIChatConversationModel?
    var indicatorView: UIActivityIndicatorView?
    var isActive: Bool = false
    var showCheckBox: Bool = false
    var scrollingTriggeredByUser: Bool = false
    var isAutoScrolledToBottom: Bool = false
    var hasCoverPage: Bool = false
    var currentVoiceMsg: TUIVoiceMessageCellData?

    // MARK: - AI Streaming Callback

    var steamCellFinishedBlock: ((Bool, TUIMessageCellData) -> Void)?

    lazy var messageCellConfig: TUIMessageCellConfig = {
        let config = TUIMessageCellConfig()
        return config
    }()

    // MARK: Class method

    class func asyncGetDisplayString(messageList: [V2TIMMessage], callback: @escaping ([String: String]) -> Void) {
        setupDataSource(self)
        TUIMessageDataProvider.asyncGetDisplayString(messageList, callback: callback)
    }

    class func getDisplayString(message: V2TIMMessage?) -> String? {
        setupDataSource(self)
        guard let message = message else { return "" }
        return TUIMessageDataProvider.getDisplayString(message: message)
    }

    private static var hasSetupDataSource = false
    private static func setupDataSource(_ cls: TUIMessageDataProviderDataSource.Type) {
        guard !hasSetupDataSource else { return }
        TUIMessageDataProvider.setDataSourceClass(cls)
        hasSetupDataSource = true
    }

    // MARK: - Life cycle

    override init(style: UITableView.Style) {
        super.init(style: style)
        TUIBaseMessageController.setupDataSource(type(of: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        registerEvents()
        isActive = true
        TUITool.addUnsupportNotification(inVC: self)
        TUIMessageProgressManager.shared.addDelegate(self)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        TUIMessageProgressManager.shared.removeDelegate(self)
        TUICore.unRegisterEvent(byObject: self)
    }

    override public func viewWillAppear(_ animated: Bool) {
        isInVC = true
        super.viewWillAppear(animated)
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sendVisibleReadGroupMessages()
        limitReadReport()
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        currentVoiceMsg?.stopVoiceMessage()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isInVC = false
    }

    @objc func applicationBecomeActive() {
        isActive = true
        sendVisibleReadGroupMessages()
    }

    @objc func applicationEnterBackground() {
        isActive = false
    }

    // MARK: - Setup views and data

    func setupViews() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapViewController))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

        tableView.scrollsToTop = false
        tableView.separatorStyle = .none
        tableView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_controller_bg_color", defaultColor: "#FFFFFF")
        indicatorView = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: CGFloat(TMessageController_Header_Height)))
        indicatorView?.style = UIActivityIndicatorView.Style.medium
        tableView.tableHeaderView = indicatorView
        if !(indicatorView?.isAnimating ?? false) {
            indicatorView?.startAnimating()
        }
        messageCellConfig.bindTableView(tableView)
    }

    func registerEvents() {
        TUICore.registerEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_PluginViewSizeChangedSubKey", object: self)
        TUICore.registerEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_WillForwardTextSubKey", object: self)
        TUICore.registerEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey", object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationBecomeActive), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onReceivedSendMessageRequest(_:)), name: NSNotification.Name(TUIChatSendMessageNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onReceivedSendMessageWithoutUpdateUIRequest(_:)), name: NSNotification.Name(TUIChatSendMessageWithoutUpdateUINotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onReceivedInsertMessageWithoutUpdateUIRequest(_:)), name: NSNotification.Name(TUIChatInsertMessageWithoutUpdateUINotification), object: nil)
    }

    @objc func onReceivedSendMessageRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }

        let message = userInfo["TUICore_TUIChatService_SendMessageMethod_MsgKey"] as? V2TIMMessage
        let cellData = userInfo["TUICore_TUIChatService_SendMessageMethod_PlaceHolderUIMsgKey"] as? TUIMessageCellData

        if let cellData = cellData, message == nil {
            sendPlaceHolderUIMessage(cellData)
        } else if let message = message {
            sendMessage(message, placeHolderCellData: cellData)
        }
    }

    @objc func onReceivedSendMessageWithoutUpdateUIRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }

        guard let message = userInfo["TUICore_TUIChatService_SendMessageMethodWithoutUpdateUI_MsgKey"] as? V2TIMMessage else {
            return
        }

        let param = TUISendMessageAppendParams()
        param.isOnlineUserOnly = true

        if let conversationData = conversationData {
            _ = TUIMessageDataProvider.sendMessage(message, toConversation: conversationData, appendParams: param, Progress: nil, SuccBlock: {
                print("send message without updating UI succeed")
            }, FailBlock: { code, desc in
                print("send message without updating UI failed, code: \(code), desc: \(desc ?? "")")
            })
        }
    }

    // MARK: Data Provider

    func setConversation(conversationData: TUIChatConversationModel) {
        self.conversationData = conversationData
        if messageDataProvider == nil {
            messageDataProvider = TUIMessageDataProvider(conversationModel: conversationData)
            messageDataProvider!.dataSource = self
            messageDataProvider!.mergeAdjacentMsgsFromTheSameSender = true
        }
        loadMessage()
        loadGroupInfo()
    }

    func loadMessage() {
        guard let messageDataProvider = messageDataProvider else { return }
        guard !messageDataProvider.isLoadingData && !messageDataProvider.isNoMoreMsg else { return }
        messageDataProvider.loadMessageSucceedBlock({ [weak self] isFirstLoad, isNoMoreMsg, newMsgs in
            guard let self else { return }
            if isNoMoreMsg {
                self.indicatorView?.mm_h = 0
            }
            if !newMsgs.isEmpty {
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()

                if isFirstLoad {
                    self.scrollToBottom(false)
                } else {
                    var visibleHeight: CGFloat = 0
                    for i in 0..<newMsgs.count {
                        let indexPath = IndexPath(row: i, section: 0)
                        visibleHeight += self.tableView(self.tableView, heightForRowAt: indexPath)
                    }
                    if isNoMoreMsg {
                        visibleHeight -= CGFloat(TMessageController_Header_Height)
                    }
                    let offsetY = self.tableView.contentOffset.y + visibleHeight
                    let rect = CGRect(x: 0, y: offsetY, width: self.tableView.frame.size.width, height: self.tableView.frame.size.height)
                    self.tableView.scrollRectToVisible(rect, animated: false)
                }
            }
        }, FailBlock: { code, desc in
            TUITool.makeToastError(Int(code), msg: desc)
        })
    }

    func loadGroupInfo() {
        guard let messageDataProvider = messageDataProvider,
              let conversationData = conversationData,
              (conversationData.groupID?.count ?? 0) > 0 else { return }

        messageDataProvider.getPinMessageList()
        messageDataProvider.loadGroupInfo {
            messageDataProvider.getSelfInfoInGroup(nil)
        }

        messageDataProvider.groupRoleChanged = { [weak self] role in
            guard let self else { return }
            self.groupRoleChanged?(role)
        }
        messageDataProvider.pinGroupMessageChanged = { [weak self] groupPinList in
            guard let self else { return }
            self.pinGroupMessageChanged?(groupPinList)
        }
    }

    func clearUImsg() {
        messageDataProvider?.clearUIMsgList()
        tableView.reloadData()
        tableView.layoutIfNeeded()
        if indicatorView?.isAnimating ?? false {
            indicatorView?.stopAnimating()
        }
    }

    func reloadAndScrollToBottomOfMessage(_ messageID: String, needScroll: Bool = true) {
        // Dispatch the task to RunLoop to ensure that they are executed after the UITableView refresh is complete.
        DispatchQueue.main.async {
            self.reloadCellOfMessage(messageID)
            DispatchQueue.main.async {
                if needScroll {
                    self.scrollCellToBottomOfMessage(messageID)
                }
            }
        }
    }

    func reloadCellOfMessage(_ messageID: String) {
        guard let indexPath = indexPathOfMessage(messageID) else { return }
        // Disable animation when loading to avoid cell jumping.
        UIView.performWithoutAnimation {
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    func scrollCellToBottomOfMessage(_ messageID: String) {
        guard !hasCoverPage else { return }

        guard let indexPath = indexPathOfMessage(messageID) else { return }

        let cellRect = tableView.rectForRow(at: indexPath)
        let tableViewRect = tableView.bounds
        let isBottomInvisible = (cellRect.origin.y < tableViewRect.maxY && cellRect.maxY > tableViewRect.maxY) ||
            (cellRect.origin.y >= tableViewRect.maxY)
        if isBottomInvisible {
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
        }
        if isAutoScrolledToBottom {
            scrollToBottom(true)
        }
    }

    func indexPathOfMessage(_ messageID: String) -> IndexPath? {
        guard let messageDataProvider = messageDataProvider else { return nil }
        for i in 0..<messageDataProvider.uiMsgs.count {
            let data = messageDataProvider.uiMsgs[i]
            if data.innerMessage?.msgID == messageID {
                return IndexPath(row: i, section: 0)
            }
        }
        return nil
    }

    // MARK: Event Response

    func scrollToBottom(_ animate: Bool) {
        guard let messageDataProvider = messageDataProvider else { return }
        guard messageDataProvider.uiMsgs.count > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: messageDataProvider.uiMsgs.count - 1, section: 0), at: .bottom, animated: animate)
        isAutoScrolledToBottom = true
    }

    @objc func didTapViewController() {
        delegate?.didTap(self)
    }

    func sendPlaceHolderUIMessage(_ cellData: TUIMessageCellData) {
        messageDataProvider?.sendPlaceHolderUIMessage(cellData)
        scrollToBottom(true)
    }

    func sendUIMessage(_ cellData: TUIMessageCellData) {
        guard let conversationData = conversationData, let messageDataProvider = messageDataProvider else { return }
        cellData.innerMessage?.needReadReceipt = isMsgNeedReadReceipt
        messageDataProvider.sendUIMsg(cellData, toConversation: conversationData, willSendBlock: { [weak self] _, _ in
            guard let self = self else { return }
            if cellData.isKind(of: TUIVideoMessageCellData.self) || cellData.isKind(of: TUIImageMessageCellData.self) {
                DispatchQueue.main.async {
                    self.scrollToBottom(true)
                }
            } else {
                self.scrollToBottom(true)
            }
            self.setUIMessageStatus(cellData, status: .sending2)
        }, SuccBlock: { [weak self] in
            guard let self = self else { return }
            self.reloadUIMessage(cellData)
            self.setUIMessageStatus(cellData, status: .success)

            if let msg = cellData.innerMessage {
                let param: [String: Any] = [
                    "TUICore_TUIChatNotify_SendMessageSubKey_Code": 0,
                    "TUICore_TUIChatNotify_SendMessageSubKey_Desc": "",
                    "TUICore_TUIChatNotify_SendMessageSubKey_Message": msg,
                ]
                TUICore.notifyEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_SendMessageSubKey", object: self, param: param)
            }
        }, FailBlock: { [weak self] code, desc in
            guard let self = self else { return }
            self.reloadUIMessage(cellData)
            self.setUIMessageStatus(cellData, status: .fail)
            self.makeSendErrorHud(Int(code), desc: desc ?? "")

            let param: [String: Any] = [
                "TUICore_TUIChatNotify_SendMessageSubKey_Code": code,
                "TUICore_TUIChatNotify_SendMessageSubKey_Desc": desc ?? "",
            ]
            TUICore.notifyEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_SendMessageSubKey", object: self, param: param)
        })
    }

    func setUIMessageStatus(_ cellData: TUIMessageCellData, status: TMsgStatus) {
        switch status {
        case .initStatus, .success, .fail:
            changeMsg(cellData, status: status)
        case .sending, .sending2:
            let delay: Int = cellData.isKind(of: TUIImageMessageCellData.self) || cellData.isKind(of: TUIVideoMessageCellData.self) ? 0 : 1
            if delay == 0 {
                changeMsg(cellData, status: .sending2)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                    if cellData.innerMessage?.status == .MSG_STATUS_SENDING {
                        self.changeMsg(cellData, status: .sending2)
                    }
                }
            }
        }
    }

    func makeSendErrorHud(_ code: Int, desc: String) {
        if code == 80001 || code == 80004 {
            scrollToBottom(true)
            return
        }
        var errorMsg = ""
        let errorCode = ERR_SDK_INTERFACE_NOT_SUPPORT.rawValue
        if isMsgNeedReadReceipt && code == errorCode {
            errorMsg = TUISwift.tuiKitLocalizableString("TUIKitErrorUnsupportIntefaceMessageRead") +
                TUISwift.tuiKitLocalizableString("TUIKitErrorUnsupporInterfaceSuffix")
        } else {
            errorMsg = TUITool.convertIMError(code, msg: desc)
        }
        let ac = UIAlertController(title: errorMsg, message: nil, preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    func sendMessage(_ message: V2TIMMessage) {
        sendMessage(message, placeHolderCellData: nil)
    }

    func sendMessage(_ message: V2TIMMessage, placeHolderCellData: TUIMessageCellData?) {
        var cellData: TUIMessageCellData? = nil
        if message.elemType == .ELEM_TYPE_CUSTOM {
            cellData = delegate?.onNewMessage(self, message: message)
            cellData?.innerMessage = message
        }
        if cellData == nil {
            cellData = TUIMessageDataProvider.convertToCellData(from: message)
        }
        if let cellData = cellData {
            cellData.placeHolder = placeHolderCellData
            if let userID = TUILogin.getUserID() {
                cellData.identifier = userID
            }
            cellData.avatarUrl = TUILogin.getFaceUrl().flatMap { URL(string: $0) }

            sendUIMessage(cellData)
        }
    }

    func reloadUIMessage(_ msg: TUIMessageCellData) {
        guard let messageDataProvider = messageDataProvider else { return }

        if let index = messageDataProvider.uiMsgs.firstIndex(of: msg), let innerMsg = msg.innerMessage {
            let newUIMsgs = messageDataProvider.transUIMsgFromIMMsg([innerMsg])
            guard newUIMsgs.count > 0 else { return }
            let newUIMsg = newUIMsgs.first!
            messageDataProvider.preProcessMessage([newUIMsg], callback: { [weak self] in
                guard let self else { return }
                messageDataProvider.replaceUIMsg(newUIMsg, atIndex: index)
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
            })
        }
    }

    func changeMsg(_ msg: TUIMessageCellData, status: TMsgStatus) {
        guard let messageDataProvider = messageDataProvider else { return }
        msg.status = status
        if let index = messageDataProvider.uiMsgs.firstIndex(of: msg), tableView.numberOfRows(inSection: 0) > index {
            if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? TUIMessageCell {
                cell.fill(with: msg)
            } else {
                print("lack of cell")
            }
        }

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "kTUINotifyMessageStatusChanged"), object: nil, userInfo: ["msg": msg, "status": status.rawValue, "msgSender": self])
    }

    @objc func onReceivedInsertMessageWithoutUpdateUIRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? V2TIMMessage,
              let isNeedScrollToBottom = userInfo["needScrollToBottom"] as? String
        else {
            return
        }
        guard let messageDataProvider = messageDataProvider else { return }

        let newUIMsgs = messageDataProvider.transUIMsgFromIMMsg([message])
        guard !newUIMsgs.isEmpty else {
            return
        }

        let newUIMsg = newUIMsgs.first!
        weak var weakSelf = self
        messageDataProvider.preProcessMessage([newUIMsg]) {
            guard let self = weakSelf else { return }

            UIView.performWithoutAnimation {
                self.tableView.beginUpdates()
                autoreleasepool {
                    for uiMsg in newUIMsgs {
                        if let messageDataProvider = self.messageDataProvider {
                            messageDataProvider.addUIMsg(uiMsg)
                            let indexPath = IndexPath(row: messageDataProvider.uiMsgs.count - 1, section: 0)
                            self.tableView.insertRows(at: [indexPath], with: .none)
                        }
                    }
                }
                self.tableView.endUpdates()

                if isNeedScrollToBottom == "1" {
                    self.scrollToBottom(true)
                }
            }
        }
    }

    // MARK: TUINotificationProtocol

    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        guard let messageDataProvider = messageDataProvider else { return }
        if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_PluginViewSizeChangedSubKey" {
            guard let message = param?["TUICore_TUIPluginNotify_PluginViewSizeChangedSubKey_Message"] as? V2TIMMessage else { return }
            for data in messageDataProvider.uiMsgs {
                if let msg = data.innerMessage, msg.msgID == message.msgID {
                    messageCellConfig.removeHeightCacheOfMessageCellData(data)
                    reloadAndScrollToBottomOfMessage(data.innerMessage?.msgID ?? "")
                    if let indexPath = indexPathOfMessage(data.innerMessage?.msgID ?? "") {
                        tableView.beginUpdates()
                        _ = tableView(tableView, heightForRowAt: indexPath)
                        tableView.endUpdates()
                    }
                    break
                }
            }
        } else if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_DidChangePluginViewSubKey" {
            guard let data = param?["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data"] as? TUIMessageCellData else { return }
            var isAllowScroll2Bottom = true
            if let allowScroll2Bottom = param?["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_isAllowScroll2Bottom"] as? String, allowScroll2Bottom == "0" {
                isAllowScroll2Bottom = false
                let lasData = messageDataProvider.uiMsgs.last
                let isInBottomPage = tableView.contentSize.height - tableView.contentOffset.y <= TUISwift.screen_Height()
                if lasData?.msgID == data.msgID && isInBottomPage {
                    isAllowScroll2Bottom = true
                }
            }

            // Handle AI streaming callback - only for chatbot cells
            if let steamCellFinishedBlock = steamCellFinishedBlock {
                if let isFinished = param?["isFinished"] as? String {
                    if isFinished == "1" {
                        steamCellFinishedBlock(true, data)
                    } else {
                        steamCellFinishedBlock(false, data)
                    }
                }
            }

            messageCellConfig.removeHeightCacheOfMessageCellData(data)
            if let msgID = data.innerMessage?.msgID {
                reloadAndScrollToBottomOfMessage(msgID, needScroll: isAllowScroll2Bottom)
            }
        }
        if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_WillForwardTextSubKey" {
            guard let text = param?["TUICore_TUIPluginNotify_WillForwardTextSubKey_Text"] as? String else { return }
            delegate?.onForwardText(self, text: text)
        }
    }

    // MARK: TUIMessageProgressManagerDelegate

    func onUploadProgress(msgID: String, progress: Int) {}
    func onDownloadProgress(msgID: String, progress: Int) {}
    func onMessageSendingResultChanged(type: TUIMessageSendingResultType, messageID: String) {
        guard let messageDataProvider = messageDataProvider else { return }
        DispatchQueue.main.async {
            for cellData in messageDataProvider.uiMsgs {
                if cellData.msgID == messageID {
                    self.changeMsg(cellData, status: type == TUIMessageSendingResultType.success ? .success : .fail)
                }
            }
        }
    }

    // MARK: TUIMessageBaseDataProviderDataSource

    static func onGetCustomMessageCellDataClass(businessID: String) -> TUIMessageCellDataDelegate.Type? {
        return TUIMessageCellConfig.getCustomMessageCellDataClass(businessID)
    }

    func isDataSourceConsistent() -> Bool {
        let dataSourceCount = messageDataProvider?.uiMsgs.count ?? 0
        let tableViewCount = tableView.numberOfRows(inSection: 0)

        if dataSourceCount != tableViewCount {
            print("Data source and UI are inconsistent: Data source count = \(dataSourceCount), Table view count = \(tableViewCount)")
            return false
        }
        return true
    }

    private static var lastMsgIndexs: [Int]?
    private static var reloadMsgIndexs: [Int]?

    func dataProviderDataSourceWillChange(_ dataProvider: TUIMessageBaseDataProvider) {
        tableView.beginUpdates()

        if TUIBaseMessageController.lastMsgIndexs != nil {
            TUIBaseMessageController.lastMsgIndexs?.removeAll()
        } else {
            TUIBaseMessageController.lastMsgIndexs = []
        }

        if TUIBaseMessageController.reloadMsgIndexs != nil {
            TUIBaseMessageController.reloadMsgIndexs?.removeAll()
        } else {
            TUIBaseMessageController.reloadMsgIndexs = []
        }
    }

    func dataProviderDataSourceChange(_ dataProvider: TUIMessageBaseDataProvider, withType type: TUIMessageBaseDataProviderDataSourceChangeType, atIndex index: UInt, animation: Bool) {
        let indexPath = IndexPath(row: Int(index), section: 0)
        let rowAnimation: UITableView.RowAnimation = animation ? .fade : .none

        switch type {
        case .insert:
            tableView.insertRows(at: [indexPath], with: rowAnimation)
        case .delete:
            tableView.deleteRows(at: [indexPath], with: rowAnimation)
        case .reload:
            tableView.reloadRows(at: [indexPath], with: rowAnimation)
        }
    }

    func dataProviderDataSourceDidChange(_ dataProvider: TUIMessageBaseDataProvider) {
        tableView.endUpdates()
    }

    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, onRemoveHeightCache cellData: TUIMessageCellData) {
        messageCellConfig.removeHeightCacheOfMessageCellData(cellData)
    }

    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, customCellDataFromNewIMMessage msg: V2TIMMessage) -> TUIMessageCellData? {
        guard msg.userID == conversationData?.userID || msg.groupID == conversationData?.groupID else { return nil }
        guard msg.status != .MSG_STATUS_LOCAL_REVOKED else { return nil }

        if let customCellData = delegate?.onNewMessage(self, message: msg) {
            customCellData.innerMessage = msg
            return customCellData
        }
        return nil
    }

    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, receiveReadMsgWithUserID userId: String, time timestamp: time_t) {
        guard userId.count > 0 && userId == conversationData?.userID else { return }
        guard let messageDataProvider = messageDataProvider else { return }
        for i in 0..<messageDataProvider.uiMsgs.count {
            let indexPath = IndexPath(row: messageDataProvider.uiMsgs.count - 1 - i, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) as? TUIMessageCell,
               let msgTime = cell.messageData?.innerMessage?.timestamp?.timeIntervalSince1970,
               msgTime <= Double(timestamp) && cell.readReceiptLabel.text != TUISwift.timCommonLocalizableString("Read")
            {
                cell.readReceiptLabel.text = TUISwift.timCommonLocalizableString("Read")
            }
        }
    }

    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, receiveReadMsgWithGroupID groupID: String, msgID: String, readCount: UInt, unreadCount: UInt) {
        guard let messageDataProvider = messageDataProvider, groupID == conversationData?.groupID else { return }
        let row = messageDataProvider.getIndexOfMessage(msgID)
        if row >= 0 && row < messageDataProvider.uiMsgs.count {
            let indexPath = IndexPath(row: row, section: 0)
            if let cell = tableView.cellForRow(at: indexPath) as? TUIMessageCell {
                cell.updateReadLabelText()
            }
        }
    }

    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, receiveNewUIMsg uiMsg: TUIMessageCellData) {
        if tableView.contentSize.height - tableView.contentOffset.y < TUISwift.screen_Height() * 1.5 {
            scrollToBottom(true)
            if isInVC && isActive {
                messageDataProvider?.sendLatestMessageReadReceipt()
            }
        }

        limitReadReport()
    }

    func dataProvider(_ dataProvider: TUIMessageBaseDataProvider, receiveRevokeUIMsg uiMsg: TUIMessageCellData) {}

    // MARK: Private

    static var lastTimestamp: UInt64 = 0
    static var delayReport = false
    private func limitReadReport() {
        let currentTimestamp = UInt64(Date().timeIntervalSince1970)
        if currentTimestamp - TUIBaseMessageController.lastTimestamp >= 1 && TUIBaseMessageController.lastTimestamp != 0 {
            TUIBaseMessageController.lastTimestamp = currentTimestamp
            readReport()
        } else {
            if TUIBaseMessageController.delayReport {
                return
            }
            TUIBaseMessageController.delayReport = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.readReport()
                TUIBaseMessageController.delayReport = false
            }
        }
    }

    func readReport() {
        guard let conversationData = conversationData else { return }
        guard isInVC && isActive else { return }

        let userID = conversationData.userID ?? ""
        let groupID = conversationData.groupID ?? ""
        let convID = conversationData.conversationID ?? ""

        if !userID.isEmpty {
            TUIMessageDataProvider.markC2CMessageAsRead(userID, succ: nil, fail: nil)
        }

        if !groupID.isEmpty {
            TUIMessageDataProvider.markGroupMessageAsRead(groupID, succ: nil, fail: nil)
        }

        var conversationID: String
        if !userID.isEmpty {
            conversationID = "c2c_\(userID)"
        } else if !groupID.isEmpty {
            conversationID = "group_\(groupID)"
        } else if !convID.isEmpty {
            conversationID = convID
        } else {
            return
        }

        TUIMessageDataProvider.markConversationAsUndead([conversationID], enableMark: false)
    }

    private func sendVisibleReadGroupMessages() {
        guard isInVC && isActive else { return }
        let range = calcVisibleCellRange()
        messageDataProvider?.sendMessageReadReceiptAtIndexes(transferIndexFromRange(range))
    }

    private func calcVisibleCellRange() -> NSRange {
        guard let indexPaths = tableView.indexPathsForVisibleRows, indexPaths.count > 0 else { return NSRange(location: 0, length: 0) }
        let topmost = indexPaths.first!
        let downmost = indexPaths.last!
        return NSRange(location: topmost.row, length: downmost.row - topmost.row + 1)
    }

    private func transferIndexFromRange(_ range: NSRange) -> [Int] {
        var indexes = [Int]()
        for i in range.location..<(range.location + range.length) {
            indexes.append(i)
        }
        return indexes
    }

    private func hideKeyboardIfNeeded() {
        view.endEditing(true)
        TUITool.applicationKeywindow()?.endEditing(true)
    }

    func getHeightFromMessageCellData(_ cellData: TUIMessageCellData) -> CGFloat {
        return messageCellConfig.getHeightFromMessageCellData(cellData)
    }

    // MARK: UITableViewDelegate

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messageDataProvider?.uiMsgs.count ?? 0
    }

    override public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let messageDataProvider = messageDataProvider else { return 0 }
        if indexPath.row < messageDataProvider.uiMsgs.count {
            let cellData = messageDataProvider.uiMsgs[indexPath.row]
            return messageCellConfig.getHeightFromMessageCellData(cellData)
        } else {
            return 0
        }
    }

    override public func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let messageDataProvider = messageDataProvider else { return UITableViewCell() }
        let data = messageDataProvider.uiMsgs[indexPath.row]
        data.showCheckBox = showCheckBox && supportCheckBox(data)

        var cell = delegate?.onShowMessageData(self, data: data) as? TUIMessageCell
        if cell != nil {
            cell!.delegate = self
            return cell!
        }

        guard !data.reuseId.isEmpty else {
            assertionFailure("Unknown cell")
            return UITableViewCell()
        }

        cell = tableView.dequeueReusableCell(withIdentifier: data.reuseId, for: indexPath) as? TUIMessageCell
        let oldData = cell?.messageData
        cell?.delegate = self
        cell?.fill(with: data)
        cell?.notifyBottomContainerReady(of: oldData)
        return cell!
    }

    func tableView(_ tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let messageCell = cell as? TUIMessageCell, let messageData = messageCell.messageData else { return }
        delegate?.willDisplayCell(self, cell: messageCell, withData: messageData)
    }

    func tableView(_ tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let messageDataProvider = messageDataProvider else { return }
        if indexPath.row < messageDataProvider.uiMsgs.count {
            if let cellData = messageDataProvider.uiMsgs[indexPath.row] as? TUITextMessageCellData {
                // Delete after TUICallKit is connected according to the standard process
                if (cellData.isAudioCall || cellData.isVideoCall) && cellData.showUnreadPoint {
                    cellData.innerMessage?.localCustomInt = 1
                    cellData.showUnreadPoint = false
                }
                TUICore.notifyEvent("TUICore_TUIChatNotify", subKey: "TUICore_TUIChatNotify_MessageDisplayedSubKey", object: cellData, param: nil)
            }
        }
    }

    // MARK: UIScrollViewDelegate

    override public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollingTriggeredByUser {
            sendVisibleReadGroupMessages()
            isAutoScrolledToBottom = false
        }
    }

    override public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollingTriggeredByUser = true
        didTapViewController()
    }

    override public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if isScrollViewEndDragging(scrollView) {
            scrollingTriggeredByUser = false
        }
    }

    override public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if isScrollViewEndDecelerating(scrollView) {
            scrollingTriggeredByUser = false
        }
    }

    override public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        if isScrollViewEndDecelerating(scrollView) {
            sendVisibleReadGroupMessages()
        }
    }

    func isScrollViewEndDecelerating(_ scrollView: UIScrollView) -> Bool {
        return scrollView.isTracking == false && scrollView.isDragging == false && scrollView.isDecelerating == false
    }

    func isScrollViewEndDragging(_ scrollView: UIScrollView) -> Bool {
        return scrollView.isTracking == true && scrollView.isDragging == false && scrollView.isDecelerating == false
    }

    // MARK: TUIMessageCellDelegate

    public func onSelectMessage(_ cell: TUIMessageCell) {
        guard let messageData = cell.messageData else { return }
        if let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onMessageClicked(cell, messageCellData: messageData), result == true { return }

        if (messageData.innerMessage?.hasRiskContent ?? false) && !(cell is TUIReferenceMessageCell) {
            return
        }

        if let data = cell.data as? TUIMessageCellData {
            if showCheckBox && supportCheckBox(data) {
                data.selected = !data.selected
                tableView.reloadData()
                return
            }
        }

        hideKeyboardIfNeeded()

        if let messageData = cell.messageData, TUIMessageCellConfig.isPluginCustomMessageCellData(messageData) {
            var param = [String: Any]()
            param["TUICore_TUIPluginNotify_PluginCustomCellClick_Cell"] = cell
            if let navigationController = navigationController {
                param["TUICore_TUIPluginNotify_PluginCustomCellClick_PushVC"] = navigationController
            }
            cell.pluginMsgSelectCallback?(param)
        } else if let textCell = cell as? TUITextMessageCell {
            clickTextMessage(textCell)
        } else if let systemCell = cell as? TUISystemMessageCell {
            clickSystemMessage(systemCell)
        } else if let voiceCell = cell as? TUIVoiceMessageCell {
            playVoiceMessage(voiceCell)
        } else if let imageCell = cell as? TUIImageMessageCell {
            showImageMessage(imageCell)
        } else if let videoCell = cell as? TUIVideoMessageCell {
            showVideoMessage(videoCell)
        } else if let fileCell = cell as? TUIFileMessageCell {
            showFileMessage(fileCell)
        } else if let mergeCell = cell as? TUIMergeMessageCell {
            showRelayMessage(mergeCell)
        } else if let linkCell = cell as? TUILinkCell {
            showLinkMessage(linkCell)
        } else if let replyCell = cell as? TUIReplyMessageCell {
            showReplyMessage(replyCell)
        } else if let referenceCell = cell as? TUIReferenceMessageCell {
            showReplyMessage(referenceCell)
        } else if let orderCell = cell as? TUIOrderCell {
            showOrderMessage(orderCell)
        }

        delegate?.onSelectMessageContent(self, cell: cell)
    }

    // MARK: - TUIMessageCellDelegate

    public func onLongPressMessage(_ cell: TUIMessageCell) {
        guard let data = cell.messageData else { return }
        if let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onMessageLongClicked(cell, messageCellData: data), result == true { return }

        TUITool.applicationKeywindow()?.endEditing(false)

        if !data.canLongPress() || data is TUISystemMessageCellData {
            return
        }
        menuUIMsg = data

        if let chatPopMenu = chatPopMenu, chatPopMenu.superview != nil {
            return
        }

        // Handle AI conversation long press
        if let conversationData = conversationData, conversationData.isAIConversation() {
            handleAIConversationLongPress(cell)
            return
        }

        let menu = TUIChatPopMenu(hasEmojiView: true, frame: .zero)
        chatPopMenu = menu
        menu.targetCellData = data
        menu.targetCell = cell

        let isPluginCustomMessage = TUIMessageCellConfig.isPluginCustomMessageCellData(data)
        let isChatNormalMessageOrCustomMessage = !isPluginCustomMessage

        if isChatNormalMessageOrCustomMessage {
            addChatCommonActionToCell(cell, ofMenu: menu)
        } else {
            addChatPluginCommonActionToCell(cell, ofMenu: menu)
        }

        addExtensionActionToCell(cell, ofMenu: menu)

        if let textCell = cell as? TUITextMessageCell {
            textCell.textView.becomeFirstResponder()
            textCell.textView.selectAll(self)
        } else if let referenceCell = cell as? TUIReferenceMessageCell {
            referenceCell.textView.becomeFirstResponder()
            referenceCell.textView.selectAll(self)
        }

        var isFirstResponder = false
        if let willShowMenu = delegate?.willShowMenu(self, inCell: cell) {
            isFirstResponder = willShowMenu
        }
        if isFirstResponder {
            NotificationCenter.default.addObserver(self, selector: #selector(menuDidHide(_:)), name: UIMenuController.didHideMenuNotification, object: nil)
        } else {
            becomeFirstResponder()
        }

        if let keyWindow = TUITool.applicationKeywindow() {
            let frame = keyWindow.convert(cell.container.frame, from: cell)

            var topMarginByCustomView: CGFloat = 0
            if let margin = delegate?.getTopMarginByCustomView() {
                topMarginByCustomView = margin
            }

            menu.setArrawPosition(CGPoint(x: frame.origin.x + frame.size.width * 0.5, y: frame.origin.y - 5 - topMarginByCustomView), adjustHeight: frame.size.height + 5)
            menu.showInView(tableView)

            configSelectActionToCell(cell, ofMenu: menu)
        }
    }

    @objc func menuDidHide(_ notification: Notification) {
        delegate?.didHideMenu(self)
        NotificationCenter.default.removeObserver(self, name: UIMenuController.didHideMenuNotification, object: nil)
    }

    func addChatCommonActionToCell(_ cell: TUIMessageCell, ofMenu menu: TUIChatPopMenu) {
        // Setup popAction
        let copyAction = setupCopyAction(cell)
        let deleteAction = setupDeleteAction(cell)
        let recallAction = setupRecallAction(cell)
        let multiAction = setupMulitSelectAction(cell)
        let forwardAction = setupForwardAction(cell)
        let replyAction = setupReplyAction(cell)
        let quoteAction = setupQuoteAction(cell)
        let audioPlaybackStyleAction = setupAudioPlaybackStyleAction(cell)
        let groupPinAction = setupGroupPinAction(cell)

        let data = cell.messageData
        guard let imMsg = data?.innerMessage else { return }

        let isMsgSendSucceed = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isContentModerated = imMsg.hasRiskContent

        if let audioPlaybackStyleAction = audioPlaybackStyleAction, imMsg.soundElem != nil {
            menu.addAction(audioPlaybackStyleAction)
        }
        if let copyAction = copyAction, (data is TUITextMessageCellData || data is TUIReplyMessageCellData || data is TUIReferenceMessageCellData) && !isContentModerated {
            menu.addAction(copyAction)
        }
        if let deleteAction = deleteAction {
            menu.addAction(deleteAction)
        }
        if let multiAction = multiAction, !isContentModerated {
            menu.addAction(multiAction)
        }
        if let recallAction = recallAction, imMsg.isSelf && Date().timeIntervalSince(imMsg.timestamp ?? Date()) < Double(TUIChatConfig.shared.timeIntervalForMessageRecall) && isMsgSendSucceed {
            menu.addAction(recallAction)
        }
        if let forwardAction = forwardAction, let data = data, canForward(data) && isMsgSendSucceed && !isContentModerated {
            menu.addAction(forwardAction)
        }
        if let replyAction = replyAction, isMsgSendSucceed && !isContentModerated {
            menu.addAction(replyAction)
        }
        if let quoteAction = quoteAction, isMsgSendSucceed && !isContentModerated {
            menu.addAction(quoteAction)
        }
        if let groupPinAction = groupPinAction, let groupID = data?.innerMessage?.groupID, !groupID.isEmpty && (messageDataProvider?.isCurrentUserRoleSuperAdminInGroup() ?? false) && isMsgSendSucceed && !isContentModerated {
            menu.addAction(groupPinAction)
        }
    }

    func addChatPluginCommonActionToCell(_ cell: TUIMessageCell, ofMenu menu: TUIChatPopMenu) {
        // Setup popAction
        let deleteAction = setupDeleteAction(cell)
        let recallAction = setupRecallAction(cell)
        let multiAction = setupMulitSelectAction(cell)
        let replyAction = setupReplyAction(cell)
        let quoteAction = setupQuoteAction(cell)
        let pinAction = setupGroupPinAction(cell)

        let data = cell.messageData
        guard let imMsg = data?.innerMessage else { return }
        let isContentModerated = imMsg.hasRiskContent

        let isMsgSendSucceed = imMsg.status == .MSG_STATUS_SEND_SUCC
        if let multiAction = multiAction {
            menu.addAction(multiAction)
        }
        if let replyAction = replyAction, let quoteAction = quoteAction, isMsgSendSucceed {
            menu.addAction(replyAction)
            menu.addAction(quoteAction)
        }
        if let pinAction = pinAction, let groupID = data?.innerMessage?.groupID, !groupID.isEmpty && (messageDataProvider?.isCurrentUserRoleSuperAdminInGroup() ?? false) && isMsgSendSucceed && !isContentModerated {
            menu.addAction(pinAction)
        }
        if let deleteAction = deleteAction {
            menu.addAction(deleteAction)
        }
        if let recallAction = recallAction, imMsg.isSelf && Date().timeIntervalSince(imMsg.timestamp ?? Date()) < Double(TUIChatConfig.shared.timeIntervalForMessageRecall) && isMsgSendSucceed {
            menu.addAction(recallAction)
        }
    }

    func addExtensionActionToCell(_ cell: TUIMessageCell, ofMenu menu: TUIChatPopMenu) {
        // extra
        let infoArray = TUICore.getExtensionList("TUICore_TUIChatExtension_PopMenuActionItem_ClassicExtensionID", param: [
            "TUICore_TUIChatExtension_PopMenuActionItem_TargetVC": self,
            "TUICore_TUIChatExtension_PopMenuActionItem_ClickCell": cell,
        ])

        for info in infoArray {
            if let text = info.text, let icon = info.icon, let onClicked = info.onClicked {
                let extensionAction = TUIChatPopMenuAction(title: text, image: icon, weight: info.weight) {
                    onClicked([:])
                }
                menu.addAction(extensionAction)
            }
        }
    }

    func configSelectActionToCell(_ cell: TUIMessageCell, ofMenu menu: TUIChatPopMenu) {
        // Setup popAction
        let copyAction = setupCopyAction(cell)
        let deleteAction = setupDeleteAction(cell)
        let multiAction = setupMulitSelectAction(cell)
        let forwardAction = setupForwardAction(cell)
        let replyAction = setupReplyAction(cell)
        let quoteAction = setupQuoteAction(cell)
        let groupPinAction = setupGroupPinAction(cell)

        let data = cell.messageData

        var isSelectAll = true
        let selectAllContentCallback: (Bool) -> Void = { [weak self, weak cell, weak menu] selectAll in
            guard let self = self, let cell = cell, let menu = menu else { return }
            if isSelectAll == selectAll {
                return
            }
            isSelectAll = selectAll
            menu.removeAllAction()
            if isSelectAll {
                if let copyAction = copyAction {
                    menu.addAction(copyAction)
                }
                if let deleteAction = deleteAction {
                    menu.addAction(deleteAction)
                }
                if let multiAction = multiAction {
                    menu.addAction(multiAction)
                }
                if let forwardAction = forwardAction, let data = data, self.canForward(data) {
                    menu.addAction(forwardAction)
                }
                if let replyAction = replyAction {
                    menu.addAction(replyAction)
                }
                if let quoteAction = quoteAction {
                    menu.addAction(quoteAction)
                }

                if let groupPinAction = groupPinAction, let groupID = data?.innerMessage?.groupID, !groupID.isEmpty && (self.messageDataProvider?.isCurrentUserRoleSuperAdminInGroup() ?? false) {
                    menu.addAction(groupPinAction)
                }
            } else {
                if let copyAction = copyAction {
                    menu.addAction(copyAction)
                }
                if let forwardAction = forwardAction, let data = data, self.canForward(data) {
                    menu.addAction(forwardAction)
                }
            }
            self.addExtensionActionToCell(cell, ofMenu: menu)
            menu.layoutSubview()
        }

        if let textCell = cell as? TUITextMessageCell {
            textCell.textView.selectAll(self)
            textCell.selectAllContentCallback = selectAllContentCallback
            menu.hideCallback = {
                textCell.textView.selectedTextRange = nil
            }
        }

        if let referenceCell = cell as? TUIReferenceMessageCell {
            referenceCell.textView.selectAll(self)
            referenceCell.selectAllContentCallback = selectAllContentCallback
            menu.hideCallback = {
                referenceCell.textView.selectedTextRange = nil
            }
        }
    }

    func setupCopyAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isCopyShown = TUIChatConfig.shared.enablePopMenuCopyAction
        let copyAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Copy"),
                                              image: TUISwift.tuiChatBundleThemeImage("chat_icon_copy_img", defaultImage: "icon_copy"),
                                              weight: 10000)
        { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            self.onCopyMsg(cell)
        }
        return isCopyShown ? copyAction : nil
    }

    func setupDeleteAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isDeleteShown = TUIChatConfig.shared.enablePopMenuDeleteAction
        let deleteAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Delete"),
                                                image: TUISwift.tuiChatBundleThemeImage("chat_icon_delete_img", defaultImage: "icon_delete"),
                                                weight: 3000)
        { [weak self] in
            self?.onDelete(nil)
        }
        return isDeleteShown ? deleteAction : nil
    }

    func setupRecallAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isRecallShown = TUIChatConfig.shared.enablePopMenuRecallAction
        let recallAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Revoke"),
                                                image: TUISwift.tuiChatBundleThemeImage("chat_icon_recall_img", defaultImage: "icon_recall"),
                                                weight: 4000)
        { [weak self] in
            self?.onRevoke(nil)
        }
        return isRecallShown ? recallAction : nil
    }

    func setupMulitSelectAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isSelectShown = TUIChatConfig.shared.enablePopMenuSelectAction
        let multiAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Multiple"),
                                               image: TUISwift.tuiChatBundleThemeImage("chat_icon_multi_img", defaultImage: "icon_multi"),
                                               weight: 8000)
        { [weak self] in
            self?.onMulitSelect(nil)
        }
        return isSelectShown ? multiAction : nil
    }

    func setupForwardAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isForwardShown = TUIChatConfig.shared.enablePopMenuForwardAction
        let forwardAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Forward"),
                                                 image: TUISwift.tuiChatBundleThemeImage("chat_icon_forward_img", defaultImage: "icon_forward"),
                                                 weight: 9000)
        { [weak self] in
            self?.onForward(nil)
        }
        return isForwardShown ? forwardAction : nil
    }

    func setupReplyAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isReplyShown = TUIChatConfig.shared.enablePopMenuReplyAction
        let replyAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Reply"),
                                               image: TUISwift.tuiChatBundleThemeImage("chat_icon_reply_img", defaultImage: "icon_reply"),
                                               weight: 5000)
        { [weak self] in
            self?.onReply(nil)
        }
        return isReplyShown ? replyAction : nil
    }

    func setupQuoteAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isQuoteShown = TUIChatConfig.shared.enablePopMenuReferenceAction
        let quoteAction = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("TUIKitReference"),
                                               image: TUISwift.tuiChatBundleThemeImage("chat_icon_reference_img", defaultImage: "icon_reference"),
                                               weight: 7000)
        { [weak self] in
            self?.onReference(nil)
        }
        return isQuoteShown ? quoteAction : nil
    }

    func setupAudioPlaybackStyleAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isPlaybackShown = TUIChatConfig.shared.enablePopMenuAudioPlaybackAction
        let originStyle = TUIVoiceMessageCellData.getAudioplaybackStyle()
        let title: String
        var img = UIImage()

        if originStyle == .loudspeaker {
            title = TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleHandset")
            img = TUISwift.tuiChatBundleThemeImage("chat_icon_audio_handset_img", defaultImage: "icon_handset")
        } else {
            title = TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleLoudspeaker")
            img = TUISwift.tuiChatBundleThemeImage("chat_icon_audio_loudspeaker_img", defaultImage: "icon_loudspeaker")
        }

        let audioPlaybackStyleAction = TUIChatPopMenuAction(title: title, image: img, weight: 11000) {
            if originStyle == .loudspeaker {
                TUITool.hideToast()
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleChange2Handset"), duration: 2)
            } else {
                TUITool.hideToast()
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleChange2Loudspeaker"), duration: 2)
            }
            TUIVoiceMessageCellData.changeAudioPlaybackStyle()
        }
        return isPlaybackShown ? audioPlaybackStyleAction : nil
    }

    func setupGroupPinAction(_ cell: TUIMessageCell) -> TUIChatPopMenuAction? {
        let isPinShown = TUIChatConfig.shared.enablePopMenuPinAction
        let isPinned = messageDataProvider?.isCurrentMessagePin(menuUIMsg?.innerMessage?.msgID ?? "") ?? false
        let img = isPinned ? TUISwift.tuiChatBundleThemeImage("chat_icon_group_unpin_img", defaultImage: "icon_unpin") : TUISwift.tuiChatBundleThemeImage("chat_icon_group_pin_img", defaultImage: "icon_pin")
        let groupPinAction = TUIChatPopMenuAction(title: isPinned ? TUISwift.timCommonLocalizableString("TUIKitGroupMessageUnPin") : TUISwift.timCommonLocalizableString("TUIKitGroupMessagePin"),
                                                  image: img, weight: 2900)
        { [weak self] in
            self?.onGroupPin(nil, currentStatus: isPinned)
        }
        return isPinShown ? groupPinAction : nil
    }

    func canForward(_ data: TUIMessageCellData) -> Bool {
        return !TUIMessageCellConfig.isPluginCustomMessageCellData(data)
    }

    public func onLongSelectMessageAvatar(_ cell: TUIMessageCell) {
        if let messageData = cell.messageData, let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onUserIconLongClicked(cell, messageCellData: messageData), result == true { return }

        delegate?.onLongSelectMessageAvatar(self, cell: cell)
    }

    public func onRetryMessage(_ cell: TUIMessageCell) {
        guard let resendMsg = cell.messageData, resendMsg.innerMessage?.hasRiskContent == false else { return }
        reSendUIMsg = resendMsg
        let alert = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitTipsConfirmResendMessage"), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Re_send"), style: .default, handler: { [weak self] _ in
            guard let self else { return }
            self.sendUIMessage(resendMsg)
        }))
        alert.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        navigationController?.present(alert, animated: true, completion: nil)
    }

    public func onSelectMessageAvatar(_ cell: TUIMessageCell) {
        if let messageData = cell.messageData, let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onUserIconClicked(cell, messageCellData: messageData), result == true { return }

        delegate?.onSelectMessageAvatar(self, cell: cell)
    }

    public func onSelectReadReceipt(_ data: TUIMessageCellData) {
        // AI conversations don't support read receipts
        if let conversationData = conversationData, conversationData.isAIConversation() {
            return
        }

        if let msg = data.innerMessage, let groupID = data.innerMessage?.groupID, !groupID.isEmpty {
            // Navigate to group message read VC. Should get members first.
            TUIMessageDataProvider.getMessageReadReceipt([msg], succ: { [weak self] receiptList in
                guard let self = self else { return }
                // To avoid the labels in messageReadVC displaying all 0 which is not accurate, try to get message read count before navigation.
                if let receipt = receiptList?.first {
                    data.messageReceipt = receipt
                    self.pushMessageReadViewController(data)
                }
            }, fail: { [weak self] _, _ in
                guard let self = self else { return }
                self.pushMessageReadViewController(data)
            })
        } else {
            // Navigate to c2c message read VC. No need to get member.
            pushMessageReadViewController(data)
        }
    }

    func pushMessageReadViewController(_ data: TUIMessageCellData) {
        hasCoverPage = true
        let controller = TUIMessageReadViewController(cellData: data,
                                                      dataProvider: messageDataProvider ?? TUIMessageDataProvider(),
                                                      showReadStatusDisable: false,
                                                      c2cReceiverName: conversationData?.title ?? "",
                                                      c2cReceiverAvatar: conversationData?.faceUrl ?? "")
        navigationController?.pushViewController(controller, animated: true)

        controller.viewWillDismissHandler = { [weak self] in
            self?.hasCoverPage = false
        }
    }

    public func onJumpToRepliesDetailPage(_ data: TUIMessageCellData) {
        guard let conversationData = conversationData else { return }
        hasCoverPage = true
        let repliesDetailVC = TUIRepliesDetailViewController(cellData: data, conversationData: conversationData)
        repliesDetailVC.delegate = delegate
        navigationController?.pushViewController(repliesDetailVC, animated: true)
        repliesDetailVC.parentPageDataProvider = messageDataProvider ?? TUIMessageDataProvider()

        repliesDetailVC.willCloseCallback = { [weak self] in
            guard let self = self else { return }
            self.tableView.reloadData()
            self.hasCoverPage = false
        }
    }

    override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        let actions = [#selector(onDelete(_:)), #selector(onRevoke(_:)), #selector(onReSend(_:)), #selector(onCopyMsg(_:)), #selector(onMulitSelect(_:)), #selector(onForward(_:)), #selector(onReply(_:))]
        return actions.contains(action)
    }

    override public var canBecomeFirstResponder: Bool {
        return true
    }

    @available(iOS 13.0, *)
    override public func buildMenu(with builder: any UIMenuBuilder) {
        if #available(iOS 16.0, *) {
            builder.remove(menu: UIMenu.Identifier.lookup)
        }
        super.buildMenu(with: builder)
    }

    // MARK: - TIMPopActionProtocol

    @objc public func onDelete(_ sender: Any?) {
        let alertController = UIAlertController(title: nil, message: TUISwift.timCommonLocalizableString("ConfirmDeleteMessage"), preferredStyle: .actionSheet)

        let deleteAction = UIAlertAction(title: TUISwift.timCommonLocalizableString("Delete"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if let menuUIMsg = self.menuUIMsg {
                self.messageDataProvider?.deleteUIMsgs([menuUIMsg], SuccBlock: nil, FailBlock: { _, desc in
                    assertionFailure(desc ?? "")
                })
            }
        }

        let cancelAction = UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil)

        alertController.tuitheme_addAction(deleteAction)
        alertController.tuitheme_addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }

    @objc public func onCopyMsg(_ sender: Any?) {
        var content = ""

        if let txtCell = sender as? TUITextMessageCell {
            content = txtCell.selectContent ?? ""
        } else if let replyCell = sender as? TUIReplyMessageCell {
            content = replyCell.selectContent ?? ""
        } else if let referenceCell = sender as? TUIReferenceMessageCell {
            content = referenceCell.selectContent ?? ""
        }

        if !content.isEmpty {
            let pasteboard = UIPasteboard.general
            pasteboard.string = content
            TUITool.makeToast(TUISwift.timCommonLocalizableString("Copied"))
        }
    }

    @objc public func onRevoke(_ sender: Any?) {
        guard let menuUIMsg = menuUIMsg else { return }
        messageDataProvider?.revokeUIMsg(menuUIMsg, SuccBlock: { [weak self] in
            guard let self else { return }
            self.delegate?.didHideMenu(self)
        }, FailBlock: { _, desc in
            print("revoke failed: \(desc ?? "")")
        })
    }

    @objc public func onReSend(_ sender: Any?) {
        guard let menuUIMsg = menuUIMsg else { return }
        sendUIMessage(menuUIMsg)
    }

    @objc public func onMulitSelect(_ sender: Any?) {
        guard let menuUIMsg = menuUIMsg else { return }
        enableMultiSelectedMode(true)
        if menuUIMsg.innerMessage?.hasRiskContent == true {
            delegate?.onSelectMessageMenu(self, menuType: 0, withData: nil)
            return
        }
        menuUIMsg.selected = true
        tableView.beginUpdates()
        if let index = messageDataProvider?.uiMsgs.firstIndex(of: menuUIMsg) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
        tableView.endUpdates()

        delegate?.onSelectMessageMenu(self, menuType: 0, withData: menuUIMsg)
    }

    @objc public func onForward(_ sender: Any?) {
        delegate?.onSelectMessageMenu(self, menuType: 1, withData: menuUIMsg)
    }

    @objc public func onReply(_ sender: Any?) {
        delegate?.onRelyMessage(self, data: menuUIMsg)
    }

    @objc public func onReference(_ sender: Any?) {
        delegate?.onReferenceMessage(self, data: menuUIMsg)
    }

    @objc public func onGroupPin(_ sender: Any?, currentStatus: Bool) {
        let groupId = conversationData?.groupID ?? ""
        let pinOrUnpin = !currentStatus

        if let menuUIMsg = menuUIMsg, let msg = menuUIMsg.innerMessage {
            messageDataProvider?.pinGroupMessage(groupId, message: msg, isPinned: pinOrUnpin, succ: {
                // Success block
            }, fail: { code, _ in
                if code == 10070 {
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupMessagePinOverLimit"))
                } else if code == 10004 {
                    if pinOrUnpin {
                        TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupMessagePinRepeatedly"))
                    } else {
                        TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupMessageUnPinRepeatedly"))
                    }
                }
            })
        }
    }

    func supportCheckBox(_ data: TUIMessageCellData) -> Bool {
        return !(data is TUISystemMessageCellData)
    }

    func supportRelay(_ data: TUIMessageCellData) -> Bool {
        return !(data is TUIVoiceMessageCellData)
    }

    func enableMultiSelectedMode(_ enable: Bool) {
        showCheckBox = enable
        if let uiMsgs = messageDataProvider?.uiMsgs, !enable {
            for cellData in uiMsgs {
                cellData.selected = false
            }
        }
        tableView.reloadData()
    }

    func multiSelectedResult(_ option: TUIMultiResultOption) -> [TUIMessageCellData] {
        var arrayM = [TUIMessageCellData]()
        if !showCheckBox {
            return arrayM
        }
        let filterUnsupported = option.rawValue & TUIMultiResultOption.filterUnsupportRelay.rawValue
        guard let messageDataProvider = messageDataProvider else { return arrayM }
        for data in messageDataProvider.uiMsgs {
            if data.selected {
                if filterUnsupported == 1 && !supportRelay(data) {
                    continue
                }
                arrayM.append(data)
            }
        }
        return arrayM
    }

    func deleteMessages(_ uiMsgs: [TUIMessageCellData]) {
        guard !uiMsgs.isEmpty && uiMsgs.count <= 30 else {
            print("The size of messages must be between 0 and 30")
            return
        }
        messageDataProvider?.deleteUIMsgs(uiMsgs, SuccBlock: {}, FailBlock: { _, _ in
            assertionFailure("deleteMessages failed!")
        })
    }

    func clickTextMessage(_ cell: TUITextMessageCell) {
        guard let message = cell.messageData?.innerMessage, let _ = message.userID else { return }
        TUIMessageDataProvider.callingDataProvider.redialFromMessage(message)
    }

    func clickSystemMessage(_ cell: TUISystemMessageCell) {
        if let data = cell.messageData as? TUISystemMessageCellData, data.supportReEdit {
            delegate?.onReEditMessage(self, data: cell.messageData)
        }
    }

    func playVoiceMessage(_ cell: TUIVoiceMessageCell) {
        for cellData in messageDataProvider?.uiMsgs ?? [] {
            guard let voiceMsg = cellData as? TUIVoiceMessageCellData else {
                continue
            }

            if voiceMsg == cell.voiceData {
                voiceMsg.playVoiceMessage()
                currentVoiceMsg = voiceMsg
                cell.voiceReadPoint.isHidden = true
                var unPlayVoiceMessageAfterSelectVoiceMessage = getCurrentUnPlayVoiceMessageAfterSelectVoiceMessage(voiceMsg)

                voiceMsg.audioPlayerDidFinishPlayingBlock = { [weak self] in
                    guard let self = self else { return }
                    if !unPlayVoiceMessageAfterSelectVoiceMessage.isEmpty {
                        if let nextVoiceCellData = unPlayVoiceMessageAfterSelectVoiceMessage.first,
                           let msgID = nextVoiceCellData.msgID
                        {
                            let nextIndex = self.indexPathOfMessage(msgID) ?? IndexPath()
                            self.scrollCellToBottomOfMessage(msgID)

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let nextCell = self.tableView.cellForRow(at: nextIndex) as? TUIVoiceMessageCell {
                                    self.playVoiceMessage(nextCell)
                                    unPlayVoiceMessageAfterSelectVoiceMessage.removeFirst()
                                } else {
                                    // Retry: avoid nextCell being nil
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        if let retryNextCell = self.tableView.cellForRow(at: nextIndex) as? TUIVoiceMessageCell {
                                            self.playVoiceMessage(retryNextCell)
                                            unPlayVoiceMessageAfterSelectVoiceMessage.removeFirst()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                voiceMsg.stopVoiceMessage()
            }
        }
    }

    func getCurrentUnPlayVoiceMessageAfterSelectVoiceMessage(_ playingCellData: TUIVoiceMessageCellData) -> [TUIVoiceMessageCellData] {
        var neverHitsPlayVoiceQueue = [TUIVoiceMessageCellData]()
        guard let uiMsgs = messageDataProvider?.uiMsgs else { return neverHitsPlayVoiceQueue }

        for cellData in uiMsgs {
            if let voiceMsg = cellData as? TUIVoiceMessageCellData, let msg = voiceMsg.innerMessage {
                if msg.localCustomInt == 0 && voiceMsg.direction == .incoming &&
                    (msg.timestamp?.timeIntervalSince1970 ?? 0) >= (playingCellData.innerMessage?.timestamp?.timeIntervalSince1970 ?? 0)
                {
                    if voiceMsg != playingCellData {
                        neverHitsPlayVoiceQueue.append(voiceMsg)
                    }
                }
            }
        }

        return neverHitsPlayVoiceQueue
    }

    func showImageMessage(_ cell: TUIImageMessageCell) {
        hideKeyboardIfNeeded()
        guard let msg = cell.messageData?.innerMessage else { return }

        let frame = cell.thumb.convert(cell.thumb.bounds, to: TUITool.applicationKeywindow())
        let mediaView = TUIMediaView(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
        mediaView.setThumb(cell.thumb, frame: frame)
        mediaView.setCurMessage(msg)
        mediaView.onClose = { [weak self] in
            guard let self else { return }
            self.didCloseMediaMessage(cell)
        }
        willShowMediaMessage(cell)
        TUITool.applicationKeywindow()?.addSubview(mediaView)
    }

    func showVideoMessage(_ cell: TUIVideoMessageCell) {
        if !(cell.videoData?.isVideoExist() ?? false) {
            cell.videoData?.downloadVideo()
        } else {
            hideKeyboardIfNeeded()
            guard let msg = cell.messageData?.innerMessage else { return }

            let frame = cell.thumb.convert(cell.thumb.bounds, to: TUITool.applicationKeywindow())
            let mediaView = TUIMediaView(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
            mediaView.setThumb(cell.thumb, frame: frame)
            mediaView.setCurMessage(msg)
            mediaView.onClose = { [weak self] in
                self?.didCloseMediaMessage(cell)
            }
            willShowMediaMessage(cell)
            TUITool.applicationKeywindow()?.addSubview(mediaView)
        }
    }

    func showFileMessage(_ cell: TUIFileMessageCell) {
        hideKeyboardIfNeeded()
        if let fileData = cell.fileData, !fileData.isLocalExist() {
            fileData.downloadFile()
            return
        }

        let fileVC = TUIFileViewController()
        fileVC.data = cell.fileData
        navigationController?.pushViewController(fileVC, animated: true)
    }

    func showRelayMessage(_ cell: TUIMergeMessageCell) {
        let mergeVC = TUIMergeMessageListController()
        mergeVC.delegate = delegate
        if let mergerElem = cell.mergeData?.mergerElem {
            mergeVC.mergerElem = mergerElem
        }
        if let conversationData = conversationData {
            mergeVC.conversationData = conversationData
        }
        if let messageDataProvider = messageDataProvider {
            mergeVC.parentPageDataProvider = messageDataProvider
        }

        mergeVC.willCloseCallback = { [weak self] in
            guard let self else { return }
            self.tableView.reloadData()
        }
        navigationController?.pushViewController(mergeVC, animated: true)
    }

    func showLinkMessage(_ cell: TUILinkCell) {
        guard let link = cell.customData?.link else { return }
        if link.count > 0 {
            if let url = URL(string: link) {
                TUITool.openLink(with: url)
            }
        }
    }

    func showOrderMessage(_ cell: TUIOrderCell) {
        guard let link = cell.customData?.link else { return }
        if link.count > 0 {
            if let url = URL(string: link) {
                TUITool.openLink(with: url)
            }
        }
    }

    func showReplyMessage<T: TUIBubbleMessageCell>(_ cell: T) {
        // subclass override
    }

    func showReferenceMessage(_ cell: TUIReferenceMessageCell) {
        // subclass override
    }

    func willShowMediaMessage(_ cell: TUIMessageCell) {
        // subclass override
    }

    func didCloseMediaMessage(_ cell: TUIMessageCell) {
        // subclass override
    }

    func onDeleteMessage(_ cell: TUIMessageCell) {
        // subclass override
    }

    func isCurrentUserRoleSuperAdminInGroup() -> Bool {
        return messageDataProvider?.isCurrentUserRoleSuperAdminInGroup() ?? false
    }

    func isCurrentMessagePin(_ msgID: String) -> Bool {
        return messageDataProvider?.isCurrentMessagePin(msgID) ?? false
    }

    func unPinGroupMessage(_ innerMessage: V2TIMMessage) {
        guard let groupId = conversationData?.groupID else { return }
        let isPinned = isCurrentMessagePin(innerMessage.msgID ?? "")
        let pinOrUnpin = !isPinned

        messageDataProvider?.pinGroupMessage(groupId, message: innerMessage, isPinned: pinOrUnpin, succ: {}, fail: { _, _ in
        })
    }

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if #available(iOS 16.0, *) {
            // Send reload view notification
            NotificationCenter.default.post(name: NSNotification.Name(TUIMessageMediaViewDeviceOrientationChangeNotification), object: nil)
        } else {
            // Fallback on earlier versions
        }
    }

    // MARK: - AI Typing Message Management

    func createAITypingMessage() {
        // Check and remove any existing AI placeholder typing message first
        if let conversationID = conversationData?.conversationID {
            if let currentAITypingMessage = TUIAIPlaceholderTypingMessageManager.shared.getAIPlaceholderTypingMessage(forConversation: conversationID) {
                // Find the index of the existing AI typing message
                if let aiTypingIndex = messageDataProvider?.uiMsgs.firstIndex(of: currentAITypingMessage) {
                    // Remove the existing AI typing placeholder message
                    messageDataProvider?.dataSource?.dataProviderDataSourceWillChange(messageDataProvider!)
                    messageDataProvider?.removeUIMsg(currentAITypingMessage)
                    messageDataProvider?.dataSource?.dataProviderDataSourceChange(messageDataProvider!, withType: .delete, atIndex: UInt(aiTypingIndex), animation: true)
                    messageDataProvider?.dataSource?.dataProviderDataSourceDidChange(messageDataProvider!)
                }
                
                // Remove from manager
                TUIAIPlaceholderTypingMessageManager.shared.removeAIPlaceholderTypingMessage(forConversation: conversationID)
            }
        }
        
        // Create AI typing placeholder message using TUIChatbotMessagePlaceholderCellData
        let aiTypingData = TUIChatbotMessagePlaceholderCellData.createAIPlaceholderCellData()

        // Send as placeholder message
        sendPlaceHolderUIMessage(aiTypingData)

        // Store reference in global manager for later replacement
        if let conversationID = conversationData?.conversationID {
            TUIAIPlaceholderTypingMessageManager.shared.setAIPlaceholderTypingMessage(aiTypingData, forConversation: conversationID)
        }

        // Note: AI typing message will be automatically removed when real AI response is received
        // via onRecvNewMessage in TUIMessageBaseDataProvider
    }

    func restoreAITypingMessageIfNeeded() {
        guard let lastObj = messageDataProvider?.uiMsgs.last,
              let conversationID = conversationData?.conversationID else { return }

        if TUIAIPlaceholderTypingMessageManager.shared.hasAIPlaceholderTypingMessage(forConversation: conversationID) {
            if let existingAIPlaceHolderMessage = TUIAIPlaceholderTypingMessageManager.shared.getAIPlaceholderTypingMessage(forConversation: conversationID) {
                let lastObjisTUIChatbotMessageCellData = lastObj is TUIChatbotMessageCellData
                let isSuccess = lastObj.status != .fail

                if !lastObjisTUIChatbotMessageCellData && isSuccess {
                    // Add the existing AI typing message to current message list
                    sendPlaceHolderUIMessage(existingAIPlaceHolderMessage)
                } else {
                    TUIAIPlaceholderTypingMessageManager.shared.removeAIPlaceholderTypingMessage(forConversation: conversationID)
                }
            }
        }
    }

    /// Handle AI conversation long press - only show copy, forward, delete options for AI conversations
    private func handleAIConversationLongPress(_ cell: TUIMessageCell) {
        guard let data = cell.messageData else { return }

        // Create menu without emoji view for AI conversations
        let menu = TUIChatPopMenu(hasEmojiView: false, frame: .zero)
        chatPopMenu = menu
        menu.targetCellData = data
        menu.targetCell = cell

        // Add AI-specific actions (only copy, forward, delete)
        addChatAIActionToCell(cell, ofMenu: menu)

        // Setup menu position and display
        if let keyWindow = TUITool.applicationKeywindow() {
            let frame = keyWindow.convert(cell.container.frame, from: cell)

            var topMarginByCustomView: CGFloat = 0
            if let topMargin = delegate?.getTopMarginByCustomView() {
                topMarginByCustomView = topMargin
            }

            menu.setArrawPosition(
                CGPoint(x: frame.origin.x + frame.size.width * 0.5, y: frame.origin.y - 5 - topMarginByCustomView),
                adjustHeight: frame.size.height + 5
            )
            menu.showInView(tableView)
        }
    }

    /// Add AI-specific actions to menu (copy, forward, delete only)
    private func addChatAIActionToCell(_ cell: TUIMessageCell, ofMenu menu: TUIChatPopMenu) {
        // Setup popAction
        let copyAction = setupCopyAction(cell)
        let forwardAction = setupForwardAction(cell)
        let deleteAction = setupDeleteAction(cell)

        let data = cell.messageData
        guard let imMsg = data?.innerMessage else { return }

        let isMsgSendSucceed = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isContentModerated = imMsg.hasRiskContent

        // Add copy action for text-based messages without risk content
        if let copyAction = copyAction,
           data is TUITextMessageCellData || data is TUIReplyMessageCellData || data is TUIReferenceMessageCellData,
           !isContentModerated
        {
            menu.addAction(copyAction)
        }

        // Add delete action
        if let deleteAction = deleteAction {
            menu.addAction(deleteAction)
        }

        // Add forward action for successful messages without risk content
        if let forwardAction = forwardAction,
           let data = data,
           canForward(data),
           isMsgSendSucceed,
           !isContentModerated
        {
            menu.addAction(forwardAction)
        }
    }
}
