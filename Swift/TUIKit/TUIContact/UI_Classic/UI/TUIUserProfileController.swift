// TUIUserProfileController.swift

//  Created by Tencent on 2023/06/09.
//  Copyright © 2023 Tencent. All rights reserved.
/**
 *
 *  Tencent Cloud Communication Service Interface Components TUIKIT - User Information View Interface
 *  This file implements the user profile view controller. User refers to other users who are not friends.
 *  If friend, use TUIFriendProfileController
 */

import TIMCommon
import UIKit

enum ProfileControllerAction: UInt {
    case PCA_NONE
    case PCA_ADD_FRIEND
    case PCA_PENDENDY_CONFIRM
    case PCA_GROUP_CONFIRM
}

class TUIUserProfileController: UITableViewController, TUIContactProfileCardDelegate {
    var userFullInfo: V2TIMUserFullInfo?
    var groupPendency: TUIGroupPendencyCellData?
    var pendency: TUICommonPendencyCellData?
    var actionType: ProfileControllerAction = .PCA_NONE

    private var dataList: [[Any]] = []
    private var titleView: TUINaviBarIndicatorView?

    override init(style: UITableView.Style = .grouped) {
        super.init(style: style)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        titleView = TUINaviBarIndicatorView()
        titleView?.setTitle(TUISwift.timCommonLocalizableString("ProfileDetails"))
        navigationItem.titleView = titleView
        navigationItem.title = ""
        clearsSelectionOnViewWillAppear = true
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(TUICommonContactTextCell.self, forCellReuseIdentifier: "TextCell")
        tableView.register(TUICommonContactProfileCardCell.self, forCellReuseIdentifier: "CardCell")
        tableView.register(TUIButtonCell.self, forCellReuseIdentifier: "ButtonCell")
        tableView.delaysContentTouches = false
        tableView.separatorStyle = .none

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
                personal.signature = userFullInfo?.showSignature()
                personal.reuseId = "CardCell"
                return personal
            }())
            return inlist
        }())

        if pendency != nil || groupPendency != nil {
            list.append({
                var inlist: [Any] = []
                inlist.append({
                    let data = TUICommonContactTextCellData()
                    data.key = TUISwift.timCommonLocalizableString("FriendAddVerificationMessage")
                    data.keyColor = UIColor(red: 136 / 255.0, green: 136 / 255.0, blue: 136 / 255.0, alpha: 1.0)
                    data.valueColor = UIColor(red: 68 / 255.0, green: 68 / 255.0, blue: 68 / 255.0, alpha: 1.0)
                    if let pendency = pendency {
                        data.value = pendency.addWording
                    } else if let groupPendency = groupPendency {
                        data.value = groupPendency.requestMsg
                    }
                    data.reuseId = "TextCell"
                    data.enableMultiLineValue = true
                    return data
                }())
                return inlist
            }())
        }

        dataList = list

        if actionType == .PCA_ADD_FRIEND {
            V2TIMManager.sharedInstance().checkFriend([userFullInfo?.userID ?? ""], check: .FRIEND_TYPE_BOTH, succ: { resultList in
                guard let resultList = resultList else { return }
                let result = resultList.first
                if result!.relationType == .FRIEND_RELATION_TYPE_IN_MY_FRIEND_LIST || result!.relationType == .FRIEND_RELATION_TYPE_BOTH_WAY {
                    return
                }

                if !TUIContactConfig.shared.isItemHiddenInContactConfig(.addFriend) {
                    self.dataList.append({
                        var inlist: [Any] = []
                        inlist.append({
                            let data = TUIButtonCellData()
                            data.title = TUISwift.timCommonLocalizableString("FriendAddTitle")
                            data.style = .ButtonWhite
                            data.cbuttonSelector = #selector(self.onAddFriend)
                            data.reuseId = "ButtonCell"
                            data.hideSeparatorLine = true
                            return data
                        }())
                        return inlist
                    }())
                    self.tableView.reloadData()
                }
            }, fail: { _, _ in
                print("")
            })
        }

        if actionType == .PCA_PENDENDY_CONFIRM {
            dataList.append({
                var inlist: [Any] = []
                inlist.append({
                    let data = TUIButtonCellData()
                    data.title = TUISwift.timCommonLocalizableString("Accept")
                    data.style = .ButtonWhite
                    data.textColor = UIColor(red: 20 / 255.0, green: 122 / 255.0, blue: 255 / 255.0, alpha: 1.0)
                    data.cbuttonSelector = #selector(self.onAgreeFriend)
                    data.reuseId = "ButtonCell"
                    return data
                }())
                inlist.append({
                    let data = TUIButtonCellData()
                    data.title = TUISwift.timCommonLocalizableString("Decline")
                    data.style = .ButtonRedText
                    data.cbuttonSelector = #selector(self.onRejectFriend)
                    data.reuseId = "ButtonCell"
                    return data
                }())
                return inlist
            }())
        }

        if actionType == .PCA_GROUP_CONFIRM {
            dataList.append({
                var inlist: [Any] = []
                inlist.append({
                    let data = TUIButtonCellData()
                    data.title = TUISwift.timCommonLocalizableString("Accept")
                    data.style = .ButtonWhite
                    data.textColor = TUISwift.timCommonDynamicColor("primary_theme_color", defaultColor: "#147AFF")
                    data.cbuttonSelector = #selector(self.onAgreeGroup)
                    data.reuseId = "ButtonCell"
                    return data
                }())
                inlist.append({
                    let data = TUIButtonCellData()
                    data.title = TUISwift.timCommonLocalizableString("Decline")
                    data.style = .ButtonRedText
                    data.cbuttonSelector = #selector(self.onRejectGroup)
                    data.reuseId = "ButtonCell"
                    return data
                }())
                return inlist
            }())
        }

        tableView.reloadData()
    }

    // Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return dataList.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataList[section].count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let data = dataList[indexPath.section][indexPath.row] as! TUICommonCellData
        let cell = tableView.dequeueReusableCell(withIdentifier: data.reuseId, for: indexPath) as! TUICommonTableViewCell
        if let cardCell = cell as? TUICommonContactProfileCardCell {
            cardCell.delegate = self
        }
        cell.fill(with: data)
        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let data = dataList[indexPath.section][indexPath.row] as! TUICommonCellData
        return data.height(ofWidth: TUISwift.screen_Width())
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 10
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }

    @objc private func onSendMessage() {
        //    let data = TUIChatConversationModel()
        //    data.conversationID = "c2c_\(userFullInfo?.userID ?? "")"
        //    data.userID = userFullInfo?.userID
        //    data.title = userFullInfo?.showName()
        //    let chat = ChatViewController()
        //    chat.conversationData = data
        //    navigationController?.pushViewController(chat, animated: true)
    }

    @objc private func onAddFriend() {
        let vc = TUIFriendRequestViewController()
        vc.profile = userFullInfo
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func onAgreeFriend() {
        pendency?.agreeWithSuccess(success: { [weak self] in
            guard let self = self else { return }
            self.navigationController?.popViewController(animated: true)
        }, failure: { _, _ in
        })
    }

    @objc private func onRejectFriend() {
        pendency?.rejectWithSuccess(success: { [weak self] in
            guard let self = self else { return }
            self.navigationController?.popViewController(animated: true)
        }, failure: { _, _ in
        })
    }

    @objc private func onAgreeGroup() {
        groupPendency?.agree(success: { [weak self] in
            guard let self = self else { return }
            self.navigationController?.popViewController(animated: true)
        }, failure: { code, msg in
        })
    }

    @objc private func onRejectGroup() {
        groupPendency?.reject(success: { [weak self] in
            guard let self = self else { return }
            self.navigationController?.popViewController(animated: true)
        }, failure: { code, msg in
        })
    }

    private func toastView() -> UIView? {
        return TUITool.applicationKeywindow()
    }

    private func didSelectAvatar() {
        let image = TUIContactAvatarViewController()
        image.avatarData?.avatarUrl = URL(string: userFullInfo?.faceURL ?? "")
        let list = dataList
        print("\(list)")

        navigationController?.pushViewController(image, animated: true)
    }

    func didTapOnAvatar(cell: TUICommonContactProfileCardCell) {
        let image = TUIContactAvatarViewController()
        image.avatarData = cell.cardData
        navigationController?.pushViewController(image, animated: true)
    }
}
