import TIMCommon
import TUICore
import UIKit

class TUIGroupInfoController_Minimalist: UIViewController, TUIModifyViewDelegate, TUIProfileCardDelegate, TUIGroupInfoDataProviderDelegate_Minimalist, UITableViewDelegate, UITableViewDataSource, TUINotificationProtocol {
    var tableView: UITableView!
    var groupId: String?
    var dataProvider: TUIGroupInfoDataProvider_Minimalist!
    var titleView: TUINaviBarIndicatorView!
    private var dataListObservation: NSKeyValueObservation?

    deinit {
        dataListObservation?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dataProvider = TUIGroupInfoDataProvider_Minimalist(groupID: groupId ?? "")
        dataProvider.delegate = self

        setupViews()
        dataProvider.loadData()
        
        // Register unified voice message settings reload notification
        TUICore.registerEvent(
            "TUICore_TUIVoiceMessageNotify",
            subKey: "TUICore_TUIVoiceMessageNotify_ReloadDataSubKey",
            object: self
        )

        dataListObservation = dataProvider.observe(\.dataList, options: [.new, .initial]) { [weak self] _, _ in
            guard let self else { return }
            self.tableView.reloadData()
        }

        titleView = TUINaviBarIndicatorView()
        navigationItem.titleView = titleView
        navigationItem.title = ""
        titleView.setTitle(TUISwift.timCommonLocalizableString("ProfileDetails"))
    }

    func setupViews() {
        tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#FFFFFF")
        tableView.delaysContentTouches = false
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = .white
        tableView.separatorInset = UIEdgeInsets(top: 0, left: -58, bottom: 0, right: 0)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.frame = view.bounds
        view.addSubview(tableView)

        tableView.tableFooterView = UIView()
        let headerView = TUIGroupProfileHeaderView_Minimalist()
        tableView.tableHeaderView = headerView
        updateGroupInfo()

        headerView.headImgClickBlock = { [weak self] in
            guard let self else { return }
            self.didSelectAvatar()
        }
        headerView.editBtnClickBlock = { [weak self] in
            guard let self else { return }
            self.didSelectEditGroupName()
        }

        // Extension
        var itemViewList: [TUIGroupProfileHeaderItemView_Minimalist] = []
        var param: [String: Any] = [:]
        if let groupId = groupId, !groupId.isEmpty {
            param["TUICore_TUIContactExtension_GroupInfoCardActionMenu_GroupID"] = groupId
        }
        param["TUICore_TUIContactExtension_GroupInfoCardActionMenu_FilterVideoCall"] = false
        param["TUICore_TUIContactExtension_GroupInfoCardActionMenu_FilterAudioCall"] = false
        if let navigationController = navigationController {
            param["TUICore_TUIContactExtension_GroupInfoCardActionMenu_PushVC"] = navigationController
        }
        let extensionList = TUICore.getExtensionList("TUICore_TUIContactExtension_GroupInfoCardActionMenu_MinimalistExtensionID", param: param)
        for info in extensionList {
            if let icon = info.icon, let text = info.text, let onClicked = info.onClicked {
                let itemView = TUIGroupProfileHeaderItemView_Minimalist()
                itemView.iconView.image = icon
                itemView.textLabel.text = text
                itemView.messageBtnClickBlock = {
                    onClicked(param)
                }
                itemViewList.append(itemView)
            }
        }
        headerView.setCustomItemViewList(itemViewList)

        if itemViewList.count > 0 {
            headerView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 355)
        } else {
            headerView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.size.width, height: 257)
        }
    }

    func updateData() {
        dataProvider.loadData()
    }

    func updateGroupInfo() {
        dataProvider.updateGroupInfo { [weak self] in
            if let headerView = self?.tableView.tableHeaderView as? TUIGroupProfileHeaderView_Minimalist {
                headerView.groupInfo = self?.dataProvider.groupInfo
            }
        }
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return dataProvider.dataList.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let array = dataProvider.dataList[section]
        return array.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let array = dataProvider.dataList[indexPath.section]
        let data = array[indexPath.row]
        if let data = data as? TUIGroupMemberCellData_Minimalist {
            return data.height(ofWidth: TUISwift.screen_Width())
        } else if let data = data as? TUIGroupButtonCellData_Minimalist {
            return data.height(ofWidth: TUISwift.screen_Width())
        } else if let data = data as? TUICommonSwitchCellData {
            return data.height(ofWidth: TUISwift.screen_Width())
        } else if data is TUIGroupNoticeCellData {
            return 72.0
        }
        return TUISwift.kScale390(55)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let array = dataProvider.dataList[indexPath.section]
        let data = array[indexPath.row]

        if let data = data as? TUICommonTextCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TKeyValueCell") as? TUICommonTextCell ?? TUICommonTextCell(style: .default, reuseIdentifier: "TKeyValueCell")
            cell.fill(with: data)
            cell.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            cell.contentView.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            return cell
        } else if let data = data as? TUIGroupMemberCellData_Minimalist {
            let cell = TUICommonTableViewCell(style: .default, reuseIdentifier: "TGroupMembersCell")
            let param: [String: Any] = [
                "data": data,
                "pushVC": navigationController as Any,
                "groupID": groupId ?? "",
                "membersData": dataProvider.membersData
            ]
            TUICore.raiseExtension("TUICore_TUIChatExtension_GroupProfileMemberListExtension_MinimalistExtensionID", parentView: cell, param: param)
            cell.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            cell.contentView.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            return cell
        } else if let data = data as? TUICommonSwitchCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TSwitchCell") as? TUICommonSwitchCell ?? TUICommonSwitchCell(style: .default, reuseIdentifier: "TSwitchCell")
            cell.fill(with: data)
            cell.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            cell.contentView.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            return cell
        } else if let data = data as? TUIGroupButtonCellData_Minimalist {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TButtonCell") as? TUIGroupButtonCell_Minimalist ?? TUIGroupButtonCell_Minimalist(style: .default, reuseIdentifier: "TButtonCell")
            cell.fill(with: data)
            return cell
        } else if data is TUIGroupNoticeCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TUIGroupNoticeCell") as? TUIGroupNoticeCell ?? TUIGroupNoticeCell(style: .default, reuseIdentifier: "TUIGroupNoticeCell")
            cell.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            cell.contentView.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#f9f9f9")
            cell.cellData = data as? TUIGroupNoticeCellData
            return cell
        }
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle row selection
    }

    func leftBarButtonClick(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    // MARK: TUIGroupInfoDataProviderDelegate_Minimalist

    @objc func groupProfileExtensionButtonClick(_ cell: TUICommonTextCell) {
        guard let data = cell.data,
              let info = data.tui_extValueObj as? TUIExtensionInfo,
              let onClicked = info.onClicked else { return }
        onClicked([:])
    }

    func onSendMessage(_ cell: TUIGroupProfileCardViewCell_Minimalist) {
        guard let cellData = cell.cardData else { return }
        let avatarImage = cell.headerView.headImg.image ?? UIImage()
        let param: [String: Any] = [
            "TUICore_TUIChatObjectFactory_ChatViewController_Title": cellData.name ?? "",
            "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": cellData.identifier ?? "",
            "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": avatarImage
        ]
        navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Minimalist", param: param, forResult: nil)
    }

    @objc func didSelectMembers() {
        var param: [String: Any] = [:]
        if let groupId = groupId, !groupId.isEmpty {
            param["groupID"] = groupId
        }
        if let groupInfo = dataProvider.groupInfo {
            param["groupInfo"] = groupInfo
        }
        if let vc = TUICore.createObject("TUICore_TUIContactObjectFactory_Minimalist", key: "TUICore_TUIContactObjectFactory_GetGroupMemberVCMethod", param: param) as? UIViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func didSelectAddOption(_ cell: UITableViewCell) {
        guard let cell = cell as? TUICommonTextCell else { return }
        var isApprove = false
        if let key = cell.textData?.key {
            isApprove = key == TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteType")
        }
        let ac = UIAlertController(title: nil, message: isApprove ? TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteType") : TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinType"), preferredStyle: .actionSheet)

        let actionList: [[V2TIMGroupAddOpt: String]] = [
            [.GROUP_ADD_FORBID: isApprove ? TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteDisable") : TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinDisable")],
            [.GROUP_ADD_AUTH: TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdminApprove")],
            [.GROUP_ADD_ANY: TUISwift.timCommonLocalizableString("TUIKitGroupProfileAutoApproval")]
        ]

        for map in actionList {
            if let title = map.values.first {
                ac.addAction(UIAlertAction(title: title, style: .default) { _ in
                    if let opt = map.keys.first {
                        if isApprove {
                            self.dataProvider.setGroupApproveOpt(opt)
                        } else {
                            self.dataProvider.setGroupAddOpt(opt)
                        }
                    }
                })
            }
        }
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    @objc func didSelectGroupNick(_ cell: TUICommonTextCell) {
        let data = TUIModifyViewData()
        data.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAlias")
        data.content = dataProvider.selfInfo?.nameCard ?? ""
        data.desc = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAliasDesc")
        let modify = TUIModifyView()
        modify.tag = 2
        modify.delegate = self
        modify.setData(data)
        if let window = view.window {
            modify.showInWindow(window)
        }
    }

    @objc func didSelectCommon() {
        guard let groupInfo = dataProvider.groupInfo else { return }
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        if groupInfo.isPrivate() || groupInfo.isMeOwner() {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditGroupName"), style: .default) { [weak self] _ in
                self?.didSelectEditGroupName()
            })
        }
        if groupInfo.isMeOwner() {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAnnouncement"), style: .default) { [weak self] _ in
                self?.didSelectEditAnnouncement()
            })
        }
        if groupInfo.isMeOwner() {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAvatar"), style: .default) { [weak self] _ in
                self?.didSelectAvatar()
            })
        }
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    @objc func didSelectEditGroupName() {
        let data = TUIModifyViewData()
        data.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditGroupName")
        data.content = dataProvider.groupInfo?.groupName ?? ""
        data.desc = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditGroupName")
        let modify = TUIModifyView()
        modify.tag = 0
        modify.delegate = self
        modify.setData(data)
        if let window = view.window {
            modify.showInWindow(window)
        }
    }

    @objc func didSelectEditAnnouncement() {
        let data = TUIModifyViewData()
        data.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAnnouncement")
        let modify = TUIModifyView()
        modify.tag = 1
        modify.delegate = self
        modify.setData(data)
        if let window = view.window {
            modify.showInWindow(window)
        }
    }

    @objc func didSelectAvatar() {
        let vc = TUISelectAvatarController()
        vc.selectAvatarType = .groupAvatar
        vc.profilFaceURL = dataProvider.groupInfo?.faceURL ?? ""
        navigationController?.pushViewController(vc, animated: true)

        vc.selectCallBack = { [weak self] urlStr in
            guard let self = self else { return }
            if !urlStr.isEmpty {
                let info = V2TIMGroupInfo()
                info.groupID = self.groupId
                info.faceURL = urlStr
               V2TIMManager.sharedInstance().setGroupInfo(info: info, succ: {
                    self.updateGroupInfo()
                }, fail: { code, msg in
                    TUITool.makeToastError(Int(code), msg: msg)
                })
            }
        }
    }

    @objc func didSelectOnNotDisturb(_ cell: TUICommonSwitchCell) {
        let opt: V2TIMReceiveMessageOpt = cell.switcher.isOn ? .RECEIVE_NOT_NOTIFY_MESSAGE : .RECEIVE_MESSAGE

       V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: false, succ: nil, fail: nil)

        dataProvider.setGroupReceiveMessageOpt(opt, succ: { [weak self] in
            self?.updateGroupInfo()
        }, fail: { _, _ in
            // Handle failure
        })
    }

    @objc func didSelectOnTop(_ cell: TUICommonSwitchCell) {
        let conversationID = "group_\(groupId ?? "")"
        if cell.switcher.isOn {
            TUIConversationPin.sharedInstance.addTopConversation(conversationID) { success, errorMessage in
                if !success {
                    cell.switcher.isOn.toggle()
                    TUITool.makeToast(errorMessage ?? "")
                }
            }
        } else {
            TUIConversationPin.sharedInstance.removeTopConversation(conversationID) { success, errorMessage in
                if !success {
                    cell.switcher.isOn.toggle()
                    TUITool.makeToast(errorMessage ?? "")
                }
            }
        }
    }

    @objc func didDeleteGroup(_ cell: TUIButtonCell) {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            if self.dataProvider.groupInfo?.canDismissGroup() ?? false {
                self.dataProvider.dismissGroup {
                    DispatchQueue.main.async {
                        if let vc = self.findConversationListViewController() {
                           V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(self.groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: false, succ: { _ in
                                self.navigationController?.popToViewController(vc, animated: true)
                            }, fail: { _, _ in
                                self.navigationController?.popToViewController(vc, animated: true)
                            })
                        }
                    }
                } fail: { code, msg in
                    TUITool.makeToastError(Int(code), msg: msg)
                }
            } else {
                self.dataProvider.quitGroup {
                    DispatchQueue.main.async {
                        if let vc = self.findConversationListViewController() {
                            TUIConversationPin.sharedInstance.removeTopConversation("group_\(self.groupId ?? "")", callback: nil)
                           V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(self.groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: false, succ: { _ in
                                self.navigationController?.popToViewController(vc, animated: true)
                            }, fail: { _, _ in
                                self.navigationController?.popToViewController(vc, animated: true)
                            })
                        }
                    }
                } fail: { code, msg in
                    TUITool.makeToastError(Int(code), msg: msg)
                }
            }
        })
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    @objc func didReportGroup(_ cell: TUIButtonCell) {
        if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
            TUITool.openLink(with: url)
        }
    }

    func findConversationListViewController() -> UIViewController? {
        for vc in navigationController?.viewControllers ?? [] {
            if vc.isKind(of: NSClassFromString("TUIConversation.TUIFoldListViewController")!) {
                return vc
            }
        }
        return navigationController?.viewControllers.first
    }

    @objc func didSelectOnFoldConversation(_ cell: TUICommonSwitchCell) {
        let enableMark = cell.switcher.isOn

       V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: enableMark, succ: { [weak self] _ in
            guard let self = self else { return }
            cell.switchData?.isOn = enableMark
            TUIConversationPin.sharedInstance.removeTopConversation("group_\(self.groupId ?? "")") { _, _ in
                self.updateGroupInfo()
            }
        }, fail: nil)
    }

    @objc func didSelectOnChangeBackgroundImage(_ cell: TUICommonTextCell) {
        let conversationID = "group_\(groupId ?? "")"
        let vc = TUISelectAvatarController()
        vc.selectAvatarType = .conversationBackgroundCover
        vc.profilFaceURL = getBackgroundImageUrlByConversationID(conversationID) ?? ""
        navigationController?.pushViewController(vc, animated: true)

        vc.selectCallBack = { [weak self] urlStr in
            guard let self = self else { return }
            self.appendBackgroundImage(urlStr, conversationID: conversationID)
            if !conversationID.isEmpty {
                TUICore.notifyEvent("TUICore_TUIContactNotify", subKey: "TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey", object: self, param: ["TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey_ConversationID": conversationID])
            }
        }
    }

    func getBackgroundImageUrlByConversationID(_ targerConversationID: String) -> String? {
        guard !targerConversationID.isEmpty else { return nil }
        guard let dict = UserDefaults.standard.object(forKey: "conversation_backgroundImage_map") as? [String: String] else { return nil }
        let loginUserID = TUILogin.getUserID()
        let conversationID_UserID = "\(targerConversationID)_\(loginUserID ?? "")"
        return dict[conversationID_UserID]
    }

    func appendBackgroundImage(_ imgUrl: String, conversationID: String) {
        guard !conversationID.isEmpty else { return }
        var dict = UserDefaults.standard.object(forKey: "conversation_backgroundImage_map")
        if dict == nil {
            dict = [String: String]()
        }
        guard var dict = dict as? [String: String] else { return }
        let loginUserID = TUILogin.getUserID()
        let conversationID_UserID = "\(conversationID)_\(loginUserID ?? "")"
        if imgUrl.isEmpty {
            dict.removeValue(forKey: conversationID_UserID)
        } else {
            dict[conversationID_UserID] = imgUrl
        }

        UserDefaults.standard.set(dict, forKey: "conversation_backgroundImage_map")
        UserDefaults.standard.synchronize()
    }

    @objc func didClearAllHistory(_ cell: TUIButtonCell) {
        let ac = UIAlertController(title: nil, message: TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistoryTips"), preferredStyle: .alert)

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.dataProvider.clearAllHistory {
                TUICore.notifyEvent("TUICore_TUIConversationNotify", subKey: "TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey", object: self, param: nil)
                TUITool.makeToast("success")
            } fail: { code, desc in
                TUITool.makeToastError(Int(code), msg: desc)
            }
        })

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    func pushNavigationController() -> UINavigationController? {
        return navigationController
    }

    @objc func didSelectGroupNotice() {
        let vc = TUIGroupNoticeController_Minimalist()
        vc.groupID = groupId
        vc.onNoticeChanged = { [weak self] in
            self?.updateGroupInfo()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: TUIProfileCardDelegate

    func didTap(onAvatar cell: TUIProfileCardCell) {
        let vc = TUISelectAvatarController()
        vc.selectAvatarType = .groupAvatar
        vc.profilFaceURL = dataProvider.groupInfo?.faceURL ?? ""
        navigationController?.pushViewController(vc, animated: true)

        vc.selectCallBack = { [weak self] urlStr in
            guard let self = self else { return }
            if !urlStr.isEmpty {
                let info = V2TIMGroupInfo()
                info.groupID = self.groupId
                info.faceURL = urlStr
               V2TIMManager.sharedInstance().setGroupInfo(info: info, succ: {
                    self.updateGroupInfo()
                }, fail: { code, msg in
                    TUITool.makeToastError(Int(code), msg: msg)
                })
            }
        }
    }

    @objc func didAddMembers() {
        TUICore.notifyEvent("TUICore_TUIContactNotify", subKey: "TUICore_TUIContactNotify_OnAddMemebersClickSubKey", object: self, param: nil)
    }
    
    @objc func didSelectVoiceSetting(_ cell: TUICommonTextCell) {
        guard let extensionInfo = cell.data?.tui_extValueObj as? TUIExtensionInfo,
              let onClicked = extensionInfo.onClicked
        else { return }
        
        onClicked([
            "viewController": self,
            "pushVC": navigationController as Any
        ])
    }

    // MARK: - TUIModifyViewDelegate

    func modifyView(_ modifyView: TUIModifyView, didModiyContent content: String) {
        if modifyView.tag == 0 {
            dataProvider.setGroupName(content, { [weak self] in
                self?.updateGroupInfo()
            }, { _, _ in })
        } else if modifyView.tag == 1 {
            dataProvider.setGroupNotification(content)
        } else if modifyView.tag == 2 {
            dataProvider.setGroupMemberNameCard(content)
        }
    }
    
    // MARK: - TUINotificationProtocol
    
    func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIVoiceMessageNotify",
           subKey == "TUICore_TUIVoiceMessageNotify_ReloadDataSubKey" {
            dataProvider.loadData()
        }
    }
}
