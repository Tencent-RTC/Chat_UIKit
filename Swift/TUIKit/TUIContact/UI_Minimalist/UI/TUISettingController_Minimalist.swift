//  TUISettingController_Minimalist.swift
//  TUIContact

import TIMCommon
import TUICore
import UIKit

public protocol TUISettingControllerDelegate_Minimalist: AnyObject {
    func onSwitchMsgReadStatus(_ isOn: Bool)
    func onSwitchOnlineStatus(_ isOn: Bool)
    func onSwitchCallsRecord(_ isOn: Bool)
    func onClickAboutIM()
    func onClickLogout()
    func onChangeStyle()
    func onChangeTheme()
}

class TUILogOutButtonCell: TUIButtonCell {
    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = CGRect(x: TUISwift.kScale390(16),
                              y: 0,
                              width: UIScreen.main.bounds.width - 2 * TUISwift.kScale390(16),
                              height: bounds.height - CGFloat(TButtonCell_Margin))
        button.layer.cornerRadius = TUISwift.kScale390(10)
        button.layer.masksToBounds = true
        button.backgroundColor = UIColor.tui_color(withHex: "f9f9f9")
    }
}

public class TUISettingController_Minimalist: UITableViewController, UIActionSheetDelegate, V2TIMSDKListener, TUIContactProfileCardCellDelegate_Minimalist, TUIStyleSelectControllerDelegate, TUIThemeSelectControllerDelegate {
    
    public var lastLoginUser: String?
    public weak var delegate: TUISettingControllerDelegate_Minimalist?

    public var showPersonalCell = true
    public var showMessageReadStatusCell = true
    public var showDisplayOnlineStatusCell = true
    public var showSelectStyleCell = false
    public var showChangeThemeCell = false
    public var showCallsRecordCell = true
    public var showAboutIMCell = false
    public var showLoginOutCell = true

    public var msgNeedReadReceipt = false
    public var displayCallsRecord = false

    public var aboutIMCellText: String?

    private var dataList: [Any] = []
    private var profile: V2TIMUserFullInfo?
    private var profileCellData: TUIContactProfileCardCellData_Minimalist?
    private var titleView: TUINaviBarIndicatorView?
    private var styleName: String?
    private var themeName: String?
    private var sortedDataList: [Any] = []

    override public init(style: UITableView.Style) {
        super.init(style: style)
        self.showPersonalCell = true
        self.showMessageReadStatusCell = true
        self.showDisplayOnlineStatusCell = true
        self.showCallsRecordCell = true
        self.showSelectStyleCell = false
        self.showChangeThemeCell = false
        self.showLoginOutCell = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setupViews()

        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        var loginUser = V2TIMManager.sharedInstance().getLoginUser()
        if loginUser == nil {
            loginUser = lastLoginUser
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

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.isHidden = false
    }

    private func setupViews() {
        tableView.delaysContentTouches = false
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .white

        tableView.register(TUICommonTextCell.self, forCellReuseIdentifier: "textCell")
        tableView.register(TUIContactProfileCardCell_Minimalist.self, forCellReuseIdentifier: "personalCell")
        tableView.register(TUILogOutButtonCell.self, forCellReuseIdentifier: "buttonCell")
        tableView.register(TUICommonSwitchCell.self, forCellReuseIdentifier: "switchCell")
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "containerCell")

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
    }

    public func onSelfInfoUpdated(info: V2TIMUserFullInfo) {
        profile = info
        setupData()
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return sortedDataList.count
    }

    override public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        if section != 1 {
            let line = UIView()
            line.backgroundColor = TUISwift.tuiDemoDynamicColor("separator_color", defaultColor: "#DBDBDB")
            line.frame = CGRect(x: TUISwift.kScale390(16), y: view.frame.size.height - 0.5, width: TUISwift.screen_Width() - TUISwift.kScale390(32), height: 0.5)
            view.addSubview(line)
        }
        return view
    }

    override public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 {
            return 0
        } else if section == dataList.count - 1 {
            return TUISwift.kScale390(37)
        } else {
            return 10
        }
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let dict = sortedDataList[section] as? [String: Any]
        if let views = dict?[kKeyViews] as? [UIView] {
            return views.count
        }
        if let items = dict?[kKeyItems] as? [Any] {
            return items.count
        }
        return 0
    }

    override public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let dict = sortedDataList[indexPath.section] as? [String: Any]
        if let views = dict?[kKeyViews] as? [UIView] {
            return views[indexPath.row].bounds.size.height
        }
        if let array = dict?[kKeyItems] as? [TUICommonCellData] {
            let data = array[indexPath.row]
            return data.height(ofWidth: TUISwift.screen_Width())
        }
        return 0
    }

    override public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let dict = sortedDataList[indexPath.section] as? [String: Any]
        if let views = dict?[kKeyViews] as? [UIView] {
            let view = views[indexPath.row]
            if let cell = view as? UITableViewCell {
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: "containerCell", for: indexPath)
                cell.addSubview(view)
                return cell
            }
        }
        if let array = dict?[kKeyItems] as? [Any] {
            let data = array[indexPath.row]
            if let data = data as? TUIContactProfileCardCellData_Minimalist {
                let cell = tableView.dequeueReusableCell(withIdentifier: "personalCell", for: indexPath) as! TUIContactProfileCardCell_Minimalist
                cell.delegate = self
                cell.fill(with: data)
                return cell
            } else if let data = data as? TUIButtonCellData {
                var cell = tableView.dequeueReusableCell(withIdentifier: "TButtonCell") as? TUILogOutButtonCell
                if cell == nil {
                    cell = TUILogOutButtonCell(style: .default, reuseIdentifier: "TButtonCell")
                }
                cell?.fill(with: data)
                return cell!
            } else if let data = data as? TUICommonTextCellData {
                let cell = tableView.dequeueReusableCell(withIdentifier: "textCell", for: indexPath) as! TUICommonTextCell
                cell.fill(with: data)
                return cell
            } else if let data = data as? TUICommonSwitchCellData {
                let cell = tableView.dequeueReusableCell(withIdentifier: "switchCell", for: indexPath) as! TUICommonSwitchCell
                cell.fill(with: data)
                return cell
            }
        }
        return UITableViewCell()
    }

    private func setupData() {
        dataList = []

        if showPersonalCell {
            let personal = TUIContactProfileCardCellData_Minimalist()
            personal.identifier = profile?.userID ?? ""
            personal.avatarImage = TUISwift.defaultAvatarImage()
            personal.avatarUrl = URL(string: profile?.faceURL ?? "")
            personal.name = profile?.showName() ?? ""
            personal.genderString = profile?.showGender() ?? ""
            personal.signature = profile?.selfSignature != nil ? String(format: TUISwift.timCommonLocalizableString("SignatureFormat"), profile?.selfSignature ?? "") : TUISwift.timCommonLocalizableString("no_personal_signature")
            personal.cselector = #selector(didSelectCommon)
            personal.showAccessory = false
            personal.showSignature = true
            profileCellData = personal
            dataList.append([kKeyWeight: 1000, kKeyItems: [personal]])
        }

        let friendApply = TUICommonTextCellData()
        friendApply.key = TUISwift.timCommonLocalizableString("MeFriendRequest")
        friendApply.showAccessory = true
        friendApply.cselector = #selector(onEditFriendApply)
        if profile?.allowType == .FRIEND_ALLOW_ANY {
            friendApply.value = TUISwift.timCommonLocalizableString("MeFriendRequestMethodAgreeAll")
        }
        if profile?.allowType == .FRIEND_NEED_CONFIRM {
            friendApply.value = TUISwift.timCommonLocalizableString("MeFriendRequestMethodNeedConfirm")
        }
        if profile?.allowType == .FRIEND_DENY_ANY {
            friendApply.value = TUISwift.timCommonLocalizableString("MeFriendRequestMethodDenyAll")
        }
        dataList.append([kKeyWeight: 900, kKeyItems: [friendApply]])

        if showMessageReadStatusCell {
            let msgReadStatus = TUICommonSwitchCellData()
            msgReadStatus.title = TUISwift.timCommonLocalizableString("MeMessageReadStatus")
            msgReadStatus.desc = msgNeedReadReceipt ? TUISwift.timCommonLocalizableString("MeMessageReadStatusOpenDesc") : TUISwift.timCommonLocalizableString("MeMessageReadStatusCloseDesc")
            msgReadStatus.cswitchSelector = #selector(onSwitchMsgReadStatus(_:))
            msgReadStatus.isOn = msgNeedReadReceipt
            dataList.append([kKeyWeight: 800, kKeyItems: [msgReadStatus]])
        }

        if showDisplayOnlineStatusCell {
            let onlineStatus = TUICommonSwitchCellData()
            onlineStatus.title = TUISwift.timCommonLocalizableString("ShowOnlineStatus")
            onlineStatus.desc = TUIConfig.default().displayOnlineStatusIcon ? TUISwift.timCommonLocalizableString("ShowOnlineStatusOpenDesc") : TUISwift.timCommonLocalizableString("ShowOnlineStatusCloseDesc")
            onlineStatus.cswitchSelector = #selector(onSwitchOnlineStatus(_:))
            onlineStatus.isOn = TUIConfig.default().displayOnlineStatusIcon
            dataList.append([kKeyWeight: 700, kKeyItems: [onlineStatus]])
        }

        if showSelectStyleCell {
            let styleApply = TUICommonTextCellData()
            styleApply.key = TUISwift.timCommonLocalizableString("TIMAppSelectStyle")
            styleApply.showAccessory = true
            styleApply.cselector = #selector(onClickChangeStyle)
            styleName = TUIStyleSelectViewController.isClassicEntrance() ? TUISwift.timCommonLocalizableString("TUIKitClassic") : TUISwift.timCommonLocalizableString("TUIKitMinimalist")
            dataList.append([kKeyWeight: 600, kKeyItems: [styleApply]])
        }

        if showChangeThemeCell && styleName == TUISwift.timCommonLocalizableString("TUIKitClassic") {
            let themeApply = TUICommonTextCellData()
            themeApply.key = TUISwift.timCommonLocalizableString("TIMAppChangeTheme")
            themeApply.showAccessory = true
            themeApply.cselector = #selector(onClickChangeTheme)
            themeName = TUIThemeSelectController.getLastThemeName()
            dataList.append([kKeyWeight: 500, kKeyItems: [themeApply]])
        }

        if showCallsRecordCell {
            let record = TUICommonSwitchCellData()
            record.title = TUISwift.timCommonLocalizableString("ShowCallsRecord")
            record.desc = ""
            record.cswitchSelector = #selector(onSwitchCallsRecord(_:))
            record.isOn = displayCallsRecord
            dataList.append([kKeyWeight: 400, kKeyItems: [record]])
        }

        if showAboutIMCell {
            let about = TUICommonTextCellData()
            about.key = aboutIMCellText ?? ""
            about.showAccessory = true
            about.cselector = #selector(onClickAboutIM(_:))
            dataList.append([kKeyWeight: 300, kKeyItems: [about]])
        }

        if showLoginOutCell {
            let button = TUIButtonCellData()
            button.title = TUISwift.timCommonLocalizableString("logout")
            button.style = .redText
            button.cbuttonSelector = #selector(onClickLogout(_:))
            button.hideSeparatorLine = true
            dataList.append([kKeyWeight: 200, kKeyItems: [button]])
        }

        setupExtensionsData()
        sortDataList()

        tableView.reloadData()
    }

    private func setupExtensionsData() {
        var param: [String: Any] = [:]
        param["TUICore_TUIContactExtension_MeSettingMenu_Nav"] = navigationController
        let extensionList = TUICore.getExtensionList("TUICore_TUIContactExtension_MeSettingMenu_MinimalistExtensionID", param: param)
        for info in extensionList {
            guard let data = info.data else {
                assertionFailure("extension for setting is invalid, check data")
                continue
            }
            if let view = data["TUICore_TUIContactExtension_MeSettingMenu_View"] as? UIView, let weight = data["TUICore_TUIContactExtension_MeSettingMenu_Weight"] as? Int {
                dataList.append([kKeyWeight: weight, kKeyViews: [view]])
            }
        }
    }

    private func sortDataList() {
        sortedDataList = dataList.sorted { obj1, obj2 -> Bool in
            let weight1 = (obj1 as? [String: Any])?[kKeyWeight] as? Int ?? 0
            let weight2 = (obj2 as? [String: Any])?[kKeyWeight] as? Int ?? 0
            return weight1 > weight2
        }
    }

    @objc private func didSelectCommon() {
        setupData()
        let profileController = TUIProfileController_Minimalist()
        navigationController?.pushViewController(profileController, animated: true)
    }

    @objc private func onEditFriendApply() {
        let sheet = UIActionSheet()
        sheet.tag = SHEET_AGREE
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("MeFriendRequestMethodAgreeAll"))
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("MeFriendRequestMethodNeedConfirm"))
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("MeFriendRequestMethodDenyAll"))
        sheet.cancelButtonIndex = sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("Cancel"))
        sheet.delegate = self
        sheet.show(in: view)
        setupData()
    }

    public func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        if actionSheet.tag == SHEET_AGREE {
            if buttonIndex >= 3 { return }
            profile?.allowType = V2TIMFriendAllowType(rawValue: buttonIndex) ?? .FRIEND_ALLOW_ANY
            setupData()
            let info = V2TIMUserFullInfo()
            info.allowType = V2TIMFriendAllowType(rawValue: buttonIndex) ?? .FRIEND_ALLOW_ANY
            V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: nil, fail: nil)
        }
    }

    func didTapOnAvatar(_ cell: TUIContactProfileCardCell_Minimalist) {
        let image = TUIAvatarViewController()
        image.avatarData = cell.cardData
        navigationController?.pushViewController(image, animated: true)
    }

    @objc private func onSwitchMsgReadStatus(_ cell: TUICommonSwitchCell) {
        let on = cell.switcher.isOn
        delegate?.onSwitchMsgReadStatus(on)

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
        delegate?.onSwitchOnlineStatus(on)
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
        delegate?.onSwitchCallsRecord(on)
    }

    @objc private func onClickAboutIM(_ cell: TUICommonTextCell) {
        delegate?.onClickAboutIM()
    }

    @objc private func onClickChangeStyle() {
        let styleVC = TUIStyleSelectViewController()
        styleVC.delegate = self
        navigationController?.pushViewController(styleVC, animated: true)
    }

    @objc private func onClickChangeTheme() {
        let vc = TUIThemeSelectController()
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    public func onSelectStyle(_ cellModel: TUIStyleSelectCellModel) {
        if cellModel.styleName != styleName {
            styleName = cellModel.styleName
            delegate?.onChangeStyle()
        }
    }

    public func onSelectTheme(_ cellModel: TUIThemeSelectCollectionViewCellModel) {
        if cellModel.themeName != themeName {
            themeName = cellModel.themeName
            delegate?.onChangeTheme()
        }
    }

    @objc private func onClickLogout(_ cell: TUIButtonCell) {
        delegate?.onClickLogout()
    }
}
