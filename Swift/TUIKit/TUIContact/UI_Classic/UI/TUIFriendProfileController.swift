//  Created by Tencent on 2023/06/09.
//  Copyright © 2023 Tencent. All rights reserved.
/**
 *  Tencent Cloud Communication Service Interface Components TUIKIT - Friends Information Interface
 *  This file implements the friend profile view controller, which is only used when displaying friends.
 *  To display user information for non-friends, see TUIUserProfileController.h
 */

import ImSDK_Plus
import TIMCommon
import UIKit

public class TUIFriendProfileController: UITableViewController, TUIContactProfileCardDelegate {
    var friendProfile: V2TIMFriendInfo?
    private var dataList: [[Any]] = []
    private var modified = false
    private var userFullInfo: V2TIMUserFullInfo?
    private var titleView: TUINaviBarIndicatorView?

    var textValueObservation: NSKeyValueObservation?

    override init(style: UITableView.Style = .grouped) {
        super.init(style: style)
    }

    deinit {
        textValueObservation = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        addLongPressGesture()

        userFullInfo = friendProfile?.userFullInfo
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")

        tableView.register(TUICommonContactTextCell.self, forCellReuseIdentifier: "TextCell")
        tableView.register(TUICommonContactSwitchCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(TUICommonContactProfileCardCell.self, forCellReuseIdentifier: "CardCell")
        tableView.register(TUIButtonCell.self, forCellReuseIdentifier: "ButtonCell")
        tableView.delaysContentTouches = false
        titleView = TUINaviBarIndicatorView()
        titleView?.setTitle(TUISwift.timCommonLocalizableString("ProfileDetails"))
        navigationItem.titleView = titleView
        navigationItem.title = ""

        loadData()
    }

    private func loadData() {
        var list: [[Any]] = []

        list.append({
            var inlist: [Any] = []
            inlist.append({
                let personal = TUICommonContactProfileCardCellData()
                personal.identifier = userFullInfo?.userID
                personal.avatarImage = TUISwift.defaultAvatarImage()
                personal.avatarUrl = URL(string: userFullInfo?.faceURL ?? "")
                personal.name = userFullInfo?.showName()
                personal.genderString = userFullInfo?.showGender()
                personal.signature = userFullInfo?.selfSignature?.isEmpty == false
                    ? String(format: TUISwift.timCommonLocalizableString("SignatureFormat"), userFullInfo?.selfSignature ?? "")
                    : TUISwift.timCommonLocalizableString("no_personal_signature")
                personal.reuseId = "CardCell"
                personal.showSignature = true
                return personal
            }())
            return inlist
        }())

        if isItemShown(.alias) {
            list.append({
                var inlist: [Any] = []
                inlist.append({
                    let data = TUICommonContactTextCellData()
                    data.key = TUISwift.timCommonLocalizableString("ProfileAlia")
                    data.value = friendProfile?.friendRemark ?? TUISwift.timCommonLocalizableString("None")
                    data.showAccessory = true
                    data.cselector = #selector(onChangeRemark(_:))
                    data.reuseId = "TextCell"
                    return data
                }())
                return inlist
            }())
        }

        if isItemShown(.muteAndPin) {
            list.append({
                var inlist: [Any] = []
                inlist.append({
                    let data = TUICommonContactSwitchCellData()
                    data.title = TUISwift.timCommonLocalizableString("ProfileMessageDoNotDisturb")
                    data.cswitchSelector = #selector(onMessageDoNotDisturb(_:))
                    data.reuseId = "SwitchCell"
                    weak var weakSelf = self
                    V2TIMManager.sharedInstance().getC2CReceiveMessageOpt(userIDList: [friendProfile?.userID ?? ""], succ: { optList in
                        if let optList = optList {
                            for info in optList {
                                if info.userID == weakSelf?.friendProfile?.userID {
                                    data.isOn = (info.receiveOpt == .RECEIVE_NOT_NOTIFY_MESSAGE)
                                    weakSelf?.tableView.reloadData()
                                    break
                                }
                            }
                        }
                    }, fail: nil)
                    return data
                }())

                inlist.append({
                    let data = TUICommonContactSwitchCellData()
                    data.title = TUISwift.timCommonLocalizableString("ProfileStickyonTop")
                    data.isOn = false

                    weak var weakSelf = self
                    if let userID = friendProfile?.userID {
                        let conversationID = "c2c_\(userID)"
                        V2TIMManager.sharedInstance().getConversation(conversationID: conversationID, succ: { conv in
                            if let conv = conv {
                                data.isOn = conv.isPinned
                            }
                            weakSelf?.tableView.reloadData()
                        }, fail: { _, _ in })
                    }

                    // TODO: TO BE DELETED
//                    if let userID = friendProfile?.userID {
//                        let conversationID = "c2c_\(userID)"
//                        if TUIConversationPin.sharedInstance.topConversationList().contains(where: { $0 as! String == conversationID }) {
//                            data.isOn = true
//                        }
//                    }

                    data.cswitchSelector = #selector(onTopMostChat(_:))
                    data.reuseId = "SwitchCell"
                    return data
                }())

                return inlist
            }())
        }

        list.append({
            var inlist: [Any] = []
            if isItemShown(.clearChatHistory) {
                inlist.append({
                    let data = TUICommonContactTextCellData()
                    data.key = TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistory")
                    data.showAccessory = true
                    data.cselector = #selector(onClearHistoryChatMessage(_:))
                    data.reuseId = "TextCell"
                    return data
                }())
            }

            if isItemShown(.background) {
                inlist.append({
                    let data = TUICommonContactTextCellData()
                    data.key = TUISwift.timCommonLocalizableString("ProfileSetBackgroundImage")
                    data.showAccessory = true
                    data.cselector = #selector(onChangeBackgroundImage(_:))
                    data.reuseId = "TextCell"
                    return data
                }())
            }

            return inlist
        }())

        if isItemShown(.block) {
            list.append({
                var inlist: [Any] = []
                inlist.append({
                    let data = TUICommonContactSwitchCellData()
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
                    }
                    return data
                }())
                return inlist
            }())
        }

        // Action menu
        list.append({
            var inlist: [Any] = []
            // Extension menus
            var extensionParam: [String: Any] = [:]
            if let userID = friendProfile?.userID, !userID.isEmpty {
                extensionParam["TUICore_TUIContactExtension_FriendProfileActionMenu_UserID"] = userID
            }
            // Check if this is an AI conversation
            let isAIConversation = (friendProfile?.userID ?? "").contains("@RBT#")
            
            if isAIConversation {
                extensionParam["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterVideoCall"] = true
                extensionParam["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterAudioCall"] = true
            } else {
                extensionParam["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterVideoCall"] = false
                extensionParam["TUICore_TUIContactExtension_FriendProfileActionMenu_FilterAudioCall"] = false
            }
            let extensionList = TUICore.getExtensionList("TUICore_TUIContactExtension_FriendProfileActionMenu_ClassicExtensionID", param: extensionParam)
            for info in extensionList {
                if let text = info.text {
                    let data = TUIButtonCellData()
                    data.title = text
                    data.style = .white
                    data.textColor = TUISwift.timCommonDynamicColor("primary_theme_color", defaultColor: "147AFF")
                    data.reuseId = "ButtonCell"
                    data.cbuttonSelector = #selector(onActionMenuExtensionClicked(_:))
                    data.tui_extValueObj = info
                    inlist.append(data)
                }
            }

            // Built-in "Delete Friend" menu
            if isItemShown(.block) {
                inlist.append({
                    let data = TUIButtonCellData()
                    data.title = TUISwift.timCommonLocalizableString("ProfileDeleteFirend")
                    data.style = .redText
                    data.cbuttonSelector = #selector(onDeleteFriend(_:))
                    data.reuseId = "ButtonCell"
                    return data
                }())
            }

            if let lastdata = inlist.last as? TUIButtonCellData {
                lastdata.hideSeparatorLine = true
            }
            return inlist
        }())

        dataList = list
        tableView.reloadData()
    }

    private func isItemShown(_ item: TUIContactConfigItem) -> Bool {
        return !TUIContactConfig.shared.isItemHiddenInContactConfig(item)
    }

    @objc private func onChangeBlackList(_ cell: TUICommonContactSwitchCell) {
        guard let userID = friendProfile?.userID else { return }
        if cell.switcher.isOn {
            V2TIMManager.sharedInstance().addToBlackList(userIDList: [userID], succ: nil, fail: nil)
        } else {
            V2TIMManager.sharedInstance().deleteFromBlackList(userIDList: [userID], succ: nil, fail: nil)
        }
    }

    @objc private func onChangeRemark(_ cell: TUICommonContactTextCell) {
        let vc = TUITextEditController(text: friendProfile?.friendRemark ?? "")
        vc.title = TUISwift.timCommonLocalizableString("ProfileEditAlia")
        vc.textValue = friendProfile?.friendRemark ?? ""
        navigationController?.pushViewController(vc, animated: true)

        textValueObservation = vc.observe(\.textValue, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let friendRemark = change.newValue else { return }
            self.modified = true
            self.friendProfile?.friendRemark = friendRemark
            if let profile = friendProfile {
                V2TIMManager.sharedInstance().setFriendInfo(info: profile, succ: {
                    self.loadData()
                    NotificationCenter.default.post(name: NSNotification.Name("FriendInfoChangedNotification"), object: self.friendProfile)
                }, fail: nil)
            }
        }
    }

    @objc private func onClearHistoryChatMessage(_ cell: TUICommonContactTextCell) {
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

    @objc private func onChangeBackgroundImage(_ cell: TUICommonContactTextCell) {
        guard let userID = friendProfile?.userID else { return }
        let conversationID = "c2c_\(userID)"
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
        UserDefaults.standard.setValue(dict, forKey: "conversation_backgroundImage_map")
        UserDefaults.standard.synchronize()
    }

    // MARK: - UITableViewDataSource

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return dataList.count
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList[section].count
    }

    override public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        return view
    }

    override public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        return view
    }

    override public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 10
    }

    override public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let data = dataList[indexPath.section][indexPath.row]
        if let data = data as? TUICommonContactProfileCardCellData {
            if let cell = tableView.dequeueReusableCell(withIdentifier: "CardCell", for: indexPath) as? TUICommonContactProfileCardCell {
                cell.delegate = self
                cell.fill(with: data)
                return cell
            }
            return UITableViewCell()
        } else if let data = data as? TUIButtonCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ButtonCell") as! TUIButtonCell
            cell.fill(with: data)
            return cell
        } else if let data = data as? TUICommonContactTextCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TextCell", for: indexPath) as! TUICommonContactTextCell
            cell.fill(with: data)
            return cell
        } else if let data = data as? TUICommonContactSwitchCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! TUICommonContactSwitchCell
            cell.fill(with: data)
            return cell
        }
        return UITableViewCell()
    }

    override public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let data = dataList[indexPath.section][indexPath.row] as! TUICommonCellData
        return data.height(ofWidth: TUISwift.screen_Width())
    }

    override public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle row selection
    }

    @objc private func onActionMenuExtensionClicked(_ sender: Any) {
        guard let cell = sender as? TUIButtonCell else { return }
        let data = cell.buttonData
        let info = data?.tui_extValueObj as? TUIExtensionInfo
        if let info = info, let onClicked = info.onClicked {
            var param: [String: Any] = [:]
            if let userID = friendProfile?.userID, !userID.isEmpty {
                param["TUICore_TUIContactExtension_FriendProfileActionMenu_UserID"] = userID
            }
            if let navigationController = navigationController {
                param["TUICore_TUIContactExtension_FriendProfileActionMenu_PushVC"] = navigationController
            }
            onClicked(param)
        }
    }

    @objc private func onVoiceCall(_ sender: Any) {
        let param: [String: Any] = [
            "TUICore_TUICallingService_ShowCallingViewMethod_UserIDsKey": [userFullInfo?.userID ?? ""],
            "TUICore_TUICallingService_ShowCallingViewMethod_CallTypeKey": "0"
        ]
        TUICore.callService("TUICore_TUICallingService", method: "TUICore_TUICallingService_ShowCallingViewMethod", param: param)
    }

    @objc private func onVideoCall(_ sender: Any) {
        let param: [String: Any] = [
            "TUICore_TUICallingService_ShowCallingViewMethod_UserIDsKey": [userFullInfo?.userID ?? ""],
            "TUICore_TUICallingService_ShowCallingViewMethod_CallTypeKey": "1"
        ]
        TUICore.callService("TUICore_TUICallingService", method: "TUICore_TUICallingService_ShowCallingViewMethod", param: param)
    }

    @objc private func onDeleteFriend(_ sender: Any) {
        V2TIMManager.sharedInstance().deleteFromFriendList(userIDList: [friendProfile?.userID ?? ""], deleteType: .FRIEND_TYPE_BOTH, succ: { [weak self] _ in
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
        var title = userFullInfo?.showName() ?? ""
        if let friendRemark = friendProfile?.friendRemark, !friendRemark.isEmpty {
            title = friendRemark
        }
        let param: [String: Any] = [
            "TUICore_TUIChatObjectFactory_ChatViewController_Title": title,
            "TUICore_TUIChatObjectFactory_ChatViewController_UserID": friendProfile?.userID ?? "",
            "TUICore_TUIChatObjectFactory_ChatViewController_ConversationID": "c2c_\(userFullInfo?.userID ?? "")"
        ]
        navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Classic", param: param, forResult: nil)
    }

    @objc private func onMessageDoNotDisturb(_ cell: TUICommonContactSwitchCell) {
        let opt: V2TIMReceiveMessageOpt = cell.switcher.isOn ? .RECEIVE_NOT_NOTIFY_MESSAGE : .RECEIVE_MESSAGE
        V2TIMManager.sharedInstance().setC2CReceiveMessageOpt(userIDList: [friendProfile?.userID ?? ""], opt: opt, succ: nil, fail: nil)
    }

    @objc private func onTopMostChat(_ cell: TUICommonContactSwitchCell) {
        if cell.switcher.isOn {
            TUIConversationPin.sharedInstance.addTopConversation("c2c_\(friendProfile?.userID ?? "")", callback: { success, errorMessage in
                if !success {
                    cell.switcher.isOn.toggle()
                    TUITool.makeToast(errorMessage ?? "")
                }
            })
        } else {
            TUIConversationPin.sharedInstance.removeTopConversation("c2c_\(friendProfile?.userID ?? "")", callback: { success, errorMessage in
                if !success {
                    cell.switcher.isOn.toggle()
                    TUITool.makeToast(errorMessage ?? "")
                }
            })
        }
    }

    private func addLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressAtCell(_:)))
        tableView.addGestureRecognizer(longPress)
    }

    @objc private func didLongPressAtCell(_ longPress: UILongPressGestureRecognizer) {
        if longPress.state == .began {
            let point = longPress.location(in: tableView)
            guard let pathAtView = tableView.indexPathForRow(at: point) else { return }
            let data = tableView.cellForRow(at: pathAtView)

            if let textCell = data as? TUICommonContactTextCell,
               let textData = textCell.textData,
               let value = textData.value, value != "未设置"
            {
                UIPasteboard.general.string = value
                let toastString = "已将 \(textData.key ?? "") 复制到粘贴板"
                TUITool.makeToast(toastString)
            } else if let profileCard = data as? TUICommonContactProfileCardCell,
                      let cardData = profileCard.cardData,
                      let identifier = cardData.identifier
            {
                UIPasteboard.general.string = identifier
                let toastString = "已将该用户账号复制到粘贴板"
                TUITool.makeToast(toastString)
            }
        }
    }

    @objc func didTapOnAvatar(cell: TUICommonContactProfileCardCell) {
        let image = TUIContactAvatarViewController()
        image.avatarData = cell.cardData
        navigationController?.pushViewController(image, animated: true)
    }

    static func isMarkedByHideType(_ markList: [NSNumber]) -> Bool {
        return markList.contains { $0.uintValue == V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue }
    }
}
