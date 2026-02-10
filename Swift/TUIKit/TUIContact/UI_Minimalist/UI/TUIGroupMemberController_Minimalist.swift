// TUIGroupMemberController_Minimalist.swift
// TUIContact

import TIMCommon
import UIKit

class TUIGroupMemberController_Minimalist: UIViewController, UITableViewDelegate, UITableViewDataSource {
    var groupId: String?
    var groupInfo: V2TIMGroupInfo?
    private var titleView: TUINaviBarIndicatorView!
    private var showContactSelectVC: UIViewController?
    private var dataProvider: TUIGroupMemberDataProvider!
    private var members: [TUIMemberInfoCellData] = []
    private var tag: Int = 0
    private var adminDataprovier: TUISettingAdminDataProvider!

    lazy var indicatorView: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .gray)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.backgroundColor = .white
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TUIMemberInfoCell.self, forCellReuseIdentifier: "TUIMemberInfoCell")
        tableView.rowHeight = TUISwift.kScale390(52)
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()

        dataProvider = TUIGroupMemberDataProvider(groupID: groupId ?? "")
        dataProvider.groupInfo = groupInfo

        adminDataprovier = TUISettingAdminDataProvider()
        adminDataprovier.groupID = groupId

        adminDataprovier.loadData { [weak self] _, _ in
            self?.refreshData()
        }
    }

    func refreshData() {
        dataProvider.loadDatas { [weak self] _, _, datas in
            guard let self = self else { return }
            let title = String(format: TUISwift.timCommonLocalizableString("TUIKitGroupProfileGroupCountFormat"), datas.count)
            self.title = title
            self.members = datas
            self.tableView.reloadData()
        }
    }

    private func setupViews() {
        view.backgroundColor = .white

        // left
        var image = TUISwift.tuiContactDynamicImage("group_nav_back_img", defaultImage: UIImage.safeImage(TUISwift.tuiContactImagePath("back")))
        image = image.rtlImageFlippedForRightToLeftLayoutDirection()
        let leftButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        leftButton.addTarget(self, action: #selector(leftBarButtonClick), for: .touchUpInside)
        leftButton.setImage(image, for: .normal)
        let leftItem = UIBarButtonItem(customView: leftButton)
        navigationItem.leftBarButtonItems = [leftItem]
        parent?.navigationItem.leftBarButtonItems = [leftItem]

        // right
        let rightButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        rightButton.addTarget(self, action: #selector(rightBarButtonClick), for: .touchUpInside)
        rightButton.setTitle(TUISwift.timCommonLocalizableString("TUIKitGroupProfileManage"), for: .normal)
        rightButton.setTitleColor(TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000"), for: .normal)
        rightButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        let rightItem = UIBarButtonItem(customView: rightButton)

        indicatorView.frame = CGRect(x: 0, y: 0, width: view.bounds.size.width, height: CGFloat(TMessageController_Header_Height))

        tableView.frame = view.bounds
        tableView.tableFooterView = indicatorView
        view.addSubview(tableView)

        titleView = TUINaviBarIndicatorView()
        navigationItem.titleView = titleView
        navigationItem.title = ""
        titleView.setTitle(TUISwift.timCommonLocalizableString("GroupMember"))
    }

    @objc private func leftBarButtonClick() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func rightBarButtonClick() {
        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        var ids: [String] = []
        var displayNames: [String: String] = [:]
        for cd in members {
            if let identifier = cd.identifier, identifier != V2TIMManager.sharedInstance().getLoginUser() {
                ids.append(identifier)
                displayNames[cd.identifier ?? ""] = cd.name ?? ""
            }
        }

        let selectContactCompletion: ([TUICommonContactSelectCellData]) -> Void = { [weak self] array in
            guard let self = self else { return }
            if self.tag == 1 {
                // add
                let list = array.map { $0.identifier }
                self.navigationController?.popToViewController(self, animated: true)
                self.addGroupId(self.groupId, members: list)
            } else if self.tag == 2 {
                // delete
                let list = array.map { $0.identifier }
                self.navigationController?.popToViewController(self, animated: true)
                self.deleteGroupId(self.groupId, members: list)
            }
        }

        if dataProvider.groupInfo?.canInviteMember() == true {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileManageAdd"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                // add
                self.tag = 1
                var param: [String: Any] = [:]
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_TitleKey"] = TUISwift.timCommonLocalizableString("GroupAddFirend")
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_DisableIdsKey"] = ids
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_DisplayNamesKey"] = displayNames
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_CompletionKey"] = selectContactCompletion
                if let vc = TUICore.createObject("TUICore_TUIContactObjectFactory_Minimalist", key: "TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod", param: param) as? UIViewController {
                    self.showContactSelectVC = vc
                    self.navigationController?.pushViewController(self.showContactSelectVC!, animated: true)
                }
            })
        }

        if dataProvider.groupInfo?.canRemoveMember() == true {
            ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileManageDelete"), style: .default) { [weak self] _ in
                guard let self = self else { return }
                // delete
                self.tag = 2
                var param: [String: Any] = [:]
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_TitleKey"] = TUISwift.timCommonLocalizableString("GroupDeleteFriend")
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_SourceIdsKey"] = ids
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_DisplayNamesKey"] = displayNames
                param["TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod_CompletionKey"] = selectContactCompletion
                if let vc = TUICore.createObject("TUICore_TUIContactObjectFactory_Minimalist", key: "TUICore_TUIContactObjectFactory_GetContactSelectControllerMethod", param: param) as? UIViewController {
                    self.showContactSelectVC = vc
                    self.navigationController?.pushViewController(self.showContactSelectVC!, animated: true)
                }
            })
        }

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))

        present(ac, animated: true, completion: nil)
    }

    private func addGroupId(_ groupId: String?, members: [String]) {
        guard let groupId = groupId else { return }
        V2TIMManager.sharedInstance().inviteUserToGroup(groupID: groupId, userList: members) { [weak self] _ in
            guard let self = self else { return }
            self.refreshData()
            TUITool.makeToast(TUISwift.timCommonLocalizableString("add_success"))
        } fail: { code, desc in
            TUITool.makeToastError(Int(code), msg: desc)
        }
    }

    private func deleteGroupId(_ groupId: String?, members: [String]) {
        guard let groupId = groupId else { return }
        V2TIMManager.sharedInstance().kickGroupMember(groupId, memberList: members, reason: "", succ: { [weak self] _ in
            guard let self = self else { return }
            self.refreshData()
            TUITool.makeToast(TUISwift.timCommonLocalizableString("delete_success"))
        }, fail: { code, desc in
            TUITool.makeToastError(Int(code), msg: desc)
        })
    }

    func getUserOrFriendProfileVCWithUserID(_ userID: String?, succ: @escaping (UIViewController) -> Void, fail: V2TIMFail?) {
        let param: [String: Any] = [
            "TUICore_TUIContactService_etUserOrFriendProfileVCMethod_UserIDKey": userID ?? "",
            "TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_SuccKey": succ,
            "TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod_FailKey": fail ?? { _, _ in }
        ]
        TUICore.createObject("TUICore_TUIContactObjectFactory_Minimalist", key: "TUICore_TUIContactObjectFactory_GetUserOrFriendProfileVCMethod", param: param)
    }

    // MARK: - UITableViewDelegate, UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return members.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TUIMemberInfoCell", for: indexPath) as! TUIMemberInfoCell
        let data = members[indexPath.row]
        data.showAccessory = true
        cell.data = data
        cell.avatarImageView.layer.cornerRadius = cell.avatarImageView.frame.height / 2
        cell.avatarImageView.layer.masksToBounds = true
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let data = members[indexPath.row]

        guard let identifier = data.identifier else {
            return
        }
        if identifier == TUILogin.getUserID() {
            // Can't manage yourself
            return
        }

        let ac = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let actionInfo = UIAlertAction(title: TUISwift.timCommonLocalizableString("Info"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.getUserOrFriendProfileVCWithUserID(data.identifier, succ: { vc in
                self.navigationController?.pushViewController(vc, animated: true)
            }, fail: nil)
        }

        let actionDelete = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileManageDelete"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            var list: [String] = []
            list.append(identifier)
            self.deleteGroupId(self.groupId, members: list)
        }

        let actionAddAdmin = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdmainAdd"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let user = TUIUserModel()
            user.userId = identifier
            self.adminDataprovier.settingAdmins(userModels: [user], callback: { [weak self] code, errorMsg in
                guard let self = self else { return }
                if code != 0 {
                    self.view.tui_makeToast(errorMsg ?? "")
                } else {
                    data.role = V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_ADMIN.rawValue
                }
                self.tableView.reloadData()
            })
        }

        let actionRemoveAdmin = UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdmainDelete"), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let user = TUIUserModel()
            user.userId = identifier
            self.adminDataprovier.removeAdmin(userID: identifier, callback: { [weak self] code, errorMsg in
                guard let self = self else { return }
                if code != 0 {
                    self.view.tui_makeToast(errorMsg ?? "")
                } else {
                    data.role = V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_MEMBER.rawValue
                }
                self.tableView.reloadData()
            })
        }

        ac.addAction(actionInfo)

        if dataProvider.groupInfo?.canSupportSetAdmain() == true {
            if data.role == V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_MEMBER.rawValue || data.role == V2TIMGroupMemberRole.GROUP_MEMBER_UNDEFINED.rawValue {
                ac.addAction(actionAddAdmin)
            } else {
                ac.addAction(actionRemoveAdmin)
            }
        }

        if dataProvider.groupInfo?.canRemoveMember() == true {
            if data.role < dataProvider.groupInfo?.role ?? UInt32(V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_MEMBER.rawValue) {
                ac.addAction(actionDelete)
            }
        }

        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Cancel"), style: .cancel, handler: nil))

        present(ac, animated: true, completion: nil)
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        if scrollView.contentOffset.y > 0 && scrollView.contentOffset.y >= scrollView.bounds.origin.y {
            if indicatorView.isAnimating {
                return
            }
            indicatorView.startAnimating()

            // There's no more data, stop loading.
            if dataProvider.isNoMoreData {
                indicatorView.stopAnimating()
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitMessageReadNoMoreData"))
                return
            }

            dataProvider.loadDatas { [weak self] success, _, datas in
                guard let self = self else { return }
                self.indicatorView.stopAnimating()
                if !success {
                    return
                }
                self.members.append(contentsOf: datas)
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                if datas.isEmpty {
                    self.tableView.setContentOffset(CGPoint(x: 0, y: scrollView.contentOffset.y - CGFloat(TMessageController_Header_Height)), animated: true)
                }
            }
        }
    }
}
