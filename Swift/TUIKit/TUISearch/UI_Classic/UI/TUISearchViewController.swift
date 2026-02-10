import TIMCommon
import UIKit

class TUISearchViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, TUISearchBarDelegate, TUISearchResultDelegate {
    private var searchBar: TUISearchBar!
    private var tableView: UITableView!
    private var dataProvider: TUISearchDataProvider!
    
    private static let cellId = "cell"
    private static let headerFooterId = "HFId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        dataProvider = TUISearchDataProvider()
        dataProvider.delegate = self
        setupViews()
        TUITool.addUnsupportNotification(inVC: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupViews() {
        view.backgroundColor = .groupTableViewBackground
        searchBar = TUISearchBar()
        searchBar.setEntrance(false)
        searchBar.delegate = self
        navigationItem.titleView = searchBar
        
        tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .groupTableViewBackground
        tableView.separatorStyle = .none
        tableView.rowHeight = 60.0
        tableView.register(TUISearchResultCell.self, forCellReuseIdentifier: TUISearchViewController.cellId)
        tableView.register(TUISearchResultHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: TUISearchViewController.headerFooterId)
        view.addSubview(tableView)
        
        searchBar.searchBar.becomeFirstResponder()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
        searchBar.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 44)
    }
    
    // MARK: - TUISearchResultDelegate

    func onSearchError(_ errMsg: String) {
        // Handle search error
    }
    
    func onSearchResults(_ results: [Int: [TUISearchResultCellModel]], forModules modules: TUISearchResultModule) {
        tableView.reloadData()
    }
    
    // MARK: - UITableViewDataSource, UITableViewDelegate

    func numberOfSections(in tableView: UITableView) -> Int {
        return dataProvider.resultSet.keys.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let results = resultForSection(section)
        return min(results.count, kMaxNumOfPerModule)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TUISearchViewController.cellId, for: indexPath) as! TUISearchResultCell
        var module: TUISearchResultModule? = .contact
        let results = resultForSection(indexPath.section, module: &module)
        if indexPath.row < results.count {
            cell.fillWithData(results[indexPath.row])
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        var module: TUISearchResultModule? = .contact
        let results = resultForSection(section, module: &module)
        if results.count < kMaxNumOfPerModule {
            return UIView()
        }
        let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: TUISearchViewController.headerFooterId) as! TUISearchResultHeaderFooterView
        footerView.isFooter = true
        if let module = module {
            footerView.title = titleForModule(module, isHeader: false)
            footerView.onTap = { [weak self] in
                self?.onSelectMoreModule(module, results: results)
            }
        }
        return footerView
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let results = resultForSection(section)
        return results.count < kMaxNumOfPerModule ? 10 : 44
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var module: TUISearchResultModule? = .contact
        _ = resultForSection(section, module: &module)
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: TUISearchViewController.headerFooterId) as! TUISearchResultHeaderFooterView
        headerView.isFooter = false
        if let module = module {
            headerView.title = titleForModule(module, isHeader: true)
        }
        headerView.onTap = nil
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
        searchBar.endEditing(true)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        var module: TUISearchResultModule? = .contact
        let results = resultForSection(indexPath.section, module: &module)
        if indexPath.row < results.count {
            let cellModel = results[indexPath.row]
            if let module = module {
                onSelectModel(cellModel, module: module)
            }
        }
    }
    
    // MARK: - Actions

    private func onSelectModel(_ cellModel: TUISearchResultCellModel, module: TUISearchResultModule) {
        searchBar.endEditing(true)
        
        if module == .chatHistory {
            guard let context = cellModel.context as? [String: Any] else { return }
            let conversationId = context[kSearchChatHistoryConversationId] as? String
            let conversation = context[kSearchChatHistoryConverationInfo] as? V2TIMConversation
            let msgs = context[kSearchChatHistoryConversationMsgs] as? [V2TIMMessage]
            if msgs?.count == 1 {
                let title = cellModel.title ?? cellModel.titleAttributeString?.string
                let param: [String: Any] = [
                    "TUICore_TUIChatObjectFactory_ChatViewController_Title": title ?? "",
                    "TUICore_TUIChatObjectFactory_ChatViewController_UserID": conversation?.userID ?? "",
                    "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": conversation?.groupID ?? "",
                    "TUICore_TUIChatObjectFactory_ChatViewController_HighlightKeyword": searchBar.searchBar.text ?? "",
                    "TUICore_TUIChatObjectFactory_ChatViewController_LocateMessage": msgs?.first ?? ""
                ]
                navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Classic", param: param, forResult: nil)
                return
            }
            
            var results = [TUISearchResultCellModel]()
            for message in msgs ?? [] {
                let model = TUISearchResultCellModel()
                model.title = message.nickName ?? message.sender
                let desc = TUISearchDataProvider.matchedText(forMessage: message, withKey: searchBar.searchBar.text ?? "")
                model.detailsAttributeString = TUISearchDataProvider.attributeString(withText: desc, key: searchBar.searchBar.text ?? "")
                model.avatarUrl = message.faceURL
                model.groupType = conversation?.groupType
                model.avatarImage = conversation?.type == .C2C ? TUISwift.defaultAvatarImage() : TUISwift.defaultGroupAvatarImage(byGroupType: conversation?.groupType)
                model.context = message
                results.append(model)
            }
            let vc = TUISearchResultListController(results: results, keyword: searchBar.searchBar.text, module: module, param: [TUISearchChatHistoryParamKeyConversationId: conversationId ?? ""])
            navigationController?.pushViewController(vc, animated: true)
            return
        }
        
        var param: [String: Any]?
        
        if module == .contact, let friend = cellModel.context as? V2TIMFriendInfo {
            let title = cellModel.title ?? cellModel.titleAttributeString?.string
            param = [
                "TUICore_TUIChatObjectFactory_ChatViewController_Title": title ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_UserID": friend.userID ?? ""
            ]
        }
        
        if module == .group, let group = cellModel.context as? V2TIMGroupInfo {
            let title = cellModel.title ?? cellModel.titleAttributeString?.string
            param = [
                "TUICore_TUIChatObjectFactory_ChatViewController_Title": title ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": group.groupID ?? ""
            ]
        }
        navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Classic", param: param, forResult: nil)
    }
    
    private func onSelectMoreModule(_ module: TUISearchResultModule, results: [TUISearchResultCellModel]) {
        let vc = TUISearchResultListController(results: results, keyword: searchBar.searchBar.text, module: module, param: nil)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    // MARK: - ViewModel

    private func resultForSection(_ section: Int) -> [TUISearchResultCellModel] {
        var module: TUISearchResultModule? = nil
        return resultForSection(section, module: &module)
    }
    
    private func resultForSection(_ section: Int, module: inout TUISearchResultModule?) -> [TUISearchResultCellModel] {
        var keys = Array(dataProvider.resultSet.keys)
        if section >= keys.count {
            return []
        }
        keys.sort { $0 < $1 }
        
        let key = keys[section]
        if module != nil {
            module = TUISearchResultModule(rawValue: key)
        }
        return dataProvider.resultSet[key] ?? []
    }
    
    // MARK: - TUISearchBarDelegate

    func searchBarDidCancelClicked(_ searchBar: TUISearchBar) {
        dismiss(animated: false, completion: nil)
    }
    
    func searchBar(_ searchBar: TUISearchBar, searchText key: String) {
        dataProvider.searchForKeyword(key, forModules: .all, param: nil)
    }
    
    func searchBarDidEnterSearch(_ searchBar: TUISearchBar) {}
        
    private func imageWithColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
}

class IUSearchView: UIView {
    var view: UIView
    
    override init(frame: CGRect) {
        view = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        super.init(frame: frame)
        addSubview(view)
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
