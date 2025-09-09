import TIMCommon
import TUICore
import UIKit

class TUIGroupInfoController: UITableViewController, TUIModifyViewDelegate, TUIProfileCardDelegate, TUIGroupInfoDataProviderDelegate {
    var groupId: String?
    private var dataProvider: TUIGroupInfoDataProvider!
    private var titleView: TUINaviBarIndicatorView!
    private var showContactSelectVC: UIViewController?
    private var dataListObservation: NSKeyValueObservation?

    deinit {
        dataListObservation?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let groupID = groupId else { return }

        dataProvider = TUIGroupInfoDataProvider(groupID: groupID)
        dataProvider.delegate = self
        dataProvider.loadData()
        dataListObservation = dataProvider.observe(\.dataList, options: [.new, .initial]) { [weak self] _, _ in
            guard let self else { return }
            self.tableView.reloadData()
        }

        titleView = TUINaviBarIndicatorView()
        navigationItem.titleView = titleView
        navigationItem.title = ""
        titleView.setTitle(TUISwift.timCommonLocalizableString("ProfileDetails"))

        setupViews()
    }

    private func setupViews() {
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        tableView.delaysContentTouches = false
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
    }

    func updateData() {
        dataProvider.loadData()
    }

    func updateGroupInfo() {
        dataProvider.updateGroupInfo()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataProvider.dataList.count
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 10
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataProvider.dataList[section].count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let data = dataProvider.dataList[indexPath.section][indexPath.row]
        let screenWidth = TUISwift.screen_Width()
        if let data = data as? TUIProfileCardCellData {
            return data.height(ofWidth: screenWidth)
        } else if let data = data as? TUIGroupMembersCellData {
            return data.height(ofWidth: screenWidth)
        } else if let data = data as? TUIButtonCellData {
            return data.height(ofWidth: screenWidth)
        } else if let data = data as? TUICommonSwitchCellData {
            return data.height(ofWidth: screenWidth)
        } else if data is TUIGroupNoticeCellData {
            return 72.0
        }
        return 44
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let data = dataProvider.dataList[indexPath.section][indexPath.row]
        if let data = data as? TUIProfileCardCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TGroupCommonCell") as? TUIProfileCardCell ?? TUIProfileCardCell(style: .default, reuseIdentifier: "TGroupCommonCell")
            cell.delegate = self
            cell.fill(with: data)
            return cell
        } else if let data = data as? TUICommonTextCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TKeyValueCell") as? TUICommonTextCell ?? TUICommonTextCell(style: .default, reuseIdentifier: "TKeyValueCell")
            cell.fill(with: data)
            return cell
        } else if let data = data as? TUIGroupMembersCellData {
            let cell = TUICommonTableViewCell(style: .default, reuseIdentifier: "TGroupMembersCell")
            let param: [String: Any] = [
                "data": data,
                "pushVC": navigationController as Any,
                "groupID": groupId ?? "",
                "membersData": dataProvider.membersData,
                "groupMembersCellData": dataProvider.groupMembersCellData as Any
            ]
            TUICore.raiseExtension("TUICore_TUIChatExtension_GroupProfileMemberListExtension_ClassicExtensionID", parentView: cell, param: param)
            return cell
        } else if let data = data as? TUICommonSwitchCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TSwitchCell") as? TUICommonSwitchCell ?? TUICommonSwitchCell(style: .default, reuseIdentifier: "TSwitchCell")
            cell.fill(with: data)
            return cell
        } else if let data = data as? TUIButtonCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TButtonCell") as? TUIButtonCell ?? TUIButtonCell(style: .default, reuseIdentifier: "TButtonCell")
            cell.fill(with: data)
            return cell
        } else if let data = data as? TUIGroupNoticeCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TUIGroupNoticeCell") as? TUIGroupNoticeCell ?? TUIGroupNoticeCell(style: .default, reuseIdentifier: "TUIGroupNoticeCell")
            cell.cellData = data
            return cell
        }
        return UITableViewCell()
    }

    @objc func leftBarButtonClick(_ sender: UIButton) {
        navigationController?.popViewController(animated: true)
    }

    // MARK: TUIGroupInfoDataProviderDelegate

    @objc func groupProfileExtensionButtonClick(_ cell: TUICommonTextCell) {
        guard let info = cell.data?.tui_extValueObj as? TUIExtensionInfo,
              let onClicked = info.onClicked else { return }
        onClicked([:])
    }

    @objc func didSelectMembers() {
        var param: [String: Any] = [:]
        if let groupId = groupId, !groupId.isEmpty {
            param["groupID"] = groupId
        }
        if let groupInfo = dataProvider.groupInfo {
            param["groupInfo"] = groupInfo
        }
        if let vc = TUICore.createObject("TUICore_TUIContactObjectFactory", key: "TUICore_TUIContactObjectFactory_GetGroupMemberVCMethod", param: param) as? UIViewController {
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc func didSelectAddOption(_ cell: UITableViewCell) {
        guard let cell = cell as? TUICommonTextCell else { return }
        guard let data = cell.textData else { return }
        let isApprove = data.key == TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteType")
        let ac = UIAlertController(title: nil, message: isApprove ? TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteType") : TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinType"), preferredStyle: .actionSheet)

        let actionList: [[V2TIMGroupAddOpt: String]] = [
            [.GROUP_ADD_FORBID: isApprove ? TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteDisable") : TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinDisable")],
            [.GROUP_ADD_AUTH: TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdminApprove")],
            [.GROUP_ADD_ANY: TUISwift.timCommonLocalizableString("TUIKitGroupProfileAutoApproval")]
        ]

        for map in actionList {
            for (opt, title) in map {
                ac.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    guard let self else { return }
                    if isApprove {
                        self.dataProvider.setGroupApproveOpt(opt)
                    } else {
                        self.dataProvider.setGroupAddOpt(opt)
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
                guard let self else { return }
                let data = TUIModifyViewData()
                data.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditGroupName")
                data.content = self.dataProvider.groupInfo?.groupName ?? ""
                data.desc = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditGroupName")
                let modify = TUIModifyView()
                modify.tag = 0
                modify.delegate = self
                modify.setData(data)
                if let window = self.view.window {
                    modify.showInWindow(window)
                }
            })
        }

        if groupInfo.isMeOwner() {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAnnouncement"), style: .default) { [weak self] _ in
                guard let self else { return }
                let data = TUIModifyViewData()
                data.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAnnouncement")
                let modify = TUIModifyView()
                modify.tag = 1
                modify.delegate = self
                modify.setData(data)
                if let window = self.view.window {
                    modify.showInWindow(window)
                }
            })
        }

        if groupInfo.isMeOwner() {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileEditAvatar"), style: .default) { [weak self] _ in
                guard let self else { return }
                let vc = TUISelectAvatarController()
                vc.selectAvatarType = .groupAvatar
                vc.profilFaceURL = groupInfo.faceURL
                self.navigationController?.pushViewController(vc, animated: true)
                vc.selectCallBack = { [weak self] urlStr in
                    guard let self = self, !urlStr.isEmpty else { return }
                    let info = V2TIMGroupInfo()
                    info.groupID = self.groupId
                    info.faceURL = urlStr
                   V2TIMManager.sharedInstance().setGroupInfo(info: info, succ: {
                        self.updateGroupInfo()
                    }, fail: { code, msg in
                        TUITool.makeToastError(Int(code), msg: msg)
                    })
                }
            })
        }

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    @objc func didSelectOnNotDisturb(_ cell: TUICommonSwitchCell) {
        let opt: V2TIMReceiveMessageOpt = cell.switcher.isOn ? .RECEIVE_NOT_NOTIFY_MESSAGE : .RECEIVE_MESSAGE

       V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: false, succ: nil, fail: nil)

        dataProvider.setGroupReceiveMessageOpt(opt, succ: { [weak self] in
            guard let self else { return }
            self.updateGroupInfo()
        }, fail: { _, _ in })
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
        let ac = UIAlertController(title: nil, message: TUISwift.timCommonLocalizableString("TUIKitGroupProfileDeleteGroupTips"), preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            if self.dataProvider.groupInfo?.canDismissGroup() ?? false {
                self.dataProvider.dismissGroup(succ: {
                    self.handleGroupDismissOrQuit()
                }, fail: { code, msg in
                    TUITool.makeToastError(Int(code), msg: msg)
                })
            } else {
                self.dataProvider.quitGroup(succ: {
                    self.handleGroupDismissOrQuit()
                }, fail: { code, msg in
                    TUITool.makeToastError(Int(code), msg: msg)
                })
            }
        })

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    private func handleGroupDismissOrQuit() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let vc = self.findConversationListViewController()
            TUIConversationPin.sharedInstance.removeTopConversation("group_\(self.groupId ?? "")", callback: nil)
           V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(self.groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: false, succ: { _ in
                self.navigationController?.popToViewController(vc, animated: true)
            }, fail: { _, _ in
                self.navigationController?.popToViewController(vc, animated: true)
            })
        }
    }

    @objc func didReportGroup(_ cell: TUIButtonCell) {
        if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
            TUITool.openLink(with: url)
        }
    }

    private func findConversationListViewController() -> UIViewController {
        for vc in navigationController?.viewControllers ?? [] {
            if let cls = NSClassFromString("TUIConversation.TUIFoldListViewController") {
                if vc.isKind(of: cls) {
                    return vc
                }
            }
        }
        return navigationController?.viewControllers.first ?? UIViewController()
    }

    @objc func didSelectOnFoldConversation(_ cell: TUICommonSwitchCell) {
        let enableMark = cell.switcher.isOn
       V2TIMManager.sharedInstance().markConversation(conversationIDList: ["group_\(groupId ?? "")"], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue), enableMark: enableMark, succ: { [weak self] _ in
            guard let self else { return }
            cell.switchData?.isOn = enableMark
            TUIConversationPin.sharedInstance.removeTopConversation("group_\(self.groupId ?? "")", callback: { [weak self] _, _ in
                guard let self else { return }
                self.updateGroupInfo()
            })
        }, fail: nil)
    }

    @objc func didSelectOnChangeBackgroundImage(_ cell: TUICommonTextCell) {
        let conversationID = "group_\(groupId ?? "")"
        let vc = TUISelectAvatarController()
        vc.selectAvatarType = .conversationBackgroundCover
        vc.profilFaceURL = getBackgroundImageUrl(by: conversationID) ?? ""
        navigationController?.pushViewController(vc, animated: true)
        vc.selectCallBack = { [weak self] urlStr in
            guard let self else { return }
            self.appendBackgroundImage(urlStr, conversationID: conversationID)
            if !conversationID.isEmpty {
                TUICore.notifyEvent("TUICore_TUIContactNotify", subKey: "TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey", object: self, param: ["TUICore_TUIContactNotify_UpdateConversationBackgroundImageSubKey_ConversationID": conversationID])
            }
        }
    }

    private func getBackgroundImageUrl(by conversationID: String) -> String? {
        guard !conversationID.isEmpty else { return nil }
        let dict = UserDefaults.standard.object(forKey: "conversation_backgroundImage_map") as? [String: String] ?? [:]
        let loginUserID = TUILogin.getUserID()
        let conversationID_UserID = "\(conversationID)_\(loginUserID ?? "")"
        return dict[conversationID_UserID]
    }

    private func appendBackgroundImage(_ imgUrl: String, conversationID: String) {
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
        UserDefaults.standard.setValue(dict, forKey: "conversation_backgroundImage_map")
        UserDefaults.standard.synchronize()
    }

    @objc func didClearAllHistory(_ cell: TUIButtonCell) {
        let ac = UIAlertController(title: nil, message: TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistoryTips"), preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .destructive) { [weak self] _ in
            self?.dataProvider.clearAllHistory(succ: {
                TUICore.notifyEvent("TUICore_TUIConversationNotify", subKey: "TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey", object: self, param: nil)
                TUITool.makeToast("success")
            }, fail: { code, desc in
                TUITool.makeToastError(Int(code), msg: desc)
            })
        })
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    func pushNavigationController() -> UINavigationController? {
        return navigationController
    }

    @objc func didSelectGroupNotice() {
        let vc = TUIGroupNoticeController()
        vc.groupID = groupId
        vc.onNoticeChanged = { [weak self] in
            guard let self else { return }
            self.updateGroupInfo()
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
            guard let self = self, !urlStr.isEmpty else { return }
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

    // MARK: TUIModifyViewDelegate

    func modifyView(_ modifyView: TUIModifyView, didModiyContent content: String) {
        switch modifyView.tag {
        case 0:
            dataProvider.setGroupName(content)
        case 1:
            dataProvider.setGroupNotification(content)
        case 2:
            dataProvider.setGroupMemberNameCard(content)
        default:
            break
        }
    }
}

class IUGroupView: UIView {
    var view: UIView

    override init(frame: CGRect) {
        self.view = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        super.init(frame: frame)
        addSubview(view)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
