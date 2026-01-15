import UIKit
import TIMCommon
import TUICore
import SnapKit

/// View controller for displaying official account list
public class TUIOfficialAccountListViewController: UIViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        static let cellReuseIdentifier = "TUIOfficialAccountCell"
        static let headerReuseIdentifier = "TUIOfficialAccountSectionHeader"
    }
    
    // MARK: - Properties
    
    private let presenter = TUIOfficialAccountListPresenter()
    
    // MARK: - UI Components
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F9F9F9")
        tableView.register(TUIOfficialAccountCell.self, forCellReuseIdentifier: Constants.cellReuseIdentifier)
        tableView.register(TUIOfficialAccountSectionHeader.self, forHeaderFooterViewReuseIdentifier: Constants.headerReuseIdentifier)
        tableView.rowHeight = TUIOfficialAccountCellData.cellHeight
        tableView.sectionHeaderHeight = TUIOfficialAccountSectionHeader.headerHeight
        tableView.sectionFooterHeight = 0
        tableView.tableFooterView = UIView()
        return tableView
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    private lazy var emptyView: UIView = {
        let view = UIView()
        view.isHidden = true
        
        let imgView = UIImageView()
        imgView.image = TUISwift.timCommonBundleThemeImage(
            "empty_img",
            defaultImage: "empty"
        )
        imgView.contentMode = .scaleAspectFit
        
        let label = UILabel()
        label.text = TUISwift.timCommonLocalizableString("TUIKitNoOfficialAccounts")
        label.textColor = TUISwift.timCommonDynamicColor("form_desc_color", defaultColor: "#888888")
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        
        view.addSubview(imgView)
        view.addSubview(label)
        
        imgView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-30)
            make.size.equalTo(100)
        }
        
        label.snp.makeConstraints { make in
            make.top.equalTo(imgView.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
        }
        
        return view
    }()
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupPresenter()
        loadData()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = TUISwift.timCommonLocalizableString("TUIKitOfficialAccount")
        view.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F9F9F9")
        
        view.addSubview(tableView)
        view.addSubview(emptyView)
        
        tableView.refreshControl = refreshControl
        
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        emptyView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
    private func setupPresenter() {
        presenter.onDataUpdated = { [weak self] in
            self?.handleDataUpdated()
        }
        
        presenter.onError = { [weak self] message in
            self?.showError(message)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() {
        presenter.loadData()
    }
    
    @objc private func handleRefresh() {
        presenter.refreshData()
    }
    
    private func handleDataUpdated() {
        refreshControl.endRefreshing()
        tableView.reloadData()
        
        let isEmpty = presenter.sections.isEmpty
        emptyView.isHidden = !isEmpty
        tableView.isHidden = isEmpty
    }
    
    // MARK: - Actions
    
    private func handleFollowButtonTapped(cellData: TUIOfficialAccountCellData) {
        if cellData.isFollowed {
            presenter.unfollowAccount(accountID: cellData.accountID)
        } else {
            presenter.followAccount(accountID: cellData.accountID)
        }
    }
    
    private func navigateToAccountInfo(accountID: String) {
        let infoVC = TUIOfficialAccountInfoViewController(accountID: accountID)
        navigationController?.pushViewController(infoVC, animated: true)
    }
    
    // MARK: - Error Handling
    
    private func showError(_ message: String) {
        refreshControl.endRefreshing()
        
        let alert = UIAlertController(
            title: TUISwift.timCommonLocalizableString("TUIKitError"),
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: TUISwift.timCommonLocalizableString("TUIKitConfirm"),
            style: .default
        ))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension TUIOfficialAccountListViewController: UITableViewDataSource {
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return presenter.sections.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return presenter.section(at: section)?.cellDataList.count ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: Constants.cellReuseIdentifier,
            for: indexPath
        ) as? TUIOfficialAccountCell else {
            return UITableViewCell()
        }
        
        let section = presenter.section(at: indexPath.section)
        cell.cellData = presenter.cellData(at: indexPath)
        // Show as subscribed for created and followed sections (no follow button, show last message)
        cell.showAsSubscribed = (section?.type == .created || section?.type == .followed)
        cell.onFollowButtonTapped = { [weak self] cellData in
            self?.handleFollowButtonTapped(cellData: cellData)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension TUIOfficialAccountListViewController: UITableViewDelegate {
    
    public func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(
            withIdentifier: Constants.headerReuseIdentifier
        ) as? TUIOfficialAccountSectionHeader else {
            return nil
        }
        
        header.title = presenter.section(at: section)?.title
        return header
    }
    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return CGFloat.leastNormalMagnitude
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let cellData = presenter.cellData(at: indexPath) else { return }
        navigateToAccountInfo(accountID: cellData.accountID)
    }
    
    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Load more when scrolling to near bottom (5 items before the end)
        guard let section = presenter.section(at: indexPath.section),
              section.type == .recommended else {
            return
        }
        
        let totalRows = section.cellDataList.count
        if indexPath.row >= totalRows - 5 && presenter.canLoadMore {
            presenter.loadMoreRecommendedAccounts()
        }
    }
}
