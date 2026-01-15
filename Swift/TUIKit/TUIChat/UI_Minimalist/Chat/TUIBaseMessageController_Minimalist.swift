import ImSDK_Plus
import TIMCommon
import TUICore
import UIKit

public class TUIBaseMessageController_Minimalist: UITableViewController, TUIMessageCellDelegate, TUIJoinGroupMessageCellDelegate_Minimalist, TUIMessageProgressManagerDelegate, TUIMessageDataProviderDataSource, TIMPopActionProtocol, TUINotificationProtocol {
    var groupRoleChanged: ((V2TIMGroupMemberRole) -> Void)?
    var pinGroupMessageChanged: (([V2TIMMessage]) -> Void)?
    weak var delegate: TUIBaseMessageControllerDelegate_Minimalist?
    var isInVC: Bool = false
    var isMsgNeedReadReceipt: Bool = false

    var messageDataProvider: TUIMessageDataProvider?
    var menuUIMsg: TUIMessageCellData?
    var reSendUIMsg: TUIMessageCellData?
    var conversationData: TUIChatConversationModel?
    var indicatorView: UIActivityIndicatorView?
    var isActive: Bool = false
    var showCheckBox: Bool = false
    var scrollingTriggeredByUser: Bool = false
    var isAutoScrolledToBottom: Bool = false
    var hasCoverPage: Bool = false
    var popAlertController: TUIChatPopContextController?
    
    // MARK: - AI Streaming Callback
    var steamCellFinishedBlock: ((Bool, TUIMessageCellData) -> Void)?

    lazy var messageCellConfig: TUIMessageCellConfig_Minimalist = {
        let config = TUIMessageCellConfig_Minimalist()
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
        TUIBaseMessageController_Minimalist.setupDataSource(type(of: self))
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
        NotificationCenter.default.addObserver(self, selector: #selector(onAutoPlayVoiceMessageRequest(_:)), name: NSNotification.Name("TUIChat_AutoPlayVoiceMessage"), object: nil)
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
        }, FailBlock: { [weak self] code, desc in
            guard let self = self else { return }
            self.reloadUIMessage(cellData)
            self.setUIMessageStatus(cellData, status: .fail)
            self.makeSendErrorHud(Int(code), desc: desc ?? "")
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
        default:
            break
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
            sendUIMessage(cellData)
        }
    }

    func reloadUIMessage(_ msg: TUIMessageCellData) {
        guard let messageDataProvider = messageDataProvider else { return }

        if let index = messageDataProvider.uiMsgs.firstIndex(of: msg), let message = msg.innerMessage {
            let newUIMsgs = messageDataProvider.transUIMsgFromIMMsg([message])
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

    @objc func onReceivedSendMessageRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }

        let message = userInfo["message"] as? V2TIMMessage
        let cellData = userInfo["placeHolderCellData"] as? TUIMessageCellData

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

        guard let message = userInfo["message"] as? V2TIMMessage else {
            return
        }

        let param = TUISendMessageAppendParams()
        param.isOnlineUserOnly = true

        if let conversation = conversationData {
            _ = TUIMessageDataProvider.sendMessage(message, toConversation: conversation, appendParams: param, Progress: nil, SuccBlock: {
                print("send message without updating UI succeed")
            }, FailBlock: { code, desc in
                print("send message without updating UI failed, code: \(code), desc: \(desc ?? "")")
            })
        }
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
                    
                    if let msgID = data.innerMessage?.msgID {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self,
                                  let indexPath = self.indexPathOfMessage(msgID),
                                  let textCell = self.tableView.cellForRow(at: indexPath) as? TUITextMessageCell_Minimalist
                            else {
                                return
                            }
                            textCell.animateOriginalTextVisibilityIfNeeded(animated: true)
                        }
                    }
                    
                    break
                }
            }
        }
        else if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_DidChangePluginViewSubKey" {
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
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self,
                          let indexPath = self.indexPathOfMessage(msgID),
                          let textCell = self.tableView.cellForRow(at: indexPath) as? TUITextMessageCell_Minimalist
                    else {
                        return
                    }
                    textCell.animateOriginalTextVisibilityIfNeeded(animated: true)
                }
            }
        }
        if key == "TUICore_TUIPluginNotify" && subKey == "TUICore_TUIPluginNotify_WillForwardTextSubKey" {
            guard let text = param?["TUICore_TUIPluginNotify_WillForwardTextSubKey_Text"] as? String else { return }
            delegate?.onForwardText(self, text: text)
        }
    }

    func clearAndReloadCellOfData(_ data: TUIMessageCellData) {
        messageCellConfig.removeHeightCacheOfMessageCellData(data)
        if let msgID = data.innerMessage?.msgID {
            reloadAndScrollToBottomOfMessage(msgID)
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
        return TUIMessageCellConfig_Minimalist.getCustomMessageCellDataClass(businessID)
    }

    private static var lastMsgIndexs: [Int]?
    private static var reloadMsgIndexs: [Int]?

    func isDataSourceConsistent() -> Bool {
        let dataSourceCount = messageDataProvider?.uiMsgs.count ?? 0
        let tableViewCount = tableView.numberOfRows(inSection: 0)

        if dataSourceCount != tableViewCount {
            print("Data source and UI are inconsistent: Data source count = \(dataSourceCount), Table view count = \(tableViewCount)")
            return false
        }
        return true
    }

    func dataProviderDataSourceWillChange(_ dataProvider: TUIMessageBaseDataProvider) {
        // Disable all animations during table view updates to prevent cell reuse glitches
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation {
            tableView.beginUpdates()
        }
        CATransaction.commit()

        if TUIBaseMessageController_Minimalist.lastMsgIndexs != nil {
            TUIBaseMessageController_Minimalist.lastMsgIndexs?.removeAll()
        } else {
            TUIBaseMessageController_Minimalist.lastMsgIndexs = []
        }

        if TUIBaseMessageController_Minimalist.reloadMsgIndexs != nil {
            TUIBaseMessageController_Minimalist.reloadMsgIndexs?.removeAll()
        } else {
            TUIBaseMessageController_Minimalist.reloadMsgIndexs = []
        }
    }

    func dataProviderDataSourceChange(_ dataProvider: TUIMessageBaseDataProvider, withType type: TUIMessageBaseDataProviderDataSourceChangeType, atIndex index: UInt, animation: Bool) {
        // insert or delete or reload current cell
        TUIBaseMessageController_Minimalist.reloadMsgIndexs?.append(Int(index))
        let indexPaths = [IndexPath(row: Int(index), section: 0)]
        
        // Disable implicit animations to prevent cell reuse animation glitches
        // (e.g., avatar/bubble sliding from previous cell position)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation {
            switch type {
            case .insert:
                tableView.insertRows(at: indexPaths, with: .none)
            case .delete:
                tableView.deleteRows(at: indexPaths, with: animation ? .fade : .none)
            case .reload:
                tableView.reloadRows(at: indexPaths, with: .none)
            default:
                break
            }
        }
        CATransaction.commit()

        // remove cache index
        if let indexPosition = TUIBaseMessageController_Minimalist.lastMsgIndexs?.firstIndex(of: Int(index)) {
            TUIBaseMessageController_Minimalist.lastMsgIndexs?.remove(at: indexPosition)
        }

        // reload last cell
        if index >= 1, TUIBaseMessageController_Minimalist.reloadMsgIndexs?.firstIndex(of: Int(index) - 1) == nil {
            TUIBaseMessageController_Minimalist.lastMsgIndexs?.append(Int(index) - 1)
        }
    }

    func dataProviderDataSourceDidChange(_ dataProvider: TUIMessageBaseDataProvider) {
        // Disable implicit animations to prevent cell reuse animation glitches
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation {
            for index in TUIBaseMessageController_Minimalist.lastMsgIndexs ?? [] {
                let indexPath = IndexPath(row: index, section: 0)
                if let uiMsgs = messageDataProvider?.uiMsgs, indexPath.row < 0 || indexPath.row >= uiMsgs.count {
                    break
                }
                if let cellData = messageDataProvider?.uiMsgs[indexPath.row] as? TUIMessageCellData {
                    messageCellConfig.removeHeightCacheOfMessageCellData(cellData)
                    tableView.reloadRows(at: [indexPath], with: .none)
                }
            }
            tableView.endUpdates()
        }
        CATransaction.commit()
        TUIBaseMessageController_Minimalist.lastMsgIndexs?.removeAll()
        TUIBaseMessageController_Minimalist.reloadMsgIndexs?.removeAll()
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
            if let cell = tableView.cellForRow(at: indexPath) as? TUIMessageCell {
                if let msgTime = cell.messageData?.innerMessage?.timestamp?.timeIntervalSince1970, msgTime <= Double(timestamp) && cell.readReceiptLabel.text != TUISwift.timCommonLocalizableString("Read") {
                    cell.readReceiptLabel.text = TUISwift.timCommonLocalizableString("Read")
                }
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
        if currentTimestamp - TUIBaseMessageController_Minimalist.lastTimestamp >= 1 && TUIBaseMessageController_Minimalist.lastTimestamp != 0 {
            TUIBaseMessageController_Minimalist.lastTimestamp = currentTimestamp
            readReport()
        } else {
            if TUIBaseMessageController_Minimalist.delayReport {
                return
            }
            TUIBaseMessageController_Minimalist.delayReport = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.readReport()
                TUIBaseMessageController_Minimalist.delayReport = false
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
        cell?.delegate = self
        
        // Disable Core Animation implicit animations to prevent cell reuse glitches
        // (e.g., avatar/bubble sliding from previous cell position when receiving new messages)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        cell?.fill(with: data)
        cell?.notifyBottomContainerReady(of: nil)
        cell?.notifyTopContainerReady(of: nil)
        cell?.layoutIfNeeded()
        CATransaction.commit()
        
        return cell!
    }

    override public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.layer.zPosition = CGFloat(indexPath.row)
        
        // Remove any pending animations on the cell to prevent "falling" effect from cell reuse
        cell.layer.removeAllAnimations()
        cell.contentView.layer.removeAllAnimations()
        for subview in cell.contentView.subviews {
            subview.layer.removeAllAnimations()
        }
        
        guard let messageCell = cell as? TUIMessageCell, let data = messageCell.messageData else { return }
        delegate?.willDisplayCell(self, cell: messageCell, withData: data)
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
        if let data = cell.messageData,
           let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onMessageClicked(cell, messageCellData: data), result == true { return }

        if (cell.messageData?.innerMessage?.hasRiskContent ?? false) && !(cell is TUIReferenceMessageCell_Minimalist) {
            return
        }

        if let data = cell.data as? TUIMessageCellData {
            if showCheckBox && supportCheckBox(data) {
                data.selected = !data.selected
                tableView.reloadData()
                delegate?.onSelectMessageWhenMultiCheckboxAppear(self, data: data)
                return
            }
        }

        hideKeyboardIfNeeded()

        switch cell {
        case let textCell as TUITextMessageCell_Minimalist:
            clickTextMessage(textCell)
        case let systemCell as TUISystemMessageCell:
            clickSystemMessage(systemCell)
        case let voiceCell as TUIVoiceMessageCell_Minimalist:
            playVoiceMessage(voiceCell)
        case let imageCell as TUIImageMessageCell_Minimalist:
            showImageMessage(imageCell)
        case let videoCell as TUIVideoMessageCell_Minimalist:
            showVideoMessage(videoCell)
        case let fileCell as TUIFileMessageCell_Minimalist:
            showFileMessage(fileCell)
        case let mergeCell as TUIMergeMessageCell_Minimalist:
            showRelayMessage(mergeCell)
        case let linkCell as TUILinkCell_Minimalist:
            showLinkMessage(linkCell)
        case let replyCell as TUIReplyMessageCell_Minimalist:
            showReplyMessage(replyCell)
        case let referenceCell as TUIReferenceMessageCell_Minimalist:
            showReplyMessage(referenceCell)
        case let orderCell as TUIOrderCell_Minimalist:
            showOrderMessage(orderCell)
        default:
            break
        }

        delegate?.onSelectMessageContent(self, cell: cell)
    }

    func showContextWindow(_ cell: TUIMessageCell) {
        let alertController = TUIChatPopContextController()
        alertController.alertViewCellData = cell.messageData
        if let frame = TUITool.applicationKeywindow()?.convert(cell.container.frame, from: cell) {
            alertController.originFrame = frame
        }
        alertController.alertCellClass = type(of: cell)
        if let view = navigationController?.view {
            alertController.setBlurEffect(with: view)
        }
        configItems(alertController, targetCell: cell)
        alertController.viewWillShowHandler = { [weak self] alertView in
            guard let self else { return }
            alertView.delegate = self
        }
        alertController.dismissComplete = { [weak cell] in
            guard let cell else { return }
            cell.container.isHidden = false
        }
        navigationController?.present(alertController, animated: false, completion: nil)
        popAlertController = alertController
    }

    func configItems(_ alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) {
        /*
         Sort priorities: copy, forward, multiselect, reference, reply, recall, delete
         The higher the weight, the more prioritized it is:
             Copy - 10000
             Forward - 9000
             Select - 8000
             Quote - 7000
             Reply - 5000
             Recall - 3000
             Details - 2000
             Delete - 1000
         */
        var items = [TUIChatPopContextExtensionItem]()
        addNormalItemToItems(&items, cell: cell, alertController: alertController)
        addExtraItemToItems(&items, cell: cell, alertController: alertController)

        var sortedItems = sortItems(&items)
        let allPageItemsArray = pageItems(&sortedItems, inAlertController: alertController)
        if !allPageItemsArray.isEmpty {
            alertController.items = allPageItemsArray[0]
        }
    }

    func addNormalItemToItems(_ items: inout [TUIChatPopContextExtensionItem], cell: TUIMessageCell, alertController: TUIChatPopContextController) {
        var isPluginCustomMessage = false
        if let data = cell.messageData {
            isPluginCustomMessage = TUIMessageCellConfig_Minimalist.isPluginCustomMessageCellData(data)
        }
        if isPluginCustomMessage {
            addPluginCustomMessageItemToItems(&items, cell: cell, alertController: alertController)
            return
        }
        addNomalMessageItemToItems(&items, cell: cell, alertController: alertController)
    }

    func addPluginCustomMessageItemToItems(_ items: inout [TUIChatPopContextExtensionItem], cell: TUIMessageCell, alertController: TUIChatPopContextController) {
        let imMsg: V2TIMMessage? = cell.messageData?.innerMessage
        // Plugin build-in custom messsages, support actions: multiSelect, reference, reply, delete, recall.
        if isAddMultiSelect(imMsg) {
            items.append(setupMultiSelectAction(for: alertController, targetCell: cell))
        }
        if isAddReply(imMsg) {
            items.append(setupReplyAction(for: alertController, targetCell: cell))
        }
        if isAddQuote(imMsg) {
            items.append(setupReferenceAction(for: alertController, targetCell: cell))
        }
        if isAddDelete() {
            items.append(setupDeleteAction(for: alertController, targetCell: cell))
        }
        if isAddRecall(imMsg) {
            items.append(setupRecallAction(for: alertController, targetCell: cell))
        }
    }

    func addNomalMessageItemToItems(_ items: inout [TUIChatPopContextExtensionItem], cell: TUIMessageCell, alertController: TUIChatPopContextController) {
        let imMsg: V2TIMMessage? = cell.messageData?.innerMessage
        // 普通消息。
        if imMsg?.soundElem != nil {
            items.append(setupAudioPlaybackStyleAction(for: alertController, targetCell: cell))
        }
        if let data = cell.messageData, isAddCopy(imMsg, data: data) {
            items.append(setupCopyAction(for: alertController, targetCell: cell))
        }
        if isAddForward(imMsg) {
            items.append(setupForwardAction(for: alertController, targetCell: cell))
        }
        if isAddMultiSelect(imMsg) {
            items.append(setupMultiSelectAction(for: alertController, targetCell: cell))
        }
        if isAddQuote(imMsg) {
            items.append(setupReferenceAction(for: alertController, targetCell: cell))
        }
        if isAddReply(imMsg) {
            items.append(setupReplyAction(for: alertController, targetCell: cell))
        }
        if isAddRecall(imMsg) {
            items.append(setupRecallAction(for: alertController, targetCell: cell))
        }
        if isAddInfo(imMsg) {
            items.append(setupInfoAction(for: alertController, targetCell: cell))
        }
        if isAddDelete() {
            items.append(setupDeleteAction(for: alertController, targetCell: cell))
        }
        if isAddPin(imMsg) {
            items.append(setupGroupPinAction(for: alertController, targetCell: cell))
        }
    }

    func isAddDelete() -> Bool {
        return TUIChatConfig.shared.enablePopMenuDeleteAction
    }

    func isAddCopy(_ imMsg: V2TIMMessage?, data: TUIMessageCellData) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isCopyShown = TUIChatConfig.shared.enablePopMenuCopyAction
        let isContentModerated = imMsg.hasRiskContent
        return isCopyShown && (data is TUITextMessageCellData || data is TUIReferenceMessageCellData) && !isContentModerated
    }

    func isAddMultiSelect(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isSelectShown = TUIChatConfig.shared.enablePopMenuSelectAction
        let isContentModerated = imMsg.hasRiskContent
        return isSelectShown && !isContentModerated
    }

    func isAddReply(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isReplyShown = TUIChatConfig.shared.enablePopMenuReplyAction
        let isMsgSentSucceeded = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isContentModerated = imMsg.hasRiskContent
        return isReplyShown && isMsgSentSucceeded && !isContentModerated
    }

    func isAddRecall(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isMyselfMsgSender = imMsg.isSelf
        let isRecallSupported = Date().timeIntervalSince(imMsg.timestamp ?? Date()) < Double(TUIChatConfig.shared.timeIntervalForMessageRecall)
        let isMsgSentSucceeded = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isRecallShown = TUIChatConfig.shared.enablePopMenuRecallAction
        return isMyselfMsgSender && isRecallSupported && isMsgSentSucceeded && isRecallShown
    }

    func isAddQuote(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isQuoteShown = TUIChatConfig.shared.enablePopMenuReferenceAction
        let isMsgSentSucceeded = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isContentModerated = imMsg.hasRiskContent
        return isQuoteShown && isMsgSentSucceeded && !isContentModerated
    }

    func isAddForward(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isForwardShown = TUIChatConfig.shared.enablePopMenuForwardAction
        let isMsgSentSucceeded = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isContentModerated = imMsg.hasRiskContent
        return isForwardShown && isMsgSentSucceeded && !isContentModerated
    }

    func isAddPin(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isGroup = !(imMsg.groupID?.isEmpty ?? true)
        let isCurrentUserSuperAdmin = messageDataProvider?.isCurrentUserRoleSuperAdminInGroup() ?? false
        let isMsgSentSucceeded = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isPinShown = TUIChatConfig.shared.enablePopMenuPinAction
        let isContentModerated = imMsg.hasRiskContent
        return isGroup && isCurrentUserSuperAdmin && isMsgSentSucceeded && isPinShown && !isContentModerated
    }

    func isAddInfo(_ imMsg: V2TIMMessage?) -> Bool {
        guard let imMsg = imMsg else { return false }
        let isMyselfMsgSender = imMsg.isSelf
        let isMsgSentSucceeded = imMsg.status == .MSG_STATUS_SEND_SUCC
        let isInfoShown = TUIChatConfig.shared.enablePopMenuInfoAction
        return isMyselfMsgSender && isMsgSentSucceeded && isInfoShown
    }

    func addExtraItemToItems(_ items: inout [TUIChatPopContextExtensionItem], cell: TUIMessageCell, alertController: TUIChatPopContextController) {
        let infoArray = TUICore.getExtensionList("TUICore_TUIChatExtension_PopMenuActionItem_MinimalistExtensionID", param: ["TUICore_TUIChatExtension_PopMenuActionItem_TargetVC": self, "TUICore_TUIChatExtension_PopMenuActionItem_ClickCell": cell])
        for info in infoArray {
            if let text = info.text, let icon = info.icon, let onClicked = info.onClicked {
                let item = TUIChatPopContextExtensionItem(title: text, markIcon: icon, weight: info.weight) { [weak alertController] _ in
                    alertController?.blurDismissViewController(animated: false, completion: { _ in
                        onClicked([:])
                    })
                }
                items.append(item)
            }
        }
    }

    func sortItems(_ items: inout [TUIChatPopContextExtensionItem]) -> [TUIChatPopContextExtensionItem] {
        return items.sorted { $0.weight > $1.weight }
    }

    func pageItems(_ items: inout [TUIChatPopContextExtensionItem], inAlertController alertController: TUIChatPopContextController) -> [[TUIChatPopContextExtensionItem]] {
        let perPageLimitedCount = 4
        var itemsRemaining = items.count
        var j = 0
        var allPageItemsArray: [[TUIChatPopContextExtensionItem]] = []
        while itemsRemaining > 0 {
            let range = j..<j + min(perPageLimitedCount, itemsRemaining)
            let subLogArr = Array(items[range])
            let lastItem = subLogArr.last
            lastItem?.needBottomLine = true

            allPageItemsArray.append(subLogArr)
            let rangeLength = range.upperBound - range.lowerBound
            itemsRemaining -= rangeLength
            j += rangeLength
        }

        if allPageItemsArray.count != 1 {
            // more than one
            let lastPagedIndex = allPageItemsArray.count - 1
            for pageIndex in 0..<allPageItemsArray.count {
                let nextPageIndex = (pageIndex == lastPagedIndex) ? 0 : pageIndex + 1
                let moreItem = TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("More"), markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_more")), weight: Int.max, actionHandler: { [weak alertController] _ in
                    let nextPageItems = allPageItemsArray[nextPageIndex]
                    alertController?.items = nextPageItems
                    alertController?.updateExtensionView()
                })
                moreItem.titleColor = UIColor.tui_color(withHex: "147AFF")
                allPageItemsArray[pageIndex].append(moreItem)
            }
        } else {
            // only one
            let items = allPageItemsArray[0]
            items.last?.needBottomLine = false
        }
        return allPageItemsArray
    }

    // MARK: - TUIMessageCellDelegate

    public func onLongPressMessage(_ cell: TUIMessageCell) {
        if let data = cell.messageData,
           let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onMessageLongClicked(cell, messageCellData: data), result == true { return }


        guard !(cell.messageData is TUISystemMessageCellData) else { return }
        menuUIMsg = cell.messageData
        
        // Handle AI conversation long press
        if let conversationData = conversationData, conversationData.isAIConversation() {
            handleAIConversationLongPress(cell)
            return
        }
        
        showContextWindow(cell)
    }

    public func onLongSelectMessageAvatar(_ cell: TUIMessageCell) {
        if let data = cell.messageData,
           let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onUserIconLongClicked(cell, messageCellData: data), result == true { return }

        delegate?.onLongSelectMessageAvatar(self, cell: cell)
    }

    public func onRetryMessage(_ cell: TUIMessageCell) {
        guard let resendMsg = cell.messageData else { return }
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
        if let data = cell.messageData,
           let result = TUIChatConfig.shared.eventConfig.chatEventListener?.onUserIconClicked(cell, messageCellData: data), result == true { return }

        delegate?.onSelectMessageAvatar(self, cell: cell)
    }

    public func onSelectReadReceipt(_ cell: TUIMessageCellData) {
        // AI conversations don't support read receipts
        if let conversationData = conversationData, conversationData.isAIConversation() {
            return
        }
        
        // Minimalist version currently doesn't implement read receipt detail view
        // This method is kept for consistency with Classic version
    }

    public func onJumpToRepliesDetailPage(_ data: TUIMessageCellData) {
        guard let msg = data.innerMessage,
              let messageDataProvider = messageDataProvider,
              let copyData = TUIMessageDataProvider.convertToCellData(from: msg),
              let conversationData = conversationData else { return }
        messageDataProvider.preProcessMessage([copyData]) {
            DispatchQueue.main.async {
                let cell = TUIMessageCell()
                cell.fill(with: copyData)

                let repliesDetailVC = TUIRepliesDetailViewController_Minimalist(cellData: copyData, conversationData: conversationData)
                repliesDetailVC.delegate = self.delegate
                repliesDetailVC.modalPresentationStyle = .custom

                self.navigationController?.present(repliesDetailVC, animated: true, completion: nil)
                self.hasCoverPage = true
                repliesDetailVC.parentPageDataProvider = messageDataProvider
                repliesDetailVC.willCloseCallback = { [weak self] in
                    guard let self else { return }
                    self.hasCoverPage = false
                    tableView.reloadData()
                }
            }
        }
    }

    public func onJumpToMessageInfoPage(_ data: TUIMessageCellData, selectCell: TUIMessageCell) {
        guard let msg = selectCell.messageData?.innerMessage,
              let alertViewCellData = TUIMessageDataProvider.convertToCellData(from: msg) else { return }
        messageDataProvider?.preProcessMessage([alertViewCellData]) { [weak self] in
            guard let self else { return }
            let readViewController = TUIMessageReadViewController_Minimalist(cellData: data, dataProvider: self.messageDataProvider, showReadStatusDisable: false, c2cReceiverName: self.conversationData?.title, c2cReceiverAvatar: self.conversationData?.faceUrl)
            readViewController.originFrame = selectCell.frame
            readViewController.alertCellClass = selectCell.classForCoder
            readViewController.viewWillShowHandler = { alertView in
                alertView?.delegate = self
            }
            readViewController.viewWillDismissHandler = { _ in
                self.hasCoverPage = false
            }
            readViewController.alertViewCellData = alertViewCellData
            self.hasCoverPage = true
            self.navigationController?.pushViewController(readViewController, animated: true)
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

    func menuDidHide(_ notification: Notification) {
        delegate?.didHideMenu(self)
        NotificationCenter.default.removeObserver(self, name: UIMenuController.didHideMenuNotification, object: nil)
    }

    // MARK: - TIMPopActionProtocol

    @objc public func onDelete(_ sender: Any?) {
        if let cell = sender as? TUIMessageCell {
            onDeleteMessage(cell)
        }
    }

    @objc public func onCopyMsg(_ sender: Any?) {
        var content = ""
        if let txtCell = sender as? TUITextMessageCell_Minimalist {
            content = txtCell.textData?.content ?? ""
        } else if let replyMsgCell = sender as? TUIReferenceMessageCell_Minimalist, let replyMsg = replyMsgCell.data as? TUIReferenceMessageCellData {
            content = replyMsg.content
        }
        if !content.isEmpty {
            UIPasteboard.general.string = content
            TUITool.makeToast(TUISwift.timCommonLocalizableString("Copied"))
        }
    }

    @objc public func onRevoke(_ sender: Any?) {
        guard let menuUIMsg = menuUIMsg else { return }
        messageDataProvider?.revokeUIMsg(menuUIMsg, SuccBlock: { [weak self] in
            guard let self else { return }
            self.delegate?.didHideMenu(self)
        }, FailBlock: { _, desc in
            assertionFailure(desc ?? "")
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
        messageDataProvider?.deleteUIMsgs(uiMsgs, SuccBlock: {}, FailBlock: { _, _ in
            assertionFailure("deleteMessages failed!")
        })
    }

    func clickTextMessage(_ cell: TUITextMessageCell_Minimalist) {
        guard let message = cell.messageData?.innerMessage, let _ = message.userID else { return }
        TUIMessageDataProvider.callingDataProvider.redialFromMessage(message)
    }

    func clickSystemMessage(_ cell: TUISystemMessageCell) {
        if let data = cell.messageData as? TUISystemMessageCellData, data.supportReEdit {
            delegate?.onReEditMessage(self, data: cell.messageData)
        }
    }

    func playVoiceMessage(_ cell: TUIVoiceMessageCell_Minimalist) {
        guard let messageDataProvider = messageDataProvider else { return }
        for cellData in messageDataProvider.uiMsgs {
            if let voiceMsg = cellData as? TUIVoiceMessageCellData, voiceMsg == cell.voiceData {
                voiceMsg.playVoiceMessage()
                cell.voiceReadPoint.isHidden = true
            } else if let voiceMsg = cellData as? TUIVoiceMessageCellData {
                voiceMsg.stopVoiceMessage()
            }
        }
    }

    @objc func onAutoPlayVoiceMessageRequest(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let msgID = userInfo["msgID"] as? String else {
            return
        }
        
        // Find the cell for this message and play it
        guard let indexPath = indexPathOfMessage(msgID),
              let cell = tableView.cellForRow(at: indexPath) as? TUIVoiceMessageCell_Minimalist else {
            // Cell not visible, scroll to it first then play
            scrollCellToBottomOfMessage(msgID)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self,
                      let retryIndexPath = self.indexPathOfMessage(msgID),
                      let retryCell = self.tableView.cellForRow(at: retryIndexPath) as? TUIVoiceMessageCell_Minimalist else {
                    // Notify that play failed (cell not found)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("TUIChat_AutoPlayVoiceMessageResult"),
                        object: nil,
                        userInfo: ["msgID": msgID, "success": false]
                    )
                    return
                }
                self.playVoiceMessage(retryCell)
                NotificationCenter.default.post(
                    name: NSNotification.Name("TUIChat_AutoPlayVoiceMessageResult"),
                    object: nil,
                    userInfo: ["msgID": msgID, "success": true]
                )
            }
            return
        }
        
        playVoiceMessage(cell)
        NotificationCenter.default.post(
            name: NSNotification.Name("TUIChat_AutoPlayVoiceMessageResult"),
            object: nil,
            userInfo: ["msgID": msgID, "success": true]
        )
    }

    func showImageMessage(_ cell: TUIImageMessageCell_Minimalist) {
        hideKeyboardIfNeeded()
        guard let msg = cell.messageData?.innerMessage else { return }
        let frame = cell.thumb.convert(cell.thumb.bounds, to: TUITool.applicationKeywindow())
        let mediaView = TUIMediaView_Minimalist(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
        mediaView.setThumb(cell.thumb, frame: frame)
        mediaView.setCurMessage(msg)
        mediaView.onClose = { [weak self] in
            guard let self else { return }
            self.didCloseMediaMessage(cell)
        }
        willShowMediaMessage(cell)
        TUITool.applicationKeywindow()?.addSubview(mediaView)
    }

    func showVideoMessage(_ cell: TUIVideoMessageCell_Minimalist) {
        hideKeyboardIfNeeded()
        guard let msg = cell.messageData?.innerMessage else { return }
        let frame = cell.thumb.convert(cell.thumb.bounds, to: TUITool.applicationKeywindow())
        let mediaView = TUIMediaView_Minimalist(frame: CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.screen_Height()))
        mediaView.setThumb(cell.thumb, frame: frame)
        mediaView.setCurMessage(msg)
        mediaView.onClose = { [weak self] in
            self?.didCloseMediaMessage(cell)
        }
        willShowMediaMessage(cell)
        TUITool.applicationKeywindow()?.addSubview(mediaView)
    }

    func showFileMessage(_ cell: TUIFileMessageCell_Minimalist) {
        hideKeyboardIfNeeded()
        if let fileData = cell.fileData, !fileData.isLocalExist() {
            fileData.downloadFile()
            return
        }
        if let alertController = popAlertController {
            alertController.blurDismissViewController(animated: false) { _ in }
        }

        let fileVC = TUIFileViewController_Minimalist()
        fileVC.data = cell.fileData
        navigationController?.pushViewController(fileVC, animated: true)
    }

    func showRelayMessage(_ cell: TUIMergeMessageCell_Minimalist) {
        if let alertController = popAlertController {
            alertController.blurDismissViewController(animated: false) { _ in }
        }

        let mergeVC = TUIMergeMessageListController_Minimalist()
        mergeVC.delegate = delegate
        mergeVC.mergerElem = cell.mergeData?.mergerElem
        mergeVC.conversationData = conversationData
        mergeVC.parentPageDataProvider = messageDataProvider
        mergeVC.willCloseCallback = { [weak self] in
            guard let self else { return }
            self.tableView.reloadData()
        }
        navigationController?.pushViewController(mergeVC, animated: true)
    }

    func showLinkMessage(_ cell: TUILinkCell_Minimalist) {
        guard let link = cell.customData?.link, link.count > 0 else { return }
        if let url = URL(string: link) {
            TUITool.openLink(with: url)
        }
    }

    func showOrderMessage(_ cell: TUIOrderCell_Minimalist) {
        guard let link = cell.customData?.link, link.count > 0 else { return }
        if let url = URL(string: link) {
            TUITool.openLink(with: url)
        }
    }

    func showReplyMessage<T: TUIBubbleMessageCell_Minimalist>(_ cell: T) {
        // subclass override
    }

    func showReferenceMessage(_ cell: TUIReferenceMessageCell_Minimalist) {
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

    // MARK: - Config TUIChatPopContextExtensionItems

    func setupCopyAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Copy"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_copy")),
                                              weight: 10000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false) { [weak self, weak cell] _ in
                guard let self, let cell else { return }
                self.onCopyMsg(cell)
            }
        }
    }

    func setupForwardAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Forward"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_forward")),
                                              weight: 9000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onForward(nil)
            })
        }
    }

    func setupMultiSelectAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("MultiSelect"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_multi")),
                                              weight: 8000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onMulitSelect(nil)
            })
        }
    }

    func setupReferenceAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Quote"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_quote")),
                                              weight: 7000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onReference(nil)
            })
        }
    }

    func setupReplyAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Reply"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_reply")),
                                              weight: 5000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onReply(nil)
            })
        }
    }

    func setupRecallAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Recall"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_revocation")),
                                              weight: 3000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onRevoke(nil)
            })
        }
    }

    func setupInfoAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        return TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Info"),
                                              markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_info")),
                                              weight: 2000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self, let data = cell.messageData else { return }
                self.onJumpToMessageInfoPage(data, selectCell: cell)
            })
        }
    }

    func setupDeleteAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        let item = TUIChatPopContextExtensionItem(title: TUISwift.timCommonLocalizableString("Delete"),
                                                  markIcon: UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_delete")),
                                                  weight: 1000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onDelete(cell)
            })
        }
        item.titleColor = UIColor.tui_color(withHex: "FF584C")
        return item
    }

    // MARK: - Setup Audio Playback Style Action

    func setupAudioPlaybackStyleAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        let originStyle = TUIVoiceMessageCellData.getAudioplaybackStyle()
        let title = originStyle == .loudspeaker ? TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleHandset") : TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleLoudspeaker")
        let img = originStyle == .loudspeaker ? UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_loudspeaker")) : UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_handset"))

        var item: TUIChatPopContextExtensionItem? = nil
        item = TUIChatPopContextExtensionItem(title: title,
                                              markIcon: img,
                                              weight: 11000)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak item] _ in
                guard let item else { return }
                if originStyle == .loudspeaker {
                    item.title = TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleLoudspeaker")
                    TUITool.hideToast()
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleChange2Handset"), duration: 2)
                } else {
                    item.title = TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleHandset")
                    TUITool.hideToast()
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitAudioPlaybackStyleChange2Loudspeaker"), duration: 2)
                }
                TUIVoiceMessageCellData.changeAudioPlaybackStyle()
            })
        }
        return item!
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

    func setupGroupPinAction(for alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) -> TUIChatPopContextExtensionItem {
        guard let message = menuUIMsg?.innerMessage else { return TUIChatPopContextExtensionItem() }
        let isPinned = isCurrentMessagePin(message.msgID ?? "")
        let img = isPinned ? UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_unpin")) :
            UIImage.safeImage(TUISwift.tuiChatImagePath_Minimalist("icon_extion_pin"))
        return TUIChatPopContextExtensionItem(title: isPinned ? TUISwift.timCommonLocalizableString("TUIKitGroupMessageUnPin") : TUISwift.timCommonLocalizableString("TUIKitGroupMessagePin"),
                                              markIcon: img,
                                              weight: 900)
        { [weak alertController] _ in
            guard let alertController else { return }
            alertController.blurDismissViewController(animated: false, completion: { [weak self] _ in
                guard let self else { return }
                self.onGroupPin(nil, currentStatus: isPinned)
            })
        }
    }

    func onGroupPin(_ sender: Any?, currentStatus: Bool) {
        guard let groupId = conversationData?.groupID, let innerMessage = menuUIMsg?.innerMessage else { return }
        let isPinned = currentStatus
        let pinOrUnpin = !isPinned
        messageDataProvider?.pinGroupMessage(groupId, message: innerMessage, isPinned: pinOrUnpin, succ: {}, fail: { code, _ in
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
        
        let frame = TUITool.applicationKeywindow()?.convert(cell.container.frame, from: cell) ?? .zero
        let alertController = TUIChatPopContextController()
        alertController.alertViewCellData = cell.messageData
        alertController.originFrame = frame
        alertController.alertCellClass = type(of: cell)
        alertController.isConfigRecentView = false
        
        // blur effect
        if let navView = navigationController?.view {
            alertController.setBlurEffect(with: navView)
        }
        
        // config AI-specific items (copy, forward, delete only)
        configAIItems(alertController, targetCell: cell)
        
        alertController.viewWillShowHandler = { [weak self] alertView in
            alertView.delegate = self
        }
        
        alertController.dismissComplete = { [weak cell] in
            cell?.container.isHidden = false
        }
        
        navigationController?.present(alertController, animated: false, completion: nil)
        popAlertController = alertController
    }
    
    /// Configure AI-specific menu items (copy, forward, delete only)
    private func configAIItems(_ alertController: TUIChatPopContextController, targetCell cell: TUIMessageCell) {
        var items = [TUIChatPopContextExtensionItem]()
        
        guard let imMsg = cell.messageData?.innerMessage else { return }
        
        // Add copy action if applicable
        if let data = cell.messageData, isAddCopy(imMsg, data: data) {
            items.append(setupCopyAction(for: alertController, targetCell: cell))
        }
        
        // Add forward action if applicable
        if isAddForward(imMsg) {
            items.append(setupForwardAction(for: alertController, targetCell: cell))
        }
        
        // Add delete action if applicable
        if isAddDelete() {
            items.append(setupDeleteAction(for: alertController, targetCell: cell))
        }
        
        var sortedArray = sortItems(&items)
        let allPageItemsArray = pageItems(&sortedArray, inAlertController: alertController)
        
        if !allPageItemsArray.isEmpty {
            alertController.items = allPageItemsArray[0]
        }
    }

}
