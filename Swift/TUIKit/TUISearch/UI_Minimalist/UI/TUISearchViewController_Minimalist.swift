import TIMCommon
import UIKit

class TUISearchViewController_Minimalist: UIViewController, UITableViewDelegate, UITableViewDataSource, TUISearchBarDelegate_Minimalist, TUISearchResultDelegate {
    private var searchBar: TUISearchBar_Minimalist!
    private var tableView: UITableView!
    private var dataProvider: TUISearchDataProvider!
    lazy var noDataEmptyView: TUISearchEmptyView_Minimalist = {
        let view = TUISearchEmptyView_Minimalist(
            image: TUISwift.tuiSearchBundleThemeImage("", defaultImage: "search_not_found_icon"),
            text: TUISwift.timCommonLocalizableString("TUIKitSearchNoResultLists")
        )
        view.isHidden = true
        return view
    }()
    
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
        view.backgroundColor = .white
        searchBar = TUISearchBar_Minimalist()
        searchBar.setEntrance(false)
        searchBar.delegate = self
        navigationItem.titleView = searchBar
        
        tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .white
        tableView.separatorStyle = .none
        tableView.rowHeight = TUISwift.kScale390(72)
        tableView.register(TUISearchResultCell_Minimalist.self, forCellReuseIdentifier: TUISearchViewController_Minimalist.cellId)
        tableView.register(TUISearchResultHeaderFooterView_Minimalist.self, forHeaderFooterViewReuseIdentifier: TUISearchViewController_Minimalist.headerFooterId)
        view.addSubview(tableView)
        
        noDataEmptyView = TUISearchEmptyView_Minimalist(image: TUISwift.tuiSearchBundleThemeImage("", defaultImage: "search_not_found_icon"), text: TUISwift.timCommonLocalizableString("TUIKitSearchNoResultLists"))
        noDataEmptyView.isHidden = true
        noDataEmptyView.frame = CGRect(x: 0, y: TUISwift.kScale390(42), width: view.bounds.size.width - 20, height: 200)
        tableView.addSubview(noDataEmptyView)
        
        searchBar.searchBar.becomeFirstResponder()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tableView.frame = view.bounds
        searchBar.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 44)
    }
    
    private func navBackColor() -> UIColor {
        return .white
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithDefaultBackground()
            appearance.shadowColor = nil
            appearance.backgroundEffect = nil
            appearance.backgroundColor = navBackColor()
            let navigationBar = navigationController?.navigationBar
            navigationBar?.backgroundColor = navBackColor()
            navigationBar?.barTintColor = navBackColor()
            navigationBar?.shadowImage = UIImage()
            navigationBar?.standardAppearance = appearance
            navigationBar?.scrollEdgeAppearance = appearance
        } else {
            let navigationBar = navigationController?.navigationBar
            navigationBar?.backgroundColor = navBackColor()
            navigationBar?.barTintColor = navBackColor()
            navigationBar?.shadowImage = UIImage()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // MARK: - TUISearchResultDelegate

    func onSearchError(_ errMsg: String) {
        // Handle search error
    }
    
    func onSearchResults(_ results: [Int: [TUISearchResultCellModel]], forModules modules: TUISearchResultModule) {
        noDataEmptyView.isHidden = true
        if results.isEmpty {
            noDataEmptyView.isHidden = false
            if searchBar.searchBar.text?.isEmpty ?? true {
                noDataEmptyView.isHidden = true
            }
        }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: TUISearchViewController_Minimalist.cellId, for: indexPath) as! TUISearchResultCell_Minimalist
        var module: TUISearchResultModule? = .contact
        let results = resultForSection(indexPath.section, module: &module)
        if indexPath.row >= results.count {
            return cell
        }
        let model = results[indexPath.row]
        model.avatarType = .TAvatarTypeRadiusCorner
        cell.fillWithData(model)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 20
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        var module: TUISearchResultModule? = .contact
        _ = resultForSection(section, module: &module)
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: TUISearchViewController_Minimalist.headerFooterId) as! TUISearchResultHeaderFooterView_Minimalist
        headerView.isFooter = false
        headerView.showMoreBtn = true
        if let module = module {
            headerView.title = titleForModule(module, isHeader: true)
        }
        let results = resultForSection(section, module: &module)
        headerView.onTap = { [weak self] in
            guard let self else { return }
            self.onSelectMoreModule(module ?? TUISearchResultModule(), results: results)
        }
   
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
        if indexPath.row >= results.count {
            return
        }
        let cellModel = results[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath) as! TUISearchResultCell_Minimalist
        cellModel.avatarImage = cell.avatarView.image
        cellModel.title = cell.title_label.text
        if let module = module {
            onSelectModel(cellModel, module: module)
        }
    }
    
    // MARK: - Actions

    private func onSelectModel(_ cellModel: TUISearchResultCellModel, module: TUISearchResultModule) {
        searchBar.endEditing(true)
        
        if module == .chatHistory {
            guard let convInfo = cellModel.context as? [String: Any] else { return }
            let conversationId = convInfo[kSearchChatHistoryConversationId] as! String
            let conversation = convInfo[kSearchChatHistoryConverationInfo] as! V2TIMConversation
            let msgs = convInfo[kSearchChatHistoryConversationMsgs] as! [V2TIMMessage]
            
            var results: [TUISearchResultCellModel] = []
            for message in msgs {
                let model = TUISearchResultCellModel()
                model.title = message.nickName ?? message.sender
                let desc = TUISearchDataProvider.matchedText(forMessage: message, withKey: searchBar.searchBar.text ?? "")
                model.detailsAttributeString = TUISearchDataProvider.attributeString(withText: desc, key: searchBar.searchBar.text)
                model.avatarUrl = message.faceURL
                model.groupType = conversation.groupID
                model.avatarImage = conversation.type == .C2C ? TUISwift.defaultAvatarImage() : TUISwift.defaultGroupAvatarImage(byGroupType: conversation.groupType)
                model.context = message
                results.append(model)
            }
            let vc = TUISearchResultListController_Minimalist(results: results, keyword: searchBar.searchBar.text, module: module, param: [TUISearchChatHistoryParamKeyConversationId: conversationId])
            vc.headerConversationAvatar = cellModel.avatarImage
            vc.headerConversationShowName = cellModel.title
            navigationController?.pushViewController(vc, animated: true)
            return
        }
        
        var param: [String: Any]? = nil
        let title = cellModel.title ?? cellModel.titleAttributeString?.string
        if module == .contact, let friend = cellModel.context as? V2TIMFriendInfo {
            param = [
                "TUICore_TUIChatObjectFactory_ChatViewController_Title": title ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_UserID": friend.userID ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": cellModel.avatarImage ?? UIImage()
            ]
        }
        
        if module == .group, let group = cellModel.context as? V2TIMGroupInfo {
            param = [
                "TUICore_TUIChatObjectFactory_ChatViewController_Title": title ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_GroupID": group.groupID ?? "",
                "TUICore_TUIChatObjectFactory_ChatViewController_AvatarImage": cellModel.avatarImage ?? UIImage()
            ]
        }
        navigationController?.push("TUICore_TUIChatObjectFactory_ChatViewController_Minimalist", param: param, forResult: nil)
    }
    
    private func onSelectMoreModule(_ module: TUISearchResultModule, results: [TUISearchResultCellModel]) {
        let vc = TUISearchResultListController_Minimalist(results: results, keyword: searchBar.searchBar.text, module: module, param: nil)
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

    func searchBarDidCancelClicked(_ searchBar: TUISearchBar_Minimalist) {
        dismiss(animated: false, completion: nil)
    }
    
    func searchBar(_ searchBar: TUISearchBar_Minimalist, searchText key: String) {
        dataProvider.searchForKeyword(key, forModules: .all, param: nil)
    }
    
    func searchBarDidEnterSearch(_ searchBar: TUISearchBar_Minimalist) {}
        
    private func imageWithColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()
        
        context?.setFillColor(color.cgColor)
        context?.fill(rect)
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image ?? UIImage()
    }
}

class IUSearchView_Minimalist: UIView {
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
