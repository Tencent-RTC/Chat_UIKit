//  TUIContactController_Minimalist.swift
//  TUIContact

import TIMCommon
import TUICore
import UIKit

protocol TUIContactControllerListener_Minimalist: AnyObject {
    func onSelectFriend(_ cell: TUICommonContactCell_Minimalist) -> Bool
    func onAddNewFriend(_ cell: TUICommonTableViewCell) -> Bool
    func onGroupConversation(_ cell: TUICommonTableViewCell) -> Bool
}

extension TUIContactControllerListener_Minimalist {
    func onSelectFriend(_ cell: TUICommonContactCell_Minimalist) -> Bool { return false }
    func onAddNewFriend(_ cell: TUICommonTableViewCell) -> Bool { return false }
    func onGroupConversation(_ cell: TUICommonTableViewCell) -> Bool { return false }
}

public class TUIContactController_Minimalist: UIViewController, UITableViewDelegate, UITableViewDataSource, V2TIMFriendshipListener, TUIPopViewDelegate {
    public func popView(_ popView: TUIPopView, didSelectRowAt index: Int) {
        // to do
    }

    weak var delegate: TUIContactControllerListener_Minimalist?
    var firstGroupData: [TUIContactActionCellData_Minimalist] = []
    private var isLoadFinishedObservation: NSKeyValueObservation?
    private var pendencyCntObservation: NSKeyValueObservation?

    lazy var tableView: UITableView = {
        let rect = view.bounds
        let tableView = UITableView(frame: rect, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.sectionIndexBackgroundColor = .clear
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 8, right: 0)
        tableView.sectionIndexColor = .systemBlue
        tableView.backgroundColor = view.backgroundColor
        tableView.delaysContentTouches = false
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        let v = UIView(frame: .zero)
        tableView.tableFooterView = v
        tableView.separatorColor = .clear
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 58, bottom: 0, right: 0)
        tableView.register(TUICommonContactCell_Minimalist.self, forCellReuseIdentifier: kContactCellReuseId)
        tableView.register(TUIContactActionCell_Minimalist.self, forCellReuseIdentifier: kContactActionCellReuseId)
        return tableView
    }()

    lazy var viewModel: TUIContactViewDataProvider_Minimalist = {
        let viewModel = TUIContactViewDataProvider_Minimalist()
        viewModel.loadContacts()
        return viewModel
    }()

    override public func viewDidLoad() {
        super.viewDidLoad()
        var list: [TUIContactActionCellData_Minimalist] = []
        list.append({
            let data = TUIContactActionCellData_Minimalist()
            data.title = TUISwift.timCommonLocalizableString("TUIKitContactsNewFriends")
            data.cselector = #selector(onAddNewFriend(_:))
            return data
        }())
        list.append({
            let data = TUIContactActionCellData_Minimalist()
            data.title = TUISwift.timCommonLocalizableString("TUIKitContactsGroupChats")
            data.cselector = #selector(onGroupConversation(_:))
            return data
        }())
        list.append({
            let data = TUIContactActionCellData_Minimalist()
            data.title = TUISwift.timCommonLocalizableString("TUIKitContactsBlackList")
            data.cselector = #selector(onBlackList(_:))
            return data
        }())
        
        // Add extensions
        addExtensionsToList(list: &list)
        
        // Set needBottomLine for last item
        if let lastItem = list.last {
            lastItem.needBottomLine = false
        }
        
        firstGroupData = list

        setupNavigator()
        setupViews()

        NotificationCenter.default.addObserver(self, selector: #selector(onFriendInfoChanged(_:)), name: NSNotification.Name("FriendInfoChangedNotification"), object: nil)
    }
    
    private func addExtensionsToList(list: inout [TUIContactActionCellData_Minimalist]) {
        let param: [String: Any] = ["TUICore_TUIContactExtension_ContactMenu_Nav": navigationController as Any]
        let extensionList = TUICore.getExtensionList("TUICore_TUIContactExtension_ContactMenu_MinimalistExtensionID", param: param)
        let sortedExtensionList = extensionList.sorted { $0.weight > $1.weight }
        for info in sortedExtensionList {
            list.append({
                let data = TUIContactActionCellData_Minimalist()
                data.icon = info.icon
                data.title = info.text ?? ""
                data.cselector = #selector(onExtensionClicked(_:))
                data.onClicked = { param in
                    info.onClicked?(param ?? [:])
                }
                return data
            }())
        }
    }
    
    @objc private func onExtensionClicked(_ cell: TUICommonTableViewCell) {
        if let data = cell.data as? TUIContactActionCellData_Minimalist {
            var param: [String: Any] = [:]
            if let nav = navigationController {
                param["navigationController"] = nav
            }
            data.onClicked?(param)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        isLoadFinishedObservation = nil
        pendencyCntObservation = nil
    }

    @objc func onFriendInfoChanged(_ notice: Notification) {
        viewModel.loadContacts()
    }

    func setupNavigator() {
        let moreButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        moreButton.setImage(TUISwift.timCommonDynamicImage("nav_more_img", defaultImage: UIImage.safeImage(TUISwift.timCommonImagePath("more"))), for: .normal)
        moreButton.addTarget(self, action: #selector(onRightItem(_:)), for: .touchUpInside)
        moreButton.widthAnchor.constraint(equalToConstant: 24).isActive = true
        moreButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let moreItem = UIBarButtonItem(customView: moreButton)
        navigationItem.rightBarButtonItem = moreItem

        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        view.backgroundColor = TUISwift.timCommonDynamicColor("", defaultColor: "#FFFFFF")
    }

    func setupViews() {
        view.addSubview(tableView)

        isLoadFinishedObservation = viewModel.observe(\.isLoadFinished, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let finished = change.newValue else { return }
            if finished {
                self.tableView.reloadData()
            }
        }
        pendencyCntObservation = viewModel.observe(\.pendencyCnt, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let cnt = change.newValue else { return }
            self.firstGroupData[0].readNum = Int(cnt)
        }
    }

    @objc func onRightItem(_ rightBarButton: UIButton) {
        var menus: [TUIPopCellData] = []
        let friend = TUIPopCellData()
        friend.image = TUISwift.tuiContactDynamicImage("pop_icon_add_friend_img", defaultImage: UIImage.safeImage(TUISwift.tuiContactImagePath("add_friend")))
        friend.title = TUISwift.timCommonLocalizableString("ContactsAddFriends")
        menus.append(friend)

        let group = TUIPopCellData()
        group.image = TUISwift.tuiContactDynamicImage("pop_icon_add_group_img", defaultImage: UIImage.safeImage(TUISwift.tuiContactImagePath("add_group")))
        group.title = TUISwift.timCommonLocalizableString("ContactsJoinGroup")
        menus.append(group)

        let height = TUIPopCell.getHeight() * CGFloat(menus.count) + TUISwift.tuiPopView_Arrow_Size().height
        let orginY = TUISwift.statusBar_Height() + TUISwift.navBar_Height()
        var orginX = TUISwift.screen_Width() - 140
        if TUISwift.isRTL() {
            orginX = 10
        }
        let popView = TUIPopView(frame: CGRect(x: orginX, y: orginY, width: 130, height: height))
        let frameInNaviView = navigationController?.view.convert(rightBarButton.frame, from: rightBarButton.superview)
        popView.arrowPoint = CGPoint(x: frameInNaviView?.origin.x ?? 0 + (frameInNaviView?.size.width ?? 0) * 0.5, y: orginY)
        popView.delegate = self
        popView.setData(menus)
        popView.showInWindow(view.window!)
    }

    public func addToContacts() {
        let add = TUIFindContactViewController_Minimalist()
        add.type = .C2C_Minimalist
        add.onSelect = { [weak self] cellModel in
            guard let self = self else { return }
            self.dismiss(animated: false) { [weak self] in
                guard let self else { return }
                var userID = ""
                if let cellUserID = cellModel.userInfo?.userID, !cellUserID.isEmpty {
                    userID = cellUserID
                }
                var targetViewController: (UIViewController & TUIFloatSubViewControllerProtocol)? = nil
                if let friendContactData = self.viewModel.contactMap[userID] {
                    let vc = TUIFriendProfileController_Minimalist()
                    vc.friendProfile = friendContactData.friendProfile
                    targetViewController = vc
                } else {
                    let frc = TUIFriendRequestViewController_Minimalist()
                    frc.profile = cellModel.userInfo
                    targetViewController = frc
                }

                let bfloatVC = TUIFloatViewController()
                if let vc = targetViewController {
                    bfloatVC.appendChildViewController(vc, topMargin: TUISwift.kScale390(87.5))
                }
                bfloatVC.topGestureView.setTitleText(mainText: TUISwift.timCommonLocalizableString("Info"), subTitleText: "", leftBtnText: TUISwift.timCommonLocalizableString("TUIKitCreateCancel"), rightBtnText: "")
                bfloatVC.topGestureView.rightButton.isHidden = true
                bfloatVC.topGestureView.subTitleLabel.isHidden = true
                self.present(bfloatVC, animated: true)
                bfloatVC.topGestureView.leftButtonClickCallback = {
                    self.dismiss(animated: true)
                }
            }
        }

        let floatVC = TUIFloatViewController()
        floatVC.appendChildViewController(add, topMargin: TUISwift.kScale390(87.5))
        floatVC.topGestureView.setTitleText(mainText: TUISwift.timCommonLocalizableString("TUIKitAddFriend"), subTitleText: "", leftBtnText: TUISwift.timCommonLocalizableString("TUIKitCreateCancel"), rightBtnText: "")
        floatVC.topGestureView.rightButton.isHidden = true
        floatVC.topGestureView.subTitleLabel.isHidden = true
        floatVC.topGestureView.leftButtonClickCallback = {
            self.dismiss(animated: true)
        }
        present(floatVC, animated: true)
    }

    public func addGroups() {
        let add = TUIFindContactViewController_Minimalist()
        add.type = .Group_Minimalist
        add.onSelect = { [weak self] cellModel in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                let vc = TUIGroupRequestViewController_Minimalist()
                vc.groupInfo = cellModel.groupInfo

                let bfloatVC = TUIFloatViewController()
                bfloatVC.appendChildViewController(vc, topMargin: TUISwift.kScale390(87.5))
                bfloatVC.topGestureView.setTitleText(mainText: TUISwift.timCommonLocalizableString("Info"), subTitleText: "", leftBtnText: TUISwift.timCommonLocalizableString("TUIKitCreateCancel"), rightBtnText: "")
                bfloatVC.topGestureView.rightButton.isHidden = true
                bfloatVC.topGestureView.subTitleLabel.isHidden = true
                self.present(bfloatVC, animated: true)
                bfloatVC.topGestureView.leftButtonClickCallback = {
                    self.dismiss(animated: true)
                }
            }
        }

        let floatVC = TUIFloatViewController()
        floatVC.appendChildViewController(add, topMargin: TUISwift.kScale390(87.5))
        floatVC.topGestureView.setTitleText(mainText: TUISwift.timCommonLocalizableString("TUIKitAddGroup"), subTitleText: "", leftBtnText: TUISwift.timCommonLocalizableString("TUIKitCreateCancel"), rightBtnText: "")
        floatVC.topGestureView.rightButton.isHidden = true
        floatVC.topGestureView.subTitleLabel.isHidden = true
        floatVC.topGestureView.leftButtonClickCallback = {
            self.dismiss(animated: true)
        }
        present(floatVC, animated: true)
    }

    @objc func onSelectFriend(_ cell: TUICommonContactCell_Minimalist) {
        if let delegate = delegate {
            if delegate.onSelectFriend(cell) { return }
        }
        let data = cell.contactData
        let vc = TUIFriendProfileController_Minimalist()
        vc.friendProfile = data?.friendProfile
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func onAddNewFriend(_ cell: TUICommonTableViewCell) {
        if let delegate = delegate {
            if delegate.onAddNewFriend(cell) { return }
        }
        let vc = TUINewFriendViewController_Minimalist()
        vc.cellClickBlock = { [weak self] cell in
            guard let self = self else { return }
            let controller = TUIUserProfileController_Minimalist(style: .grouped)
            if let pendencyData = cell.pendencyData {
                V2TIMManager.sharedInstance().getUsersInfo([pendencyData.identifier]) { [weak self] profiles in
                    guard let self = self, let profiles = profiles else { return }
                    controller.userFullInfo = profiles.first
                    controller.pendency = cell.pendencyData
                    controller.actionType = .PCA_PENDENDY_CONFIRM_MINI
                    self.navigationController?.pushViewController(controller, animated: true)
                } fail: { _, _ in }
            }
        }
        navigationController?.pushViewController(vc, animated: true)
        viewModel.clearApplicationCnt()
    }

    @objc func onGroupConversation(_ cell: TUICommonTableViewCell) {
        if let delegate = delegate {
            if delegate.onGroupConversation(cell) { return }
        }
        let vc = TUIGroupConversationListController_Minimalist()
        vc.onSelect = { [weak self] cellData in
            guard let self = self else { return }
            let param: [String: Any] = [
                "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": cellData.identifier,
                "TUICore_TUIChatObjectFactory_ChatViewController_Title": cellData.title ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": cellData.avatarImage ?? UIImage(),
                "TUICore_TUIChatObjectFactory_ChatViewController_AvatarUrl": cellData.avatarUrl?.absoluteString ?? ""
            ]
            self.navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Minimalist", param: param, forResult: nil)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func onBlackList(_ cell: TUICommonContactCell_Minimalist) {
        let vc = TUIBlackListController_Minimalist()
        vc.didSelectCellBlock = { [weak self] cell in
            guard let self = self else { return }
            self.onSelectFriend(cell)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func runSelector(_ selector: Selector, withObject object: Any?) {
        if responds(to: selector) {
            perform(selector, with: object)
        }
    }

    // MARK: - UITableViewDataSource

    public func numberOfSections(in tableView: UITableView) -> Int {
        return (viewModel.groupList.count) + 1
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return firstGroupData.count
        } else {
            let group = viewModel.groupList[section - 1]
            let list = viewModel.dataDict[group] ?? []
            return list.count
        }
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: kContactActionCellReuseId, for: indexPath) as! TUIContactActionCell_Minimalist
            cell.fill(with: firstGroupData[indexPath.row])
            cell.changeColorWhenTouched = true
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: kContactCellReuseId, for: indexPath) as! TUICommonContactCell_Minimalist
            let group = viewModel.groupList[indexPath.section - 1]
            let list = viewModel.dataDict[group] ?? []
            let data = list[indexPath.row]
            data.cselector = #selector(onSelectFriend(_:))
            cell.fill(with: data)
            cell.changeColorWhenTouched = true
            cell.separtorView.isHidden = true
            return cell
        }
    }

    // MARK: - UITableViewDelegate

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle row selection
    }

    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 { return nil }

        let headerViewId = "ContactDrawerView"
        var headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerViewId)
        if headerView == nil {
            headerView = UITableViewHeaderFooterView(reuseIdentifier: headerViewId)
            let textLabel = UILabel(frame: .zero)
            textLabel.tag = 1
            textLabel.font = UIFont.systemFont(ofSize: 16)
            textLabel.textColor = UIColor.tui_color(withHex: "#000000")
            textLabel.rtlAlignment = .leading
            headerView?.addSubview(textLabel)
            textLabel.snp.remakeConstraints { make in
                make.leading.equalTo(headerView!.snp.leading).offset(12)
                make.top.bottom.trailing.equalTo(headerView!)
            }
            textLabel.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        }
        let label = headerView?.viewWithTag(1) as? UILabel
        label?.text = viewModel.groupList[section - 1]
        headerView?.backgroundColor = .white
        headerView?.contentView.backgroundColor = .white
        return headerView
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TUISwift.kScale390(52)
    }

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section == 0 ? 0 : 33
    }

    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        var array = [""]
        array.append(contentsOf: viewModel.groupList)
        return array
    }
}

class IUContactView_Minimalist: UIView {
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
