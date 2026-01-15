import TIMCommon
import TUICore

// import TUIGroup
import UIKit

public class TUIGroupChatViewController_Minimalist: TUIBaseChatViewController_Minimalist, V2TIMGroupListener {
    var tipsView: UIView?
    var pendencyLabel: UILabel?
    var pendencyBtn: UIButton?
    var pendencyViewModel: TUIGroupPendencyDataProvider?
    var atUserList: [TUIUserModel] = []
    var responseKeyboard: Bool = false
    var oneGroupPinView: TUIGroupPinCellView?
    var groupPinList: [V2TIMMessage] = []
    var pinPageVC: TUIGroupPinPageViewController?
    private var unreadCountObservation: NSKeyValueObservation?

    override public var conversationData: TUIChatConversationModel? {
        didSet {
            guard let data = conversationData, let groupID = data.groupID, !groupID.isEmpty else { return }
            pendencyViewModel = TUIGroupPendencyDataProvider()
            pendencyViewModel?.groupID = groupID
            atUserList = []
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupTipsView()
        setupGroupPinTips()
        V2TIMManager.sharedInstance().addGroupListener(listener: self)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshTipsView), name: NSNotification.Name(rawValue: "TUICore_TUIChatExtension_ChatViewTopArea_ChangedNotification"), object: nil)

        // Notify plugins about chat view loaded
        if let groupID = conversationData?.groupID {
            let param: [String: Any] = ["TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey_GroupID": groupID]
            TUICore.notifyEvent("TUICore_TUIChatNotify",
                                subKey: "TUICore_TUIChatNotify_ChatVC_ViewDidLoadSubKey",
                                object: nil,
                                param: param)
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshTipsView()

        // Notify plugins about chat view will appear (for restoring state after returning from sub-pages)
        if let groupID = conversationData?.groupID {
            let param: [String: Any] = ["TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey_GroupID": groupID]
            TUICore.notifyEvent("TUICore_TUIChatNotify",
                                subKey: "TUICore_TUIChatNotify_ChatVC_ViewWillAppearSubKey",
                                object: nil,
                                param: param)
        }
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // Notify plugins about chat view will disappear
        TUICore.notifyEvent("TUICore_TUIChatNotify",
                            subKey: "TUICore_TUIChatNotify_ChatVC_ViewWillDisappearSubKey",
                            object: nil,
                            param: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        TUICore.unRegisterEvent(byObject: self)
        unreadCountObservation?.invalidate()
        unreadCountObservation = nil
    }

    func setupTipsView() {
        tipsView = UIView(frame: .zero)
        tipsView!.backgroundColor = TUISwift.rgb(246, g: 234, b: 190)
        view.addSubview(tipsView!)
        tipsView!.mm_height(24).mm_width(view.mm_w)

        pendencyLabel = UILabel(frame: .zero)
        tipsView!.addSubview(pendencyLabel!)
        pendencyLabel!.font = UIFont.systemFont(ofSize: 12)

        pendencyBtn = UIButton(type: .system)
        tipsView!.addSubview(pendencyBtn!)
        pendencyBtn!.setTitle(TUISwift.timCommonLocalizableString("TUIKitChatPendencyTitle"), for: .normal)
        pendencyBtn!.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        pendencyBtn!.addTarget(self, action: #selector(openPendency(_:)), for: .touchUpInside)
        pendencyBtn!.sizeToFit()
        tipsView!.alpha = 0

        unreadCountObservation = pendencyViewModel?.observe(\.unReadCnt, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let unreadCount = change.newValue else { return }

            if unreadCount > 0 {
                let formattedText = String(format: TUISwift.timCommonLocalizableString("TUIKitChatPendencyRequestToJoinGroupFormat"), unreadCount)
                pendencyLabel?.text = formattedText
                pendencyLabel?.sizeToFit()

                let tipsViewWidth = self.tipsView?.mm_w ?? 0
                let pendencyLabelWidth = pendencyLabel?.mm_w ?? 0
                let pendencyBtnWidth = pendencyBtn?.mm_w ?? 0
                let gap = (tipsViewWidth - pendencyLabelWidth - pendencyBtnWidth - 8) / 2

                pendencyLabel?.mm_left(gap).mm__centerY((self.tipsView?.mm_h ?? 0) / 2)
                pendencyBtn?.mm_hstack(8)

                tipsView?.alpha = 1
                self.refreshTipsView()
            } else {
                tipsView?.alpha = 0
            }
        }

        getPendencyList()
    }

    @objc func refreshTipsView() {
        guard let topView = TUIGroupChatViewController_Minimalist.topAreaBottomView() else { return }
        let transRect = topView.convert(topView.bounds, to: view)
        tipsView?.frame = CGRect(x: 0, y: transRect.origin.y + transRect.size.height, width: tipsView?.frame.size.width ?? 0, height: tipsView?.frame.size.height ?? 0)
    }

    func setupGroupPinTips() {
        oneGroupPinView = TUIGroupPinCellView()
        let margin: CGFloat = 0
        oneGroupPinView?.frame = CGRect(x: 0, y: margin, width: view.frame.size.width, height: 62)
        guard let topView = TUIGroupChatViewController_Minimalist.groupPinTopView else { return }
        for subview in topView.subviews {
            subview.removeFromSuperview()
        }
        topView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 0)
        topView.addSubview(oneGroupPinView!)
        oneGroupPinView?.isFirstPage = true
        oneGroupPinView?.onClickCellView = { [weak self] message in
            guard let self = self else { return }
            if self.groupPinList.count >= 2 {
                self.gotoDetailPopPinPage()
            } else {
                self.jump2GroupPinHighlightLine(message)
            }
        }
        oneGroupPinView?.onClickRemove = { [weak self] message in
            guard let self = self else { return }
            self.messageController?.unPinGroupMessage(message)
        }
        messageController?.pinGroupMessageChanged = { [weak self] groupPinList in
            guard let self = self else { return }
            if groupPinList.count > 0 {
                if let oneGroupPinView = self.oneGroupPinView, oneGroupPinView.superview == nil {
                    topView.addSubview(oneGroupPinView)
                }
                if let cellData = TUIMessageDataProvider.convertToCellData(from: groupPinList.last!) {
                    self.oneGroupPinView?.fill(withData: cellData)
                    if groupPinList.count >= 2 {
                        self.oneGroupPinView?.showMultiAnimation()
                        topView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: (self.oneGroupPinView?.frame.size.height ?? 0) + 20 + margin)
                        self.oneGroupPinView?.removeButton.isHidden = true
                    } else {
                        self.oneGroupPinView?.hideMultiAnimation()
                        topView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: (self.oneGroupPinView?.frame.size.height ?? 0) + margin)
                        let isAdmin = self.messageController?.isCurrentUserRoleSuperAdminInGroup() ?? false
                        self.oneGroupPinView?.removeButton.isHidden = !isAdmin
                    }
                }
            } else {
                self.oneGroupPinView?.removeFromSuperview()
                topView.frame = CGRect(x: 0, y: 0, width: view.frame.size.width, height: 0)
            }
            self.groupPinList = groupPinList
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUICore_TUIChatExtension_ChatViewTopArea_ChangedNotification"), object: nil)
            if let pinPageVC = self.pinPageVC {
                let formatGroupPinList = Array(groupPinList.reversed())
                pinPageVC.groupPinList = formatGroupPinList
                pinPageVC.canRemove = self.messageController?.isCurrentUserRoleSuperAdminInGroup() ?? false
                if groupPinList.count > 0 {
                    self.reloadPopPinPage()
                } else {
                    pinPageVC.dismiss(animated: false, completion: nil)
                }
            }
        }
        messageController?.groupRoleChanged = { [weak self] _ in
            guard let self = self else { return }
            self.messageController?.pinGroupMessageChanged?(self.groupPinList)
            if let pinPageVC = self.pinPageVC {
                pinPageVC.canRemove = self.messageController?.isCurrentUserRoleSuperAdminInGroup() ?? false
                pinPageVC.tableview.reloadData()
            }
        }
    }

    func gotoDetailPopPinPage() {
        let vc = TUIGroupPinPageViewController()
        pinPageVC = vc
        let formatGroupPinList = Array(groupPinList.reversed())
        vc.groupPinList = formatGroupPinList
        vc.canRemove = messageController?.isCurrentUserRoleSuperAdminInGroup() ?? false
        vc.view.frame = view.frame

        let cellHeight: CGFloat = 62
        let maxOnePage: CGFloat = 4
        let height = CGFloat(formatGroupPinList.count) * cellHeight
        let maxHeight = cellHeight * maxOnePage

        guard let topView = TUIGroupChatViewController_Minimalist.groupPinTopView else { return }
        let transRect = topView.convert(topView.bounds, to: TUITool.applicationKeywindow())
        vc.modalPresentationStyle = .overFullScreen

        present(vc, animated: false) { [weak self] in
            guard let self else { return }
            vc.tableview.frame = CGRect(x: 0, y: transRect.minY, width: self.view.frame.size.width, height: height)
            vc.customArrowView.frame = CGRect(x: 0, y: vc.tableview.frame.maxY, width: vc.tableview.frame.width, height: 0)
            vc.bottomShadow.frame = CGRect(x: 0, y: vc.customArrowView.frame.maxY, width: vc.tableview.frame.width, height: self.view.frame.size.height)
            UIView.animate(withDuration: 0.3) {
                vc.tableview.frame = CGRect(x: 0, y: transRect.minY, width: self.view.frame.size.width, height: min(height, maxHeight))
                vc.customArrowView.frame = CGRect(x: 0, y: vc.tableview.frame.maxY, width: vc.tableview.frame.width, height: 40)
                vc.bottomShadow.frame = CGRect(x: 0, y: vc.customArrowView.frame.maxY, width: vc.tableview.frame.width, height: self.view.frame.size.height)
                let maskPath = UIBezierPath(roundedRect: vc.customArrowView.bounds, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 10.0, height: 10.0))
                let maskLayer = CAShapeLayer()
                maskLayer.frame = vc.customArrowView.bounds
                maskLayer.path = maskPath.cgPath
                vc.customArrowView.layer.mask = maskLayer
            }
        }

        vc.onClickRemove = { [weak self] originMessage in
            guard let self = self else { return }
            self.messageController?.unPinGroupMessage(originMessage)
        }
        vc.onClickCellView = { [weak self] originMessage in
            guard let self = self else { return }
            self.jump2GroupPinHighlightLine(originMessage)
        }
    }

    func jump2GroupPinHighlightLine(_ originMessage: V2TIMMessage) {
        guard let msgVC = messageController as? TUIMessageController_Minimalist,
              let msgID = originMessage.msgID else { return }
        msgVC.findMessages([msgID], callback: { [weak self] success, _, messages in
            guard let self else { return }
            if success, let message = messages?.first, message.status == .MSG_STATUS_SEND_SUCC {
                msgVC.locateAssignMessage(originMessage, matchKeyWord: "")
            } else {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitReplyMessageNotFoundOriginMessage"))
            }
        })
    }

    func reloadPopPinPage() {
        let cellHeight: CGFloat = 62
        let maxOnePage: CGFloat = 4
        let height = CGFloat(groupPinList.count) * cellHeight
        let maxHeight = cellHeight * maxOnePage
        guard let pinPageVC = pinPageVC else { return }
        pinPageVC.tableview.frame = CGRect(x: 0, y: pinPageVC.tableview.frame.minY, width: view.frame.size.width, height: min(height, maxHeight))
        pinPageVC.customArrowView.frame = CGRect(x: 0, y: pinPageVC.tableview.frame.maxY, width: pinPageVC.tableview.frame.width, height: 40)
        pinPageVC.bottomShadow.frame = CGRect(x: 0, y: pinPageVC.customArrowView.frame.maxY, width: pinPageVC.tableview.frame.width, height: view.frame.size.height)
        pinPageVC.tableview.reloadData()
    }

    func getPendencyList() {
        guard let conversationData = conversationData else { return }
        if let groupID = conversationData.groupID, !groupID.isEmpty {
            pendencyViewModel?.loadData()
        }
    }

    @objc func openPendency(_ sender: Any) {
        let vc = TUIGroupPendencyController()
        vc.cellClickBlock = { [weak self] cell in
            guard let self = self else { return }
            guard let pendencyData = cell.pendencyData else { return }
            if pendencyData.isRejected || pendencyData.isAccepted {
                return
            }
            guard let userID = pendencyData.fromUser else { return }
            V2TIMManager.sharedInstance().getUsersInfo([userID], succ: { [weak self] profiles in
                guard let self = self, let first = profiles?.first else { return }
                let param: [String: Any] = [
                    "TUICore_TUIContactObjectFactory_UserProfileController_UserProfile": first,
                    "TUICore_TUIContactObjectFactory_UserProfileController_PendencyData": pendencyData,
                    "TUICore_TUIContactObjectFactory_UserProfileController_ActionType": UInt(3)
                ]
                self.navigationController?.push("TUICore_TUIContactObjectFactory_UserProfileController_Minimalist", param: param, forResult: nil)
            }) { _, _ in
            }
        }
        vc.viewModel = pendencyViewModel ?? TUIGroupPendencyDataProvider()
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - V2TIMGroupListener

    public func onReceiveJoinApplication(groupID: String?, member: V2TIMGroupMemberInfo, opReason: String?) {
        getPendencyList()
    }

    public func onGroupInfoChanged(groupID: String?, changeInfoList: [V2TIMGroupChangeInfo]) {
        guard let data = conversationData else { return }
        if groupID != data.groupID {
            return
        }
        for changeInfo in changeInfoList {
            if changeInfo.type == .GROUP_INFO_CHANGE_TYPE_NAME {
                data.title = changeInfo.value
            } else if changeInfo.type == .GROUP_INFO_CHANGE_TYPE_FACE {
                data.faceUrl = changeInfo.value
            }
        }
    }

    // MARK: - TUIInputControllerDelegate

    override func inputController(_ inputController: TUIInputController_Minimalist, didSendMessage message: V2TIMMessage) {
        var atMessage = message
        if message.elemType == .ELEM_TYPE_TEXT {
            var atUserList: [String] = []
            for model in self.atUserList {
                atUserList.append(model.userId)
            }
            if atUserList.count > 0 {
                let list = NSMutableArray(array: atUserList)
                let cloudCustomData = message.cloudCustomData
                if let msg = V2TIMManager.sharedInstance().createTextAtMessage(text: message.textElem?.text ?? "", atUserList: list) {
                    msg.cloudCustomData = cloudCustomData
                    atMessage = msg
                }
            }
            self.atUserList.removeAll()
        }
        super.inputController(inputController, didSendMessage: atMessage)
    }

    let kTUIInputNoramlFont = UIFont.systemFont(ofSize: 16)
    override func inputControllerDidInputAt(_ inputController: TUIInputController_Minimalist) {
        super.inputControllerDidInputAt(inputController)

        guard let groupID = conversationData?.groupID, !groupID.isEmpty else { return }
        if let topViewController = navigationController?.topViewController,
           let targetClass = NSClassFromString("TUIContact.TUISelectGroupMemberViewController_Minimalist"),
           topViewController.isKind(of: targetClass) { return }

        inputController.reset()

        var param: [String: Any] = [:]
        param["TUICore_TUIContactObjectFactory_SelectGroupMemberVC_GroupID"] = groupID
        param["TUICore_TUIContactObjectFactory_SelectGroupMemberVC_Name"] = TUISwift.timCommonLocalizableString("TUIKitAtSelectMemberTitle")
        param["TUICore_TUIContactObjectFactory_SelectGroupMemberVC_OptionalStyle"] = 1

        navigationController?.push("TUICore_TUIContactObjectFactory_SelectGroupMemberVC_Minimalist", param: param, forResult: { [weak self] param in
            guard let self = self else { return }
            guard let modelList = param["TUICore_TUIContactObjectFactory_SelectGroupMemberVC_ResultUserList"] as? [TUIUserModel] else { return }
            let atText = NSMutableString()
            for model in modelList {
                self.atUserList.append(model)
                atText.append("@\(model.name) ")
            }
            let textFont = kTUIInputNoramlFont
            let spaceString = NSAttributedString(string: atText as String, attributes: [NSAttributedString.Key.font: textFont])
            self.inputController.inputBar?.addWordsToInputBar(spaceString)
        })
    }

    override func inputController(_ inputController: TUIInputController_Minimalist, didDeleteAt atText: String) {
        super.inputController(inputController, didDeleteAt: atText)
        for user in atUserList {
            let userName: String? = user.name
            if let userName = userName, atText.contains(userName) {
                if let index = atUserList.firstIndex(of: user) {
                    atUserList.remove(at: index)
                }
                break
            }
        }
    }

    // MARK: - TUIBaseMessageControllerDelegate

    override func onLongSelectMessageAvatar(_ controller: TUIBaseMessageController_Minimalist, cell: TUIMessageCell) {
        guard let messageData = cell.messageData, messageData.identifier != TUILogin.getUserID() else { return }

        let atUserExist = atUserList.contains { $0.userId == messageData.identifier }
        if !atUserExist {
            let user = TUIUserModel()
            if let userID = messageData.identifier {
                user.userId = userID
            }
            user.name = messageData.senderName
            atUserList.append(user)

            let nameString = "@\(user.name) "
            let textFont = kTUIInputNoramlFont
            let spaceString = NSAttributedString(string: nameString, attributes: [NSAttributedString.Key.font: textFont])
            inputController.inputBar?.addWordsToInputBar(spaceString)
        }
    }

    // MARK: - Override Methods

    override public func forwardTitleWithMyName(_ nameStr: String) -> String {
        return TUISwift.timCommonLocalizableString("TUIKitRelayGroupChatHistory")
    }
}
