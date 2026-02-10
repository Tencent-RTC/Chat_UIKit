import TIMCommon
import UIKit

class TUIGroupManageController: UIViewController, UITableViewDelegate, UITableViewDataSource, TUIGroupManageDataProviderDelegate {
    var groupID: String?
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: self.view.bounds, style: .grouped)
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        tableView.delaysContentTouches = false
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    lazy var dataProvider: TUIGroupManageDataProvider = {
        let dataProvider = TUIGroupManageDataProvider()
        dataProvider.delegate = self
        return dataProvider
    }()

    lazy var coverView: UIView = {
        let coverView = UIView()
        coverView.backgroundColor = self.tableView.backgroundColor
        return coverView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        if let groupID = groupID {
            dataProvider.groupID = groupID
            showCoverViewWhenMuteAll(true)
            dataProvider.loadData()
        }
    }

    private func setupViews() {
        let titleLabel = UILabel()
        titleLabel.text = TUISwift.timCommonLocalizableString("TUIKitGroupProfileManage")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17.0)
        titleLabel.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        view.addSubview(tableView)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }

    @objc func onSettingAdmin(_ textData: TUICommonTextCellData) {
        guard dataProvider.currentGroupTypeSupportSettingAdmin else {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupSetAdminsForbidden"))
            return
        }
        let vc = TUISettingAdminController()
        vc.groupID = groupID
        weak var weakSelf = self
        vc.settingAdminDissmissCallBack = {
            weakSelf?.dataProvider.updateMuteMembersFilterAdmins()
            weakSelf?.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func onMutedAll(_ switchCell: TUICommonSwitchCell) {
        weak var weakSelf = self
        dataProvider.mutedAll(switchCell.switcher.isOn) { code, error in
            if code != 0 {
                switchCell.switcher.isOn.toggle()
                weakSelf?.view.tui_makeToast(error ?? "")
                return
            }
            weakSelf?.showCoverViewWhenMuteAll(switchCell.switcher.isOn)
        }
    }

    // MARK: - TUIGroupManageDataProviderDelegate

    func onError(_ code: Int, desc: String, operate: String) {
        if code != 0 {
            TUITool.makeToast("\(code), \(desc)")
        }
    }

    func showCoverViewWhenMuteAll(_ show: Bool) {
        coverView.removeFromSuperview()
        if show {
            let y: CGFloat
            if dataProvider.datas.isEmpty {
                y = 100
            } else {
                let rect = tableView.rect(forSection: 0)
                y = rect.maxY
            }
            coverView.frame = CGRect(x: 0, y: y, width: tableView.frame.width, height: tableView.frame.height)
            tableView.addSubview(coverView)
        }
    }

    func reloadData() {
        tableView.reloadData()
        weak var weakSelf = self
        DispatchQueue.main.async {
            weakSelf?.showCoverViewWhenMuteAll(weakSelf?.dataProvider.muteAll ?? false)
        }
    }

    func insertSections(_ sections: IndexSet, withRowAnimation animation: UITableView.RowAnimation) {
        tableView.insertSections(sections, with: animation)
    }

    func reloadRows(at indexPaths: [IndexPath], withRowAnimation animation: UITableView.RowAnimation) {
        tableView.reloadRows(at: indexPaths, with: animation)
    }

    func insertRows(at indexPaths: [IndexPath], withRowAnimation animation: UITableView.RowAnimation) {
        tableView.insertRows(at: indexPaths, with: animation)
    }

    // MARK: - UITableViewDelegate, UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return dataProvider.datas.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let subArray = dataProvider.datas[section]
        return (subArray as AnyObject).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let subArray = dataProvider.datas[indexPath.section] as! NSArray
        let data = subArray[indexPath.row]

        let cell: UITableViewCell
        if let textData = data as? TUICommonTextCellData {
            cell = TUICommonTextCell(style: .value1, reuseIdentifier: String(describing: TUICommonTextCell.self))
            (cell as? TUICommonTextCell)?.fill(with: textData)
        } else if let switchData = data as? TUICommonSwitchCellData {
            cell = TUICommonSwitchCell(style: .value1, reuseIdentifier: String(describing: TUICommonSwitchCell.self))
            (cell as? TUICommonSwitchCell)?.fill(with: switchData)
        } else if let memberData = data as? TUIMemberInfoCellData {
            cell = TUIMemberInfoCell(style: .value1, reuseIdentifier: String(describing: TUIMemberInfoCell.self))
            if let infoCell = cell as? TUIMemberInfoCell {
                infoCell.data = memberData
            }
        } else {
            cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell()
            cell.textLabel?.text = ""
        }

        cell.selectionStyle = .none
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 48.0
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return section == 0 ? 30 : 0
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = UIColor.groupTableViewBackground
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("TUIKitGroupManageShutupAllTips")
        label.textColor = UIColor(red: 136 / 255.0, green: 136 / 255.0, blue: 136 / 255.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 14.0)
        view.addSubview(label)
        label.sizeToFit()
        label.frame.origin = CGPoint(x: 20, y: 10)
        return view
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if indexPath.section == 1 && indexPath.row == 0 {
            guard dataProvider.currentGroupTypeSupportAddMemberOfBlocked else {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupAddMemberOfBlockedForbidden"))
                return
            }

            let vc = TUISelectGroupMemberViewController()
            vc.optionalStyle = .publicMan
            vc.groupId = groupID
            vc.name = TUISwift.timCommonLocalizableString("TUIKitGroupProfileMember")
            vc.selectedFinished = { [weak self] (modelList: [TUIUserModel]) in
                guard let self = self else { return }
                for userModel in modelList {
                    self.dataProvider.mute(true, user: userModel)
                }
            }
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return TUISwift.timCommonLocalizableString("Delete")
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row > 0
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let datas = dataProvider.datas[indexPath.section] as! NSArray
            guard let cellData = datas[indexPath.row] as? TUIMemberInfoCellData else {
                return
            }

            let userModel = TUIUserModel()
            userModel.userId = cellData.identifier ?? ""
            dataProvider.mute(false, user: userModel)
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return UIView()
    }
}
