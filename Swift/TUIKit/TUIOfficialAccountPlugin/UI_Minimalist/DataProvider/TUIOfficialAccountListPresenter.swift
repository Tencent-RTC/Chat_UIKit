import Foundation
import TIMCommon

/// Presenter for Official Account list view
public class TUIOfficialAccountListPresenter: NSObject {
    
    // MARK: - Properties
    
    private let dataProvider: TUIOfficialAccountDataProvider
    
    /// Section data for table view
    public private(set) var sections: [TUIOfficialAccountListSection] = []
    
    /// Loading state
    public var isLoading: Bool {
        return dataProvider.isLoading
    }
    
    // MARK: - Callbacks
    
    public var onDataUpdated: (() -> Void)?
    public var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public init(dataProvider: TUIOfficialAccountDataProvider = TUIOfficialAccountDataProvider()) {
        self.dataProvider = dataProvider
        super.init()
        setupDataProvider()
    }
    
    // MARK: - Setup
    
    private func setupDataProvider() {
        dataProvider.onDataUpdated = { [weak self] in
            self?.updateSections()
            self?.onDataUpdated?()
        }
        
        dataProvider.onError = { [weak self] message in
            self?.onError?(message)
        }
    }
    
    // MARK: - Data Loading
    
    /// Load all data
    public func loadData() {
        dataProvider.loadAllAccounts { [weak self] in
            self?.updateSections()
            self?.onDataUpdated?()
        }
    }
    
    /// Refresh data
    public func refreshData() {
        loadData()
    }
    
    /// Load more recommended accounts
    public func loadMoreRecommendedAccounts() {
        dataProvider.loadMoreRecommendedAccounts { [weak self] _, _ in
            self?.updateSections()
            self?.onDataUpdated?()
        }
    }
    
    /// Check if can load more recommended accounts
    public var canLoadMore: Bool {
        return dataProvider.canLoadMoreRecommended
    }
    
    // MARK: - Section Management
    
    private func updateSections() {
        var newSections: [TUIOfficialAccountListSection] = []
        
        // Created accounts section (accounts created by current user)
        if !dataProvider.createdAccounts.isEmpty {
            let createdCellData = dataProvider.createdAccounts.map { info -> TUIOfficialAccountCellData in
                let cellData = TUIOfficialAccountCellData(accountInfo: info)
                cellData.lastMessage = dataProvider.getLastMessage(for: info.accountID)
                return cellData
            }
            let createdSection = TUIOfficialAccountListSection(
                type: .created,
                title: TUISwift.timCommonLocalizableString("TUIKitCreatedAccounts") ?? "Created",
                cellDataList: createdCellData
            )
            newSections.append(createdSection)
        }
        
        // Followed accounts section
        if !dataProvider.followedAccounts.isEmpty {
            let followedCellData = dataProvider.followedAccounts.map { info -> TUIOfficialAccountCellData in
                let cellData = TUIOfficialAccountCellData(accountInfo: info)
                cellData.lastMessage = dataProvider.getLastMessage(for: info.accountID)
                return cellData
            }
            let followedSection = TUIOfficialAccountListSection(
                type: .followed,
                title: TUISwift.timCommonLocalizableString("TUIKitFollowedAccounts"),
                cellDataList: followedCellData
            )
            newSections.append(followedSection)
        }
        
        // Recommended accounts section
        if !dataProvider.recommendedAccounts.isEmpty {
            let recommendedCellData = dataProvider.recommendedAccounts.map { info in
                TUIOfficialAccountCellData(accountInfo: info)
            }
            let recommendedSection = TUIOfficialAccountListSection(
                type: .recommended,
                title: TUISwift.timCommonLocalizableString("TUIKitRecommendedAccounts"),
                cellDataList: recommendedCellData
            )
            newSections.append(recommendedSection)
        }
        
        sections = newSections
    }
    
    // MARK: - Actions
    
    /// Follow account
    /// - Parameters:
    ///   - accountID: Account ID
    ///   - completion: Completion handler
    public func followAccount(accountID: String, completion: ((Bool) -> Void)? = nil) {
        dataProvider.followAccount(accountID: accountID) { success, error in
            completion?(success)
        }
    }
    
    /// Unfollow account
    /// - Parameters:
    ///   - accountID: Account ID
    ///   - completion: Completion handler
    public func unfollowAccount(accountID: String, completion: ((Bool) -> Void)? = nil) {
        dataProvider.unfollowAccount(accountID: accountID) { success, error in
            completion?(success)
        }
    }
    
    // MARK: - Data Access
    
    /// Get cell data at index path
    /// - Parameter indexPath: Index path
    /// - Returns: Cell data if exists
    public func cellData(at indexPath: IndexPath) -> TUIOfficialAccountCellData? {
        guard indexPath.section < sections.count,
              indexPath.row < sections[indexPath.section].cellDataList.count else {
            return nil
        }
        return sections[indexPath.section].cellDataList[indexPath.row]
    }
    
    /// Get section at index
    /// - Parameter index: Section index
    /// - Returns: Section if exists
    public func section(at index: Int) -> TUIOfficialAccountListSection? {
        guard index < sections.count else { return nil }
        return sections[index]
    }
}

// MARK: - Section Model

public enum TUIOfficialAccountListSectionType {
    case created
    case followed
    case recommended
}

public class TUIOfficialAccountListSection {
    public let type: TUIOfficialAccountListSectionType
    public let title: String
    public var cellDataList: [TUIOfficialAccountCellData]
    
    public init(
        type: TUIOfficialAccountListSectionType,
        title: String,
        cellDataList: [TUIOfficialAccountCellData]
    ) {
        self.type = type
        self.title = title
        self.cellDataList = cellDataList
    }
}
