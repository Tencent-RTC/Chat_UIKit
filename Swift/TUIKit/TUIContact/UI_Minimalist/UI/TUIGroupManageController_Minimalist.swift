import TIMCommon
import UIKit

class TUIGroupManageController_Minimalist: UIViewController, UITableViewDelegate, UITableViewDataSource, TUIGroupManageDataProviderDelegate_Minimalist {
    var groupID: String?
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = UIColor.tui_color(withHex: "#f9f9f9")
        tableView.delaysContentTouches = false
        return tableView
    }()
    
    private let dataProvider = TUIGroupManageDataProvider_Minimalist()
    private var coverView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.tui_color(withHex: "#f9f9f9")
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        dataProvider.groupID = groupID
        dataProvider.delegate = self
        showCoverViewWhenMuteAll(true)
        dataProvider.loadData()
    }
    
    private func setupViews() {
        let titleLabel = UILabel()
        titleLabel.text = TUISwift.timCommonLocalizableString("TUIKitGroupProfileManage")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17.0)
        titleLabel.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        titleLabel.sizeToFit()
        navigationItem.titleView = titleLabel
        view.addSubview(tableView)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
    }
    
    @objc private func onSettingAdmin(_ textData: TUICommonTextCellData) {
        guard dataProvider.currentGroupTypeSupportSettingAdmin else {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupSetAdminsForbidden"))
            return
        }
        let vc = TUISettingAdminController_Minimalist()
        vc.groupID = groupID
        vc.settingAdminDissmissCallBack = { [weak self] in
            guard let self else { return }
            self.dataProvider.updateMuteMembersFilterAdmins()
            self.tableView.reloadData()
        }
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func onMutedAll(_ switchCell: TUICommonSwitchCell) {
        dataProvider.mutedAll(switchCell.switcher.isOn) { [weak self] code, error in
            guard let self else { return }
            guard code == 0 else {
                switchCell.switcher.isOn.toggle()
                self.view.tui_makeToast(error ?? "")
                return
            }
            self.showCoverViewWhenMuteAll(switchCell.switcher.isOn)
        }
    }
    
    // MARK: - TUIGroupManageDataProviderDelegate_Minimalist
    
    func onError(_ code: Int, desc: String, operate: String) {
        guard code == 0 else { return }
        TUITool.makeToast("\(code), \(desc)")
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
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.showCoverViewWhenMuteAll(self.dataProvider.muteAll)
        }
    }
    
    func insertSections(_ sections: IndexSet, withRowAnimation animation: UITableView.RowAnimation) {
        tableView.insertSections(sections, with: animation)
    }
    
    func reloadRowsAtIndexPaths(_ indexPaths: [IndexPath], withRowAnimation animation: UITableView.RowAnimation) {
        tableView.reloadRows(at: indexPaths, with: animation)
    }
    
    func insertRowsAtIndexPaths(_ indexPaths: [IndexPath], withRowAnimation animation: UITableView.RowAnimation) {
        tableView.insertRows(at: indexPaths, with: animation)
    }
    
    // MARK: UITableViewDelegate & UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataProvider.datas.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let subArray = dataProvider.datas[section] as! NSArray
        return subArray.count
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
        } else if let memberData = data as? TUIMemberInfoCellData_Minimalist {
            cell = TUIMemberInfoCell_Minimalist(style: .value1, reuseIdentifier: String(describing: TUIMemberInfoCell_Minimalist.self))
            (cell as? TUIMemberInfoCell_Minimalist)?.setData(memberData)
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
        return section == 0 ? TUISwift.kScale390(53) : 0
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = UIColor.tui_color(withHex: "#f9f9f9")
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("TUIKitGroupManageShutupAllTips")
        label.textColor = UIColor(red: 136 / 255.0, green: 136 / 255.0, blue: 136 / 255.0, alpha: 1.0)
        label.font = UIFont.systemFont(ofSize: 14.0)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.textAlignment = .justified
        
        view.addSubview(label)
        label.sizeToFit()
        label.frame = CGRect(x: TUISwift.kScale390(20), y: TUISwift.kScale390(3), width: TUISwift.screen_Width() - 2 * TUISwift.kScale390(20), height: TUISwift.kScale390(53))
        
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        if indexPath.section == 1, indexPath.row == 0 {
            guard dataProvider.currentGroupTypeSupportAddMemberOfBlocked else {
                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitGroupAddMemberOfBlockedForbidden"))
                return
            }
            
            let vc = TUISelectGroupMemberViewController_Minimalist()
            vc.optionalStyle = .publicMan
            vc.groupId = groupID
            vc.name = TUISwift.timCommonLocalizableString("TUIKitGroupProfileMember")
            vc.selectedFinished = { [weak self] modelList in
                guard let self else { return }
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
            guard let cellData = datas[indexPath.row] as? TUIMemberInfoCellData_Minimalist else {
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
