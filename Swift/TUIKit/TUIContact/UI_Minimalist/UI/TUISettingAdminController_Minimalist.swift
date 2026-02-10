// TUISettingAdminController_Minimalist.swift
// TUIContact

import TIMCommon
import UIKit

class TUISettingAdminController_Minimalist: UIViewController {
    var groupID: String?
    var settingAdminDissmissCallBack: (() -> Void)?

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: self.view.bounds, style: .grouped)
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        tableView.delaysContentTouches = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TUIMemberInfoCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()

    private lazy var dataProvider: TUISettingAdminDataProvider = .init()

    deinit {
        settingAdminDissmissCallBack?()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()

        dataProvider.groupID = groupID
        dataProvider.loadData { [weak self] code, error in
            self?.tableView.reloadData()
            if code != 0 {
                self?.view.tui_makeToast(error ?? "")
            }
        }
    }

    private func setupViews() {
        let titleLabel = UILabel()
        titleLabel.text = TUISwift.timCommonLocalizableString("TUIKitGroupManageAdminSetting")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17.0)
        titleLabel.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        view.addSubview(tableView)
    }
}

extension TUISettingAdminController_Minimalist: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataProvider.datas.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let subArray = dataProvider.datas[section]
        return subArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "cell") as? TUIMemberInfoCell else {
            return UITableViewCell()
        }
        cell.selectionStyle = .none

        let subArray = dataProvider.datas[indexPath.section]
        let cellData = subArray[indexPath.row]
        cell.data = cellData
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if indexPath.section == 1 && indexPath.row == 0 {
            let vc = TUISelectGroupMemberViewController_Minimalist()
            vc.groupId = groupID
            vc.name = TUISwift.timCommonLocalizableString("TUIKitGroupManageAdminSetting")
            vc.selectedFinished = { [weak self] modelList in
                self?.dataProvider.settingAdmins(userModels: modelList) { code, errorMsg in
                    if code != 0 {
                        self?.view.tui_makeToast(errorMsg ?? "")
                    }
                    self?.tableView.reloadData()
                }
            }
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row > 0
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return TUISwift.timCommonLocalizableString("Delete")
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let subArray = dataProvider.datas[indexPath.section]
            let cellData = subArray[indexPath.row]
            if let identifier = cellData.identifier {
                dataProvider.removeAdmin(userID: identifier) { [weak self] code, err in
                    if code != 0 {
                        self?.view.tui_makeToast(err ?? "")
                    }
                    self?.tableView.reloadData()
                }
            }
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let subArray = dataProvider.datas[section]
        var title = TUISwift.timCommonLocalizableString("TUIKitGroupOwner")
        if section == 1 {
            title = String(format: TUISwift.timCommonLocalizableString("TUIKitGroupManagerFormat"), (subArray as AnyObject).count - 1, 10)
        }

        let view = UIView()
        view.backgroundColor = UIColor.groupTableViewBackground
        let label = UILabel()
        label.text = title
        label.textColor = UIColor(red: 136 / 255.0, green: 136 / 255.0, blue: 136 / 255.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 14.0)
        view.addSubview(label)
        label.sizeToFit()
        label.frame.origin = CGPoint(x: 20, y: 10)
        return view
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
}
