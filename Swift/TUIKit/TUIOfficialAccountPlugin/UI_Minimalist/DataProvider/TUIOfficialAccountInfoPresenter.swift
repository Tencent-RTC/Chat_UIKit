import Foundation
import TIMCommon

/// Presenter for Official Account info/detail view
public class TUIOfficialAccountInfoPresenter: NSObject {
    
    // MARK: - Properties
    
    private let dataProvider: TUIOfficialAccountDataProvider
    
    /// Account ID
    public let accountID: String
    
    /// Account info
    public private(set) var accountInfo: TUIOfficialAccountInfo?
    
    /// Loading state
    public private(set) var isLoading: Bool = false
    
    // MARK: - Callbacks
    
    public var onAccountInfoUpdated: ((TUIOfficialAccountInfo?) -> Void)?
    public var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public init(
        accountID: String,
        dataProvider: TUIOfficialAccountDataProvider = TUIOfficialAccountDataProvider()
    ) {
        self.accountID = accountID
        self.dataProvider = dataProvider
        super.init()
        setupNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFollowChanged(_:)),
            name: TUIOfficialAccountFollowChangedNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInfoUpdated(_:)),
            name: TUIOfficialAccountInfoUpdatedNotification,
            object: nil
        )
    }
    
    // MARK: - Data Loading
    
    /// Load account info
    public func loadAccountInfo() {
        isLoading = true
        
        dataProvider.getAccountInfo(accountID: accountID) { [weak self] info, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.onError?(error.localizedDescription)
                return
            }
            
            self.accountInfo = info
            self.onAccountInfoUpdated?(info)
        }
    }
    
    // MARK: - Actions
    
    /// Follow this account
    /// - Parameter completion: Completion handler
    public func followAccount(completion: ((Bool) -> Void)? = nil) {
        dataProvider.followAccount(accountID: accountID) { [weak self] success, error in
            if success {
                self?.accountInfo?.followStatus = .followed
                self?.onAccountInfoUpdated?(self?.accountInfo)
            }
            completion?(success)
        }
    }
    
    /// Unfollow this account
    /// - Parameter completion: Completion handler
    public func unfollowAccount(completion: ((Bool) -> Void)? = nil) {
        dataProvider.unfollowAccount(accountID: accountID) { [weak self] success, error in
            if success {
                self?.accountInfo?.followStatus = .notFollowed
                self?.onAccountInfoUpdated?(self?.accountInfo)
            }
            completion?(success)
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleFollowChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationAccountID = userInfo["accountID"] as? String,
              notificationAccountID == accountID,
              let isFollowed = userInfo["isFollowed"] as? Bool else {
            return
        }
        
        accountInfo?.followStatus = isFollowed ? .followed : .notFollowed
        onAccountInfoUpdated?(accountInfo)
    }
    
    @objc private func handleInfoUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationAccountID = userInfo["accountID"] as? String,
              notificationAccountID == accountID,
              let updatedInfo = userInfo["accountInfo"] as? TUIOfficialAccountInfo else {
            return
        }
        
        accountInfo = updatedInfo
        onAccountInfoUpdated?(accountInfo)
    }
}
