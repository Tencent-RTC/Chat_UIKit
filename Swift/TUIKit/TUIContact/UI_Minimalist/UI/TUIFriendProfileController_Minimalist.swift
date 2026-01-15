//  TUIFriendProfileController_Minimalist.swift
//  TUIContact

import TIMCommon
import TUICore
import UIKit

class TUIFriendProfileController_Minimalist: UIViewController, UITableViewDelegate, UITableViewDataSource, TUIFloatSubViewControllerProtocol, TUINotificationProtocol {
    var floatDataSourceChanged: (([Any]) -> Void)?
    
    var friendProfile: V2TIMFriendInfo?
    private var dataList: [[Any]] = []
    private var modified = false
    private var userFullInfo: V2TIMUserFullInfo!
    private var titleView: TUINaviBarIndicatorView!
    private var headerView: TUIFriendProfileHeaderView_Minimalist!
    private var textValueObservation: NSKeyValueObservation?
    private var scrollView: UIScrollView!

    lazy var tableView: UITableView = {
        let rect = view.bounds
        let tableView = UITableView(frame: rect, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#FFFFFF")

        tableView.register(TUICommonContactTextCell_Minimalist.self, forCellReuseIdentifier: "TextCell")
        tableView.register(TUICommonContactSwitchCell_Minimalist.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(TUIContactButtonCell_Minimalist.self, forCellReuseIdentifier: "ButtonCell")
        tableView.delaysContentTouches = false
        tableView.separatorColor = UIColor.clear
        return tableView
    }()

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            if modified {
                // Handle modifications
            }
        }
    }

    deinit {
        textValueObservation = nil
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        addLongPressGesture()

        scrollView = UIScrollView(frame: view.bounds)
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        tableView.frame = scrollView.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.addSubview(tableView)
        scrollView.contentSize = tableView.bounds.size

        titleView = TUINaviBarIndicatorView()
        titleView.setTitle(TUISwift.timCommonLocalizableString("ProfileDetails"))
        navigationItem.titleView = titleView
        navigationItem.title = ""

        userFullInfo = friendProfile?.userFullInfo
        
        // Register unified voice message settings reload notification
        TUICore.registerEvent(
            "TUICore_TUIVoiceMessageNotify",
            subKey: "TUICore_TUIVoiceMessageNotify_ReloadDataSubKey",
            object: self
        )

        setupHeaderViewData()
        loadData()
    }

    private func setupHeaderViewData() {
        headerView = TUIFriendProfileHeaderView_Minimalist()
        headerView.headImg.sd_setImage(with: URL(string: userFullInfo.faceURL ?? ""), placeholderImage: TUISwift.defaultAvatarImage())
        headerView.descriptionLabel.text = userFullInfo.showName()
        tableView.tableHeaderView = headerView

        // Banner extension
        var param: [String: Any] = [:]
        let userID = userFullInfo.userID ?? ""
        if !userID.isEmpty {
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_UserID"] = userID
        }
        let showName = userFullInfo.showName()
        if !showName.isEmpty {
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_UserName"] = showName
        }
        if let image = headerView.headImg.image {
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_UserIcon"] = image
        }
        // Check if this is an AI conversation
        let isAIConversation = (userFullInfo.userID ?? "").contains("@RBT#")
        
        if isAIConversation {
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterVideoCall"] = true
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterAudioCall"] = true
        } else {
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterVideoCall"] = false
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterAudioCall"] = false
        }
        if let navigationController = navigationController {
            param["TUICore_TUIContactExtension_FriendProfileActionMenu_PushVC"] = navigationController
        }
        var itemViewList: [TUIFriendProfileHeaderItemView] = []
        let extensionList = TUICore.getExtensionList("TUICore_TUIContactExtension_FriendProfileActionMenu_MinimalistExtensionID", param: param)
        for info in extensionList {
            if let text = info.text, let icon = info.icon, let onClicked = info.onClicked {
                let itemView = TUIFriendProfileHeaderItemView()
                itemView.textLabel.text = text
                itemView.iconView.image = icon
                itemView.messageBtnClickBlock = {
                    onClicked(param)
                }
                itemViewList.append(itemView)
            }
        }
        if !itemViewList.isEmpty {
            headerView.setItemViewList(itemViewList)
            headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: TUISwift.kScale390(355))
        } else {
            headerView.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: TUISwift.kScale390(257))
        }
    }

    private func loadData() {
        var list: [[Any]] = []

        if !TUIContactConfig.shared.isItemHiddenInContactConfig(.alias) {
            list.append([{
                let data = TUICommonContactTextCellData_Minimalist()
                data.key = TUISwift.timCommonLocalizableString("ProfileAlia")
                data.value = friendProfile?.friendRemark
                if data.value == nil || data.value!.isEmpty {
                    data.value = TUISwift.timCommonLocalizableString("None")
                }
                data.showAccessory = true
                data.cselector = #selector(onChangeRemark(_:))
                data.reuseId = "TextCell"
                return data
            }()])
        }
        
        // Voice message settings section
        if let userID = friendProfile?.userID {
            let extensionParam: [String: Any] = ["userID": userID]
            let extensionList = TUICore.getExtensionList(
                "TUICore_TUIContactExtension_FriendProfileSettingsSwitch_MinimalistExtensionID",
                param: extensionParam
            )
            
            if !extensionList.isEmpty {
                var voiceSettingsArray: [Any] = []
                for info in extensionList {
                    if let infoData = info.data,
                       let displayValue = infoData["displayValue"] as? String {
                        let textData = TUICommonContactTextCellData_Minimalist()
                        textData.key = info.text ?? ""
                        textData.value = displayValue
                        textData.showAccessory = true
                        textData.cselector = #selector(onVoiceSettingClicked(_:))
                        textData.reuseId = "TextCell"
                        textData.tui_extValueObj = info
                        voiceSettingsArray.append(textData)
                    }
                }
                if !voiceSettingsArray.isEmpty {
                    list.append(voiceSettingsArray)
                }
            }
        }

        if !TUIContactConfig.shared.isItemHiddenInContactConfig(.muteAndPin) {
            list.append([{
                let data = TUICommonContactSwitchCellData_Minimalist()
                data.title = TUISwift.timCommonLocalizableString("ProfileMessageDoNotDisturb")
                data.cswitchSelector = #selector(onMessageDoNotDisturb(_:))
                data.reuseId = "SwitchCell"
                V2TIMManager.sharedInstance().getC2CReceiveMessageOpt(userIDList: [friendProfile?.userID ?? ""], succ: { [weak self] optList in
                    guard let self = self, let optList = optList else { return }
                    for info in optList {
                        if info.userID == self.friendProfile?.userID {
                            data.isOn = (info.receiveOpt == .RECEIVE_NOT_NOTIFY_MESSAGE)
                            self.tableView.reloadData()
                            break
                        }
                    }
                }, fail: nil)
                return data
            }(), {
                let data = TUICommonContactSwitchCellData_Minimalist()
                data.title = TUISwift.timCommonLocalizableString("ProfileStickyonTop")
                data.isOn = false

                if let userID = friendProfile?.userID {
                    V2TIMManager.sharedInstance().getConversation(conversationID: "c2c_\(userID)", succ: { [weak self] conv in
                        guard let self = self else { return }
                        if let conv = conv {
                            data.isOn = conv.isPinned
                            self.tableView.reloadData()
                        }
                    }, fail: { _, _ in
                        // Handle failure
                    })
                }

                // TODO: TO BE DELETED
//                if let userID = friendProfile?.userID {
//                    let conversationID = "c2c_\(userID)"
//                    if TUIConversationPin.sharedInstance.topConversationList().contains(where: { $0 as! String == conversationID }) {
//                        data.isOn = true
//                    }
//                }

                data.cswitchSelector = #selector(onTopMostChat(_:))
                data.reuseId = "SwitchCell"
                return data
            }()])
        }

        if !TUIContactConfig.shared.isItemHiddenInContactConfig(.background) {
            list.append([{
                let data = TUICommonContactTextCellData_Minimalist()
                data.key = TUISwift.timCommonLocalizableString("ProfileSetBackgroundImage")
                data.showAccessory = true
                data.cselector = #selector(onChangeBackgroundImage(_:))
                data.reuseId = "TextCell"
                return data
            }()])
        }

        if !TUIContactConfig.shared.isItemHiddenInContactConfig(.block) {
            list.append([{
                let data = TUICommonContactSwitchCellData_Minimalist()
                data.title = TUISwift.timCommonLocalizableString("ProfileBlocked")
                data.cswitchSelector = #selector(onChangeBlackList(_:))
                data.reuseId = "SwitchCell"
                V2TIMManager.sharedInstance().getBlackList(succ: { [weak self] infoList in
                    guard let self = self, let infoList = infoList else { return }
                    for friend in infoList {
                        if friend.userID == self.friendProfile?.userID {
                            data.isOn = true
                            self.tableView.reloadData()
                            break
                        }
                    }
                }) { _, _ in
                    // to do
                }
                return data
            }()])
        }

        var inlist: [Any] = []
        if !TUIContactConfig.shared.isItemHiddenInContactConfig(.clearChatHistory) {
            inlist.append({
                let data = TUIContactButtonCellData_Minimalist()
                data.title = TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistory")
                data.style = .redText
                data.cbuttonSelector = #selector(onClearHistoryChatMessage(_:))
                data.reuseId = "ButtonCell"
                return data
            }())
        }

        if !TUIContactConfig.shared.isItemHiddenInContactConfig(.delete) {
            inlist.append({
                let data = TUIContactButtonCellData_Minimalist()
                data.title = TUISwift.timCommonLocalizableString("ProfileDeleteFirend")
                data.style = .redText
                data.cbuttonSelector = #selector(onDeleteFriend(_:))
                data.reuseId = "ButtonCell"
                return data
            }())
        }

        if let lastdata = inlist.last as? TUIContactButtonCellData_Minimalist {
            lastdata.hideSeparatorLine = true
        }
        list.append(inlist)

        dataList = list
        tableView.reloadData()
    }

    @objc private func onChangeBlackList(_ cell: TUICommonContactSwitchCell_Minimalist) {
        guard let userID = friendProfile?.userID else { return }
        if cell.switcher.isOn {
            V2TIMManager.sharedInstance().addToBlackList(userIDList: [userID], succ: nil, fail: nil)
        } else {
            V2TIMManager.sharedInstance().deleteFromBlackList(userIDList: [userID], succ: nil, fail: nil)
        }
    }

    @objc private func onChangeRemark(_ cell: TUICommonContactTextCell_Minimalist) {
        let vc = TUITextEditController_Minimalist(text: friendProfile?.friendRemark ?? "")
        vc.title = TUISwift.timCommonLocalizableString("ProfileEditAlia")
        vc.textValue = friendProfile?.friendRemark
        navigationController?.pushViewController(vc, animated: true)

        textValueObservation = vc.observe(\.textValue, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let friendProfile = self.friendProfile, let friendRemark = change.newValue else { return }
            self.modified = true
            friendProfile.friendRemark = friendRemark
            V2TIMManager.sharedInstance().setFriendInfo(info: friendProfile, succ: {
                self.loadData()
                NotificationCenter.default.post(name: NSNotification.Name("FriendInfoChangedNotification"), object: self.friendProfile)
            }, fail: nil)
        }
    }

    @objc private func onClearHistoryChatMessage(_ cell: TUICommonContactTextCell_Minimalist) {
        guard let userID = friendProfile?.userID, !userID.isEmpty else { return }
        let ac = UIAlertController(title: nil, message: TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistoryTips"), preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .destructive, handler: { [weak self] _ in
            guard let self = self else { return }
            V2TIMManager.sharedInstance().clearC2CHistoryMessage(userID: userID, succ: {
                TUICore.notifyEvent("TUICore_TUIConversationNotify", subKey: "TUICore_TUIConversationNotify_ClearConversationUIHistorySubKey", object: self, param: nil)
                TUITool.makeToast("success")
            }, fail: { code, desc in
                TUITool.makeToastError(Int(code), msg: desc)
            })
        }))
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))
        present(ac, animated: true, completion: nil)
    }

    @objc private func onChangeBackgroundImage(_ cell: TUICommonContactTextCell_Minimalist) {
        let conversationID = "c2c_\(friendProfile?.userID ?? "")"
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

    private func getBackgroundImageUrlByConversationID(_ targerConversationID: String) -> String? {
        guard !targerConversationID.isEmpty else { return nil }
        let dict = UserDefaults.standard.object(forKey: "conversation_backgroundImage_map") as? [String: String] ?? [:]
        let loginUserID = TUILogin.getUserID()
        let conversationID_UserID = "\(targerConversationID)_\(loginUserID ?? "")"
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
        UserDefaults.standard.set(dict, forKey: "conversation_backgroundImage_map")
        UserDefaults.standard.synchronize()
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return dataList.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList[section].count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#FFFFFF")
        return view
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#FFFFFF")
        return view
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 10
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let data = dataList[indexPath.section][indexPath.row]
        if let data = data as? TUIContactButtonCellData_Minimalist {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell") as? TUIContactButtonCell_Minimalist ?? TUIContactButtonCell_Minimalist(style: .default, reuseIdentifier: "ButtonCell")
            cell.fill(with: data)
            cell.backgroundColor = UIColor.tui_color(withHex: "#f9f9f9")
            return cell

        } else if let data = data as? TUICommonContactTextCellData_Minimalist {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as! TUICommonContactTextCell_Minimalist
            cell.fill(with: data)
            return cell

        } else if let data = data as? TUICommonContactSwitchCellData_Minimalist {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! TUICommonContactSwitchCell_Minimalist
            cell.fill(with: data)
            return cell
        }

        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let data = dataList[indexPath.section][indexPath.row] as? TUICommonCellData {
            return data.height(ofWidth: TUISwift.screen_Width())
        }
        return 0
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle cell selection
    }

    @objc private func onVoiceCall(_ sender: Any) {
        let param: [String: Any] = [
            "TUICore_TUICallingService_ShowCallingViewMethod_UserIDsKey": [userFullInfo.userID ?? ""],
            "TUICore_TUICallingService_ShowCallingViewMethod_CallTypeKey": "0"
        ]
        TUICore.callService("TUICore_TUICallingService", method: "TUICore_TUICallingService_ShowCallingViewMethod", param: param)
    }

    @objc private func onVideoCall(_ sender: Any) {
        let param: [String: Any] = [
            "TUICore_TUICallingService_ShowCallingViewMethod_UserIDsKey": [userFullInfo.userID ?? ""],
            "TUICore_TUICallingService_ShowCallingViewMethod_CallTypeKey": "1"
        ]
        TUICore.callService("TUICore_TUICallingService", method: "TUICore_TUICallingService_ShowCallingViewMethod", param: param)
    }

    @objc private func onDeleteFriend(_ sender: Any) {
        guard let userID = friendProfile?.userID else { return }
        V2TIMManager.sharedInstance().deleteFromFriendList(userIDList: [userID], deleteType: .FRIEND_TYPE_BOTH, succ: { [weak self] _ in
            guard let self = self else { return }
            self.modified = true
            TUIConversationPin.sharedInstance.removeTopConversation("c2c_\(self.friendProfile?.userID ?? "")", callback: nil)
            let conversationID = "c2c_\(self.friendProfile?.userID ?? "")"
            if !conversationID.isEmpty {
                TUICore.notifyEvent("TUICore_TUIConversationNotify", subKey: "TUICore_TUIConversationNotify_RemoveConversationSubKey", object: self, param: ["TUICore_TUIConversationNotify_RemoveConversationSubKey_ConversationID": conversationID])
            }
            self.navigationController?.popToRootViewController(animated: true)
        }, fail: nil)
    }

    @objc private func onSendMessage(_ sender: Any) {
        var avatarImage = UIImage()
        if let image = headerView.headImg.image {
            avatarImage = image
        }

        var title = ""
        if let info = friendProfile?.userFullInfo {
            title = info.showName()
        }
        if let friendRemark = friendProfile?.friendRemark, !friendRemark.isEmpty {
            title = friendRemark
        }

        let param: [String: Any] = [
            "TUICore_TUIChatObjectFactory_ChatViewController_Title": title,
            "TUICore_TUIChatObjectFactory_ChatViewController_UserID": friendProfile?.userID ?? "",
            "TUICore_TUIChatObjectFactory_ChatViewController_ConversationID": "c2c_\(userFullInfo.userID ?? "")",
            "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": avatarImage
        ]
        navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Minimalist", param: param, forResult: nil)
    }

    @objc private func onMessageDoNotDisturb(_ cell: TUICommonContactSwitchCell_Minimalist) {
        guard let friendProfile = friendProfile else { return }
        let opt: V2TIMReceiveMessageOpt = (cell.switcher.isOn ? .RECEIVE_NOT_NOTIFY_MESSAGE : .RECEIVE_MESSAGE)
        if let userID = friendProfile.userID {
            V2TIMManager.sharedInstance().setC2CReceiveMessageOpt(userIDList: [userID], opt: opt, succ: nil, fail: nil)
        }
    }

    @objc private func onTopMostChat(_ cell: TUICommonContactSwitchCell_Minimalist) {
        if cell.switcher.isOn {
            TUIConversationPin.sharedInstance.addTopConversation("c2c_\(friendProfile?.userID ?? "")", callback: { success, errorMessage in
                if success {
                    return
                }
                cell.switcher.isOn.toggle()
                TUITool.makeToast(errorMessage ?? "")
            })
        } else {
            TUIConversationPin.sharedInstance.removeTopConversation("c2c_\(friendProfile?.userID ?? "")", callback: { success, errorMessage in
                if success {
                    return
                }
                cell.switcher.isOn.toggle()
                TUITool.makeToast(errorMessage ?? "")
            })
        }
    }
    
    @objc private func onVoiceSettingClicked(_ cell: TUICommonContactTextCell_Minimalist) {
        guard let extensionInfo = cell.data?.tui_extValueObj as? TUIExtensionInfo,
              let onClicked = extensionInfo.onClicked
        else { return }
        
        onClicked([
            "viewController": self,
            "pushVC": navigationController as Any
        ])
    }

    private func addLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressAtCell(_:)))
        tableView.addGestureRecognizer(longPress)
    }

    @objc private func didLongPressAtCell(_ longPress: UILongPressGestureRecognizer) {
        if longPress.state == .began {
            let point = longPress.location(in: tableView)
            if let pathAtView = tableView.indexPathForRow(at: point) {
                let data = tableView.cellForRow(at: pathAtView)

                if let textCell = data as? TUICommonContactTextCell, let value = textCell.textData?.value, value != "未设置" {
                    UIPasteboard.general.string = value
                    let toastString = "已将 \(textCell.textData?.key ?? "") 复制到粘贴板"
                    TUITool.makeToast(toastString)
                } else if let profileCard = data as? TUICommonContactProfileCardCell_Minimalist, let identifier = profileCard.cardData?.identifier {
                    UIPasteboard.general.string = identifier
                    let toastString = "已将该用户账号复制到粘贴板"
                    TUITool.makeToast(toastString)
                }
            }
        }
    }

    @objc private func didTapOnAvatar(_ cell: TUICommonContactProfileCardCell_Minimalist) {
        let image = TUIContactAvatarViewController_Minimalist()
        image.avatarData = cell.cardData
        navigationController?.pushViewController(image, animated: true)
    }

    static func isMarkedByHideType(_ markList: [NSNumber]) -> Bool {
        return markList.contains { $0.uintValue == V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue }
    }
    
    // MARK: - TUINotificationProtocol
    
    func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIVoiceMessageNotify",
           subKey == "TUICore_TUIVoiceMessageNotify_ReloadDataSubKey" {
            loadData()
        }
    }
}
