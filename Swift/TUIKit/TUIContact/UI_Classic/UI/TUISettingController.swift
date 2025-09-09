// TUISettingController.swift
// TUIKitDemo
//
// Created by lynxzhang on 2018/10/19.
// Copyright © 2018 Tencent. All rights reserved.
//

/** IM Demo

 *  Tencent Cloud Chat Demo settings main interface view
 *  - This file implements the setting interface, that is, the view corresponding to the "Me" button in the TabBar.
 *  - Here you can view and modify your personal information, or perform operations such as logging out.
 *  - This class depends on Tencent Cloud TUIKit and IMSDK
 */

import TIMCommon
import TUICore
import UIKit

let kKeyWeight = "weight"
let kKeyItems = "items"
let kKeyViews = "views"

public protocol TUISettingControllerDelegate: AnyObject {
    func onSwitchMsgReadStatus(_ isOn: Bool)
    func onSwitchOnlineStatus(_ isOn: Bool)
    func onSwitchCallsRecord(_ isOn: Bool)
    func onClickAboutIM()
    func onClickLogout()
    func onChangeStyle()
    func onChangeTheme()
}

public class TUISettingController: UITableViewController, UIActionSheetDelegate, V2TIMSDKListener, TUIProfileCardDelegate, TUIStyleSelectControllerDelegate, TUIThemeSelectControllerDelegate {
    public var lastLoginUser: String?
    public weak var delegate: TUISettingControllerDelegate?

    public var showPersonalCell = true
    public var showMessageReadStatusCell = true
    public var showDisplayOnlineStatusCell = true
    public var showSelectStyleCell = false
    public var showChangeThemeCell = false
    public var showCallsRecordCell = true
    public var showAboutIMCell = true
    public var showLoginOutCell = true

    public var msgNeedReadReceipt = false
    public var displayCallsRecord = false

    public var aboutIMCellText: String?

    private var dataList = [Any]()
    private var profile: V2TIMUserFullInfo?
    private var profileCellData: TUIProfileCardCellData?
    private var styleName: String?
    private var themeName: String?
    private var sortedDataList = [Any]()

    override public init(style: UITableView.Style = .plain) {
        self.showPersonalCell = true
        self.showMessageReadStatusCell = true
        self.showDisplayOnlineStatusCell = true
        self.showCallsRecordCell = true
        self.showSelectStyleCell = false
        self.showChangeThemeCell = false
        self.showAboutIMCell = true
        self.showLoginOutCell = true
        super.init(style: style)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.isHidden = false
        self.tableView.reloadData()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()

        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        var loginUser = V2TIMManager.sharedInstance().getLoginUser()
        if loginUser == nil {
            loginUser = self.lastLoginUser
        }
        if let loginUser = loginUser, !loginUser.isEmpty {
            V2TIMManager.sharedInstance().getUsersInfo([loginUser], succ: { [weak self] infoList in
                guard let self = self, let infoList = infoList else { return }
                self.profile = infoList.first
                self.setupData()
            }) { _, _ in
                // to do
            }
        }

        TUITool.addUnsupportNotification(inVC: self, debugOnly: false)
    }

    private func setupViews() {
        self.tableView.delaysContentTouches = false
        self.tableView.tableFooterView = UIView()
        self.tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")

        self.tableView.register(TUICommonTextCell.self, forCellReuseIdentifier: "textCell")
        self.tableView.register(TUIProfileCardCell.self, forCellReuseIdentifier: "personalCell")
        self.tableView.register(TUIButtonCell.self, forCellReuseIdentifier: "buttonCell")
        self.tableView.register(TUICommonSwitchCell.self, forCellReuseIdentifier: "switchCell")
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "containerCell")

        if #available(iOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0
        }
    }

    public func onSelfInfoUpdated(info: V2TIMUserFullInfo) {
        self.profile = info
        self.setupData()
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return self.sortedDataList.count
    }

    override public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 10
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let dict = self.sortedDataList[section] as? [String: Any] else { return 0 }
        if let views = dict[kKeyViews] as? [UIView] {
            return views.count
        }
        if let items = dict[kKeyItems] as? [Any] {
            return items.count
        }
        return 0
    }

    override public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let dict = self.sortedDataList[indexPath.section] as? [String: Any] else { return 0 }
        if let views = dict[kKeyViews] as? [UIView] {
            let view = views[indexPath.row]
            return view.bounds.size.height
        }
        if let array = dict[kKeyItems] as? [TUICommonCellData] {
            let data = array[indexPath.row]
            return data.height(ofWidth: TUISwift.screen_Width())
        }
        return 0
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let dict = self.sortedDataList[indexPath.section] as? [String: Any] else { return UITableViewCell() }
        if let views = dict[kKeyViews] as? [UIView] {
            let view = views[indexPath.row]
            if let cell = view as? UITableViewCell {
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "containerCell", for: indexPath)
                cell.addSubview(view)
                return cell
            }
        }
        if let array = dict[kKeyItems] as? [Any] {
            let data = array[indexPath.row]
            if let profileData = data as? TUIProfileCardCellData {
                let cell = tableView.dequeueReusableCell(withIdentifier: "personalCell", for: indexPath) as! TUIProfileCardCell
                cell.delegate = self
                cell.fill(with: profileData)
                return cell
            } else if let buttonData = data as? TUIButtonCellData {
                let cell = tableView.dequeueReusableCell(withIdentifier: "buttonCell", for: indexPath) as! TUIButtonCell
                cell.fill(with: buttonData)
                return cell
            } else if let textData = data as? TUICommonTextCellData {
                let cell = tableView.dequeueReusableCell(withIdentifier: "textCell", for: indexPath) as! TUICommonTextCell
                cell.fill(with: textData)
                return cell
            } else if let switchData = data as? TUICommonSwitchCellData {
                let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as! TUICommonSwitchCell
                cell.fill(with: switchData)
                return cell
            }
        }
        return UITableViewCell()
    }

    private func setupData() {
        self.dataList = []

        if self.showPersonalCell {
            let personal = TUIProfileCardCellData()
            personal.identifier = self.profile?.userID ?? ""
            personal.avatarImage = TUISwift.defaultAvatarImage()
            if let url = self.profile?.faceURL,
               let validURL = URL(string: url) {
                personal.avatarUrl = validURL
            } else {
                personal.avatarUrl = nil
            }
            personal.name = self.profile?.showName() ?? ""
            personal.genderString = self.profile?.showGender() ?? ""
            personal.signature = self.profile?.selfSignature != nil ? String(format: TUISwift.timCommonLocalizableString("SignatureFormat"), self.profile?.selfSignature ?? "") : TUISwift.timCommonLocalizableString("no_personal_signature")
            personal.cselector = #selector(self.didSelectCommon)
            personal.showAccessory = true
            personal.showSignature = true
            self.profileCellData = personal
            self.dataList.append([kKeyWeight: 1000, kKeyItems: [personal]])
        }

        let friendApply = TUICommonTextCellData()
        friendApply.key = TUISwift.timCommonLocalizableString("MeFriendRequest")
        friendApply.showAccessory = true
        friendApply.cselector = #selector(self.onEditFriendApply)
        if self.profile?.allowType == .FRIEND_ALLOW_ANY {
            friendApply.value = TUISwift.timCommonLocalizableString("MeFriendRequestMethodAgreeAll")
        }
        if self.profile?.allowType == .FRIEND_NEED_CONFIRM {
            friendApply.value = TUISwift.timCommonLocalizableString("MeFriendRequestMethodNeedConfirm")
        }
        if self.profile?.allowType == .FRIEND_DENY_ANY {
            friendApply.value = TUISwift.timCommonLocalizableString("MeFriendRequestMethodDenyAll")
        }
        self.dataList.append([kKeyWeight: 900, kKeyItems: [friendApply]])

        if self.showMessageReadStatusCell {
            let msgReadStatus = TUICommonSwitchCellData()
            msgReadStatus.title = TUISwift.timCommonLocalizableString("MeMessageReadStatus")
            msgReadStatus.desc = self.msgNeedReadReceipt ? TUISwift.timCommonLocalizableString("MeMessageReadStatusOpenDesc") : TUISwift.timCommonLocalizableString("MeMessageReadStatusCloseDesc")
            msgReadStatus.cswitchSelector = #selector(self.onSwitchMsgReadStatus(_:))
            msgReadStatus.isOn = self.msgNeedReadReceipt
            self.dataList.append([kKeyWeight: 800, kKeyItems: [msgReadStatus]])
        }

        if self.showDisplayOnlineStatusCell {
            let onlineStatus = TUICommonSwitchCellData()
            onlineStatus.title = TUISwift.timCommonLocalizableString("ShowOnlineStatus")
            onlineStatus.desc = TUIConfig.default().displayOnlineStatusIcon ? TUISwift.timCommonLocalizableString("ShowOnlineStatusOpenDesc") : TUISwift.timCommonLocalizableString("ShowOnlineStatusCloseDesc")
            onlineStatus.cswitchSelector = #selector(self.onSwitchOnlineStatus(_:))
            onlineStatus.isOn = TUIConfig.default().displayOnlineStatusIcon
            self.dataList.append([kKeyWeight: 700, kKeyItems: [onlineStatus]])
        }

        if self.showSelectStyleCell {
            let styleApply = TUICommonTextCellData()
            styleApply.key = TUISwift.timCommonLocalizableString("TIMAppSelectStyle")
            styleApply.showAccessory = true
            styleApply.cselector = #selector(self.onClickChangeStyle)
            self.styleName = TUIStyleSelectViewController.isClassicEntrance() ? TUISwift.timCommonLocalizableString("TUIKitClassic") : TUISwift.timCommonLocalizableString("TUIKitMinimalist")
            self.dataList.append([kKeyWeight: 600, kKeyItems: [styleApply]])
        }

        if self.showChangeThemeCell && self.styleName == TUISwift.timCommonLocalizableString("TUIKitClassic") {
            let themeApply = TUICommonTextCellData()
            themeApply.key = TUISwift.timCommonLocalizableString("TIMAppChangeTheme")
            themeApply.showAccessory = true
            themeApply.cselector = #selector(self.onClickChangeTheme)
            self.themeName = TUIThemeSelectController.getLastThemeName()
            self.dataList.append([kKeyWeight: 500, kKeyItems: [themeApply]])
        }

        if self.showCallsRecordCell {
            let record = TUICommonSwitchCellData()
            record.title = TUISwift.timCommonLocalizableString("ShowCallsRecord")
            record.desc = ""
            record.cswitchSelector = #selector(self.onSwitchCallsRecord(_:))
            record.isOn = self.displayCallsRecord
            self.dataList.append([kKeyWeight: 400, kKeyItems: [record]])
        }

        if self.showAboutIMCell {
            let about = TUICommonTextCellData()
            about.key = self.aboutIMCellText ?? ""
            about.showAccessory = true
            about.cselector = #selector(self.onClickAboutIM(_:))
            self.dataList.append([kKeyWeight: 300, kKeyItems: [about]])
        }

        if self.showLoginOutCell {
            let button = TUIButtonCellData()
            button.title = TUISwift.timCommonLocalizableString("logout")
            button.style = .redText
            button.cbuttonSelector = #selector(self.onClickLogout(_:))
            button.hideSeparatorLine = true
            self.dataList.append([kKeyWeight: 200, kKeyItems: [button]])
        }

        self.setupExtensionsData()
        self.sortDataList()

        self.tableView.reloadData()
    }

    private func setupExtensionsData() {
        var param = [String: Any]()
        param["TUICore_TUIContactExtension_MeSettingMenu_Nav"] = self.navigationController
        let extensionList = TUICore.getExtensionList("TUICore_TUIContactExtension_MeSettingMenu_ClassicExtensionID", param: param)
        for info in extensionList {
            guard let data = info.data else {
                assertionFailure("extension for setting is invalid, check data")
                continue
            }
            if let view = data["TUICore_TUIContactExtension_MeSettingMenu_View"] as? UIView,
               let weight = data["TUICore_TUIContactExtension_MeSettingMenu_Weight"] as? Int
            {
                self.dataList.append([kKeyWeight: weight, kKeyViews: [view]])
            }
        }
    }

    private func sortDataList() {
        self.sortedDataList = self.dataList.sorted { obj1, obj2 -> Bool in
            guard let weight1 = (obj1 as? [String: Any])?[kKeyWeight] as? Int,
                  let weight2 = (obj2 as? [String: Any])?[kKeyWeight] as? Int
            else {
                return false
            }
            return weight1 > weight2
        }
    }

    @objc private func didSelectCommon() {
        self.setupData()
        let profileController = TUIProfileController()
        self.navigationController?.pushViewController(profileController, animated: true)
    }

    @objc private func onEditFriendApply() {
        let sheet = UIActionSheet()
        sheet.tag = SHEET_AGREE
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("MeFriendRequestMethodAgreeAll"))
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("MeFriendRequestMethodNeedConfirm"))
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("MeFriendRequestMethodDenyAll"))
        sheet.cancelButtonIndex = sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("Cancel"))
        sheet.delegate = self
        sheet.show(in: self.view)
        self.setupData()
    }

    public func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        if actionSheet.tag == SHEET_AGREE {
            if buttonIndex >= 3 { return }
            self.profile?.allowType = V2TIMFriendAllowType(rawValue: buttonIndex) ?? .FRIEND_ALLOW_ANY
            self.setupData()
            let info = V2TIMUserFullInfo()
            info.allowType = V2TIMFriendAllowType(rawValue: buttonIndex) ?? .FRIEND_ALLOW_ANY
            V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: nil, fail: nil)
        }
    }

    public func didTap(onAvatar cell: TUIProfileCardCell) {
        let image = TUIAvatarViewController()
        image.avatarData = cell.cardData
        self.navigationController?.pushViewController(image, animated: true)
    }

    @objc private func onSwitchMsgReadStatus(_ cell: TUICommonSwitchCell) {
        let on = cell.switcher.isOn
        self.delegate?.onSwitchMsgReadStatus(on)

        if let switchData = cell.switchData {
            switchData.isOn = on
            if on {
                switchData.desc = TUISwift.timCommonLocalizableString("MeMessageReadStatusOpenDesc")
                TUITool.hideToast()
                TUITool.makeToast(TUISwift.timCommonLocalizableString("ShowPackageToast"))
            } else {
                switchData.desc = TUISwift.timCommonLocalizableString("MeMessageReadStatusCloseDesc")
            }
            cell.fill(with: switchData)
        }
    }

    @objc private func onSwitchOnlineStatus(_ cell: TUICommonSwitchCell) {
        let on = cell.switcher.isOn
        self.delegate?.onSwitchOnlineStatus(on)
        TUIConfig.default().displayOnlineStatusIcon = on

        if let switchData = cell.switchData {
            switchData.isOn = on
            if on {
                switchData.desc = TUISwift.timCommonLocalizableString("ShowOnlineStatusOpenDesc")
            } else {
                switchData.desc = TUISwift.timCommonLocalizableString("ShowOnlineStatusCloseDesc")
            }

            if on {
                TUITool.hideToast()
                TUITool.makeToast(TUISwift.timCommonLocalizableString("ShowPackageToast"))
            }

            cell.fill(with: switchData)
        }
    }

    @objc private func onSwitchCallsRecord(_ cell: TUICommonSwitchCell) {
        let on = cell.switcher.isOn
        self.delegate?.onSwitchCallsRecord(on)

        if let data = cell.switchData {
            data.isOn = on
            cell.fill(with: data)
        }
    }

    @objc private func onClickAboutIM(_ cell: TUICommonTextCell) {
        self.delegate?.onClickAboutIM()
    }

    @objc private func onClickChangeStyle() {
        let styleVC = TUIStyleSelectViewController()
        styleVC.delegate = self
        self.navigationController?.pushViewController(styleVC, animated: true)
    }

    @objc private func onClickChangeTheme() {
        let vc = TUIThemeSelectController()
        vc.delegate = self
        self.navigationController?.pushViewController(vc, animated: true)
    }

    public func onSelectStyle(_ cellModel: TUIStyleSelectCellModel) {
        if cellModel.styleName != self.styleName {
            self.styleName = cellModel.styleName
            self.delegate?.onChangeStyle()
        }
    }

    public func onSelectTheme(_ cellModel: TUIThemeSelectCollectionViewCellModel) {
        if cellModel.themeName != self.themeName {
            self.themeName = cellModel.themeName
            self.delegate?.onChangeTheme()
        }
    }

    @objc private func onClickLogout(_ cell: TUIButtonCell) {
        self.delegate?.onClickLogout()
    }
}
