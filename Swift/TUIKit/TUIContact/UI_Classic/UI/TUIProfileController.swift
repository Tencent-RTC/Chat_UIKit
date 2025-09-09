//  Created by Tencent on 2023/06/09.
//  Copyright © 2023 Tencent. All rights reserved.

import TIMCommon
import UIKit

class TUIProfileController: UITableViewController, UIActionSheetDelegate, V2TIMSDKListener, TUIModifyViewDelegate {
    private var titleView: TUINaviBarIndicatorView?
    private var data: [[Any]] = []
    private var profile: V2TIMUserFullInfo?
    private weak var picker: UIDatePicker?

    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.tableFooterView = UIView(frame: .zero)
        addLongPressGesture()
        setupViews()

        tableView.delaysContentTouches = false

        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")

        tableView.register(TUICommonTextCell.self, forCellReuseIdentifier: "textCell")
        tableView.register(TUICommonAvatarCell.self, forCellReuseIdentifier: "avatarCell")
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)

        if let loginUser = V2TIMManager.sharedInstance().getLoginUser() {
            V2TIMManager.sharedInstance().getUsersInfo([loginUser], succ: { [weak self] infoList in
                guard let self = self, let infoList = infoList else { return }
                self.profile = infoList.first
                self.setupData()
            }) { _, _ in
                // to do
            }
        }
    }

    private func setupViews() {
        titleView = TUINaviBarIndicatorView()
        titleView?.setTitle(TUISwift.timCommonLocalizableString("ProfileDetails"))
        navigationItem.titleView = titleView
        navigationItem.title = ""
    }

    private func setupData() {
        data = []

        if let profile = profile {
            let avatarData = TUICommonAvatarCellData()
            avatarData.key = TUISwift.timCommonLocalizableString("ProfilePhoto")
            avatarData.showAccessory = true
            avatarData.cselector = #selector(didSelectAvatar)
            if let faceURLString = profile.faceURL, !faceURLString.isEmpty,
               let url = URL(string: faceURLString) {
                avatarData.avatarUrl = url
            } else {
                avatarData.avatarUrl = nil
            }
            data.append([avatarData])

            let nicknameData = TUICommonTextCellData()
            nicknameData.key = TUISwift.timCommonLocalizableString("ProfileName")
            nicknameData.value = profile.showName()
            nicknameData.showAccessory = true
            nicknameData.cselector = #selector(didSelectChangeNick)

            let IDData = TUICommonTextCellData()
            IDData.key = TUISwift.timCommonLocalizableString("ProfileAccount")
            IDData.value = profile.userID ?? ""
            IDData.showAccessory = false
            data.append([nicknameData, IDData])

            let signatureData = TUICommonTextCellData()
            signatureData.key = TUISwift.timCommonLocalizableString("ProfileSignature")
            signatureData.value = profile.selfSignature ?? ""
            signatureData.showAccessory = true
            signatureData.cselector = #selector(didSelectChangeSignature)

            let sexData = TUICommonTextCellData()
            sexData.key = TUISwift.timCommonLocalizableString("ProfileGender")
            sexData.value = profile.showGender()
            sexData.showAccessory = true
            sexData.cselector = #selector(didSelectSex)

            let birthdayData = TUICommonTextCellData()
            birthdayData.key = TUISwift.timCommonLocalizableString("ProfileBirthday")
            birthdayData.value = dateFormatter.string(from: Date())
            let birthday = profile.birthday
            if birthday > 0 {
                let year = birthday / 10000
                let month = (birthday - year * 10000) / 100
                let day = (birthday - year * 10000 - month * 100)
                birthdayData.value = String(format: "%04zd-%02zd-%02zd", year, month, day)
            }
            birthdayData.showAccessory = true
            birthdayData.cselector = #selector(didSelectBirthday)

            data.append([signatureData, sexData, birthdayData])
        }

        tableView.reloadData()
    }

    func onSelfInfoUpdated(info: V2TIMUserFullInfo) {
        profile = info
        setupData()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return data.count
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 10
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let array = data[indexPath.section]
        if let data = array[indexPath.row] as? TUICommonCellData {
            return data.height(ofWidth: TUISwift.screen_Width())
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let array = data[indexPath.section]
        let data = array[indexPath.row]
        if let textData = data as? TUICommonTextCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "textCell", for: indexPath) as! TUICommonTextCell
            cell.fill(with: textData)
            return cell
        } else if let avatarData = data as? TUICommonAvatarCellData {
            let cell = tableView.dequeueReusableCell(withIdentifier: "avatarCell", for: indexPath) as! TUICommonAvatarCell
            cell.fill(with: avatarData)
            return cell
        }
        return UITableViewCell()
    }

    func modifyView(_ modifyView: TUIModifyView, didModiyContent content: String) {
        if modifyView.tag == 0 {
            if !validForSignatureAndNick(content) {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("ProfileEditNameDesc"))
                return
            }
            let info = V2TIMUserFullInfo()
            info.nickName = content
            V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: {
                self.profile?.nickName = content
                self.setupData()
            }, fail: nil)
        } else if modifyView.tag == 1 {
            if !validForSignatureAndNick(content) {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("ProfileEditNameDesc"))
                return
            }
            let info = V2TIMUserFullInfo()
            info.selfSignature = content
            V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: {
                self.profile?.selfSignature = content
                self.setupData()
            }, fail: nil)
        }
    }

    private func validForSignatureAndNick(_ content: String) -> Bool {
        let reg = "^[a-zA-Z0-9_\\u4e00-\\u9fa5]*$"
        let regex = NSPredicate(format: "SELF MATCHES %@", reg)
        return regex.evaluate(with: content)
    }

    @objc private func didSelectChangeNick() {
        let data = TUIModifyViewData()
        data.title = TUISwift.timCommonLocalizableString("ProfileEditName")
        data.desc = TUISwift.timCommonLocalizableString("ProfileEditNameDesc")
        data.content = profile?.showName() ?? ""
        let modify = TUIModifyView()
        modify.tag = 0
        modify.delegate = self
        modify.setData(data)
        modify.showInWindow(view.window!)
    }

    @objc private func didSelectChangeSignature() {
        let data = TUIModifyViewData()
        data.title = TUISwift.timCommonLocalizableString("ProfileEditSignture")
        data.desc = TUISwift.timCommonLocalizableString("ProfileEditNameDesc")
        data.content = profile?.selfSignature ?? ""
        let modify = TUIModifyView()
        modify.tag = 1
        modify.delegate = self
        modify.setData(data)
        modify.showInWindow(view.window!)
    }

    @objc private func didSelectSex() {
        let sheet = UIActionSheet()
        sheet.tag = SHEET_SEX
        sheet.title = TUISwift.timCommonLocalizableString("ProfileEditGender")
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("Male"))
        sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("Female"))
        sheet.cancelButtonIndex = sheet.addButton(withTitle: TUISwift.timCommonLocalizableString("Cancel"))
        sheet.delegate = self
        sheet.show(in: view)
    }

    @objc private func didSelectAvatar() {
        let vc = TUISelectAvatarController()
        vc.selectAvatarType = .userAvatar
        vc.profilFaceURL = profile?.faceURL ?? ""
        navigationController?.pushViewController(vc, animated: true)

        weak var weakSelf = self
        vc.selectCallBack = { urlStr in
            guard let strongSelf = weakSelf else { return }
            if !urlStr.isEmpty {
                let info = V2TIMUserFullInfo()
                info.faceURL = urlStr
                V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: {
                    strongSelf.profile?.faceURL = urlStr
                    strongSelf.setupData()
                }, fail: nil)
            }
        }
    }

    func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        if actionSheet.tag == SHEET_SEX {
            var gender: V2TIMGender = .GENDER_UNKNOWN
            if buttonIndex == 0 {
                gender = .GENDER_MALE
            } else if buttonIndex == 1 {
                gender = .GENDER_FEMALE
            }
            let info = V2TIMUserFullInfo()
            info.gender = gender
            V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: {
                self.profile?.gender = gender
                self.setupData()
            }, fail: nil)
        }
    }

    private func addLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressAtCell(_:)))
        tableView.addGestureRecognizer(longPress)
    }

    @objc private func didLongPressAtCell(_ longPress: UILongPressGestureRecognizer) {
        if longPress.state == .began {
            let point = longPress.location(in: tableView)
            if let pathAtView = tableView.indexPathForRow(at: point),
               let data = tableView.cellForRow(at: pathAtView)
            {
                if let textCell = data as? TUICommonTextCell,
                   textCell.textData?.value != TUISwift.timCommonLocalizableString("no_set")
                {
                    UIPasteboard.general.string = textCell.textData?.value
                    let toastString = "copy \(textCell.textData?.key ?? "")"
                    TUITool.makeToast(toastString)
                } else if let profileCard = data as? TUIProfileCardCell {
                    UIPasteboard.general.string = profileCard.cardData?.identifier
                    TUITool.makeToast("copy")
                }
            }
        }
    }

    @objc private func didSelectBirthday() {
        hideDatePicker()
        if let keyWindow = TUITool.applicationKeywindow() {
            keyWindow.addSubview(datePicker ?? UIView())
        }
    }

    lazy var datePicker: UIView? = {
        let cover = UIView(frame: UIScreen.main.bounds)
        cover.backgroundColor = TUISwift.timCommonDynamicColor("group_modify_view_bg_color", defaultColor: "#0000007F")
        cover.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideDatePicker)))

        let menuView = UIView()
        menuView.backgroundColor = TUISwift.timCommonDynamicColor("group_modify_container_view_bg_color", defaultColor: "#FFFFFF")
        menuView.frame = CGRect(x: 0, y: UIScreen.main.bounds.height - 340, width: UIScreen.main.bounds.width, height: 40)
        cover.addSubview(menuView)

        let cancelButton = UIButton(type: .custom)
        cancelButton.setTitle(TUISwift.timCommonLocalizableString("Cancel"), for: .normal)
        cancelButton.setTitleColor(.darkGray, for: .normal)
        cancelButton.frame = CGRect(x: 10, y: 0, width: 60, height: 35)
        cancelButton.addTarget(self, action: #selector(hideDatePicker), for: .touchUpInside)
        menuView.addSubview(cancelButton)

        let okButton = UIButton(type: .custom)
        okButton.setTitle(TUISwift.timCommonLocalizableString("Confirm"), for: .normal)
        okButton.setTitleColor(.darkGray, for: .normal)
        okButton.frame = CGRect(x: cover.bounds.width - 70, y: 0, width: 60, height: 35)
        okButton.addTarget(self, action: #selector(onOKDatePicker), for: .touchUpInside)
        menuView.addSubview(okButton)

        let picker = UIDatePicker()
        picker.locale = Locale(identifier: TUIGlobalization.tk_localizableLanguageKey())
        if #available(iOS 13.0, *) {
            picker.overrideUserInterfaceStyle = .light
        }
        if #available(iOS 13.4, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        picker.backgroundColor = TUISwift.timCommonDynamicColor("group_modify_container_view_bg_color", defaultColor: "#FFFFFF")
        picker.datePickerMode = .date
        picker.frame = CGRect(x: 0, y: menuView.frame.maxY, width: cover.bounds.width, height: 300)
        cover.addSubview(picker)
        self.picker = picker

        return cover
    }()

    @objc private func hideDatePicker() {
        datePicker?.removeFromSuperview()
    }

    @objc private func onOKDatePicker() {
        hideDatePicker()
        if let date = picker?.date {
            var dateStr = dateFormatter.string(from: date)
            dateStr = dateStr.replacingOccurrences(of: "-", with: "")
            if let birthday = Int(dateStr) {
                let info = V2TIMUserFullInfo()
                info.birthday = UInt32(birthday)
                V2TIMManager.sharedInstance().setSelfInfo(info: info, succ: {
                    self.profile?.birthday = UInt32(birthday)
                    self.setupData()
                }, fail: nil)
            }
        }
    }
}
