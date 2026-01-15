import Foundation
import TIMCommon
import TUIChat

/// Data provider for Official Account operations
public class TUIOfficialAccountDataProvider: NSObject {
    
    // MARK: - Properties
    
    /// Subscribed accounts list (includes both created and followed)
    public private(set) var subscribedAccounts: [TUIOfficialAccountInfo] = []
    
    /// Recommended accounts list (not subscribed)
    public private(set) var recommendedAccounts: [TUIOfficialAccountInfo] = []
    
    /// Pagination state
    private var nextOffset: Int64 = 0
    private var hasMoreRecommended: Bool = true
    private var isLoadingMore: Bool = false
    
    /// Page size for loading accounts
    private let pageSize: Int = 20
    
    /// Last messages cache
    private var lastMessagesCache: [String: String] = [:]
    
    /// Current user ID
    private var currentUserID: String? {
        return V2TIMManager.sharedInstance().getLoginUser()
    }
    
    /// Current loading state
    public private(set) var isLoading: Bool = false
    
    /// Error message if any
    public private(set) var errorMessage: String?
    
    // MARK: - Callbacks
    
    public var onDataUpdated: (() -> Void)?
    public var onError: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public override init() {
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
    }
    
    // MARK: - Data Loading
    
    /// Load subscribed accounts list (accounts the user has subscribed to)
    /// - Parameter completion: Completion handler with result
    public func loadSubscribedAccounts(completion: (([TUIOfficialAccountInfo]?, Error?) -> Void)? = nil) {
        isLoading = true
        
        // Pass nil to get subscribed official accounts list
        V2TIMManager.sharedInstance().getOfficialAccountsInfo(officialAccountIDList: nil) { [weak self] resultList in
            guard let self = self else { return }
            self.isLoading = false
            
            var accounts: [TUIOfficialAccountInfo] = []
            let currentUserID = self.currentUserID
            
            if let resultList = resultList {
                for result in resultList {
                    if result.resultCode == 0, let info = result.officialAccountInfo {
                        let accountInfo = TUIOfficialAccountInfo()
                        accountInfo.accountID = info.officialAccountID ?? ""
                        accountInfo.accountName = info.officialAccountName ?? ""
                        accountInfo.faceURL = info.faceUrl ?? ""
                        accountInfo.accountDescription = info.introduction ?? ""
                        accountInfo.subscriberCount = UInt(Int(info.subscriberCount))
                        accountInfo.followStatus = .followed
                        accountInfo.ownerUserID = info.ownerUserID ?? ""
                        // Check if current user is the owner
                        accountInfo.isOwner = (info.ownerUserID == currentUserID)
                        accounts.append(accountInfo)
                    }
                }
            }
            
            self.subscribedAccounts = accounts
            self.onDataUpdated?()
            completion?(accounts, nil)
        } fail: { [weak self] code, desc in
            guard let self = self else { return }
            self.isLoading = false
            let errorMsg = desc ?? "Failed to load subscribed accounts"
            self.errorMessage = errorMsg
            self.onError?(errorMsg)
            completion?(nil, NSError(domain: "TUIOfficialAccount", code: Int(code), userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        }
    }
    
    /// Load recommended accounts list (all official accounts not subscribed)
    /// - Parameter completion: Completion handler with result
    public func loadRecommendedAccounts(completion: (([TUIOfficialAccountInfo]?, Error?) -> Void)? = nil) {
        isLoading = true
        nextOffset = 0
        hasMoreRecommended = true
        recommendedAccounts = []
        
        let param: [String: Any] = [
            "count": pageSize,
            "offset": nextOffset
        ]
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "getOfficialAccountList",
            param: param as NSObject
        ) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            
            var accounts: [TUIOfficialAccountInfo] = []
            let subscribedIDs = Set(self.subscribedAccounts.map { $0.accountID })
            
            if let resultDict = result as? [String: Any] {
                // Update pagination state
                if let nextOffsetValue = resultDict["next_offset"] as? Int64 {
                    self.nextOffset = nextOffsetValue
                    self.hasMoreRecommended = nextOffsetValue > 0
                } else {
                    self.hasMoreRecommended = false
                }
                
                if let infoList = resultDict["official_account_list"] as? [V2TIMOfficialAccountInfo] {
                    for info in infoList {
                        let accountID = info.officialAccountID ?? ""
                        // Skip already subscribed accounts
                        if subscribedIDs.contains(accountID) {
                            continue
                        }
                        
                        let accountInfo = TUIOfficialAccountInfo()
                        accountInfo.accountID = accountID
                        accountInfo.accountName = info.officialAccountName ?? ""
                        accountInfo.faceURL = info.faceUrl ?? ""
                        accountInfo.accountDescription = info.introduction ?? ""
                        accountInfo.subscriberCount = UInt(Int(info.subscriberCount))
                        accountInfo.followStatus = .notFollowed
                        accountInfo.ownerUserID = info.ownerUserID ?? ""
                        accounts.append(accountInfo)
                    }
                }
            }
            
            self.recommendedAccounts = accounts
            self.onDataUpdated?()
            completion?(accounts, nil)
        } fail: { [weak self] code, desc in
            guard let self = self else { return }
            self.isLoading = false
            // Recommended accounts failure is not critical, just log it
            TUIOfficialAccountLog.error("Failed to load recommended accounts: \(code) \(desc ?? "")")
            self.recommendedAccounts = []
            self.hasMoreRecommended = false
            self.onDataUpdated?()
            completion?([], nil)
        }
    }
    
    /// Load more recommended accounts (pagination)
    /// - Parameter completion: Completion handler with result
    public func loadMoreRecommendedAccounts(completion: (([TUIOfficialAccountInfo]?, Error?) -> Void)? = nil) {
        guard !isLoadingMore, hasMoreRecommended, !isLoading else {
            completion?([], nil)
            return
        }
        
        isLoadingMore = true
        
        let param: [String: Any] = [
            "count": pageSize,
            "offset": nextOffset
        ]
        
        V2TIMManager.sharedInstance().callExperimentalAPI(
            api: "getOfficialAccountList",
            param: param as NSObject
        ) { [weak self] result in
            guard let self = self else { return }
            self.isLoadingMore = false
            
            var accounts: [TUIOfficialAccountInfo] = []
            let subscribedIDs = Set(self.subscribedAccounts.map { $0.accountID })
            
            if let resultDict = result as? [String: Any] {
                // Update pagination state
                if let nextOffsetValue = resultDict["next_offset"] as? Int64 {
                    self.nextOffset = nextOffsetValue
                    self.hasMoreRecommended = nextOffsetValue > 0
                } else {
                    self.hasMoreRecommended = false
                }
                
                if let infoList = resultDict["official_account_list"] as? [V2TIMOfficialAccountInfo] {
                    for info in infoList {
                        let accountID = info.officialAccountID ?? ""
                        // Skip already subscribed accounts
                        if subscribedIDs.contains(accountID) {
                            continue
                        }
                        
                        // Skip duplicates
                        if self.recommendedAccounts.contains(where: { $0.accountID == accountID }) {
                            continue
                        }
                        
                        let accountInfo = TUIOfficialAccountInfo()
                        accountInfo.accountID = accountID
                        accountInfo.accountName = info.officialAccountName ?? ""
                        accountInfo.faceURL = info.faceUrl ?? ""
                        accountInfo.accountDescription = info.introduction ?? ""
                        accountInfo.subscriberCount = UInt(Int(info.subscriberCount))
                        accountInfo.followStatus = .notFollowed
                        accountInfo.ownerUserID = info.ownerUserID ?? ""
                        accounts.append(accountInfo)
                    }
                }
            }
            
            self.recommendedAccounts.append(contentsOf: accounts)
            self.onDataUpdated?()
            completion?(accounts, nil)
        } fail: { [weak self] code, desc in
            guard let self = self else { return }
            self.isLoadingMore = false
            TUIOfficialAccountLog.error("Failed to load more recommended accounts: \(code) \(desc ?? "")")
            self.hasMoreRecommended = false
            completion?([], NSError(domain: "TUIOfficialAccount", code: Int(code), userInfo: [NSLocalizedDescriptionKey: desc ?? "Unknown error"]))
        }
    }
    
    /// Check if has more recommended accounts to load
    public var canLoadMoreRecommended: Bool {
        return hasMoreRecommended && !isLoadingMore && !isLoading
    }
    
    /// Load all accounts (subscribed + recommended)
    /// - Parameter completion: Completion handler
    public func loadAllAccounts(completion: (() -> Void)? = nil) {
        // Load subscribed accounts first, then last messages, then recommended
        loadSubscribedAccounts { [weak self] _, _ in
            self?.loadLastMessages { [weak self] in
                self?.loadRecommendedAccounts { _, _ in
                    completion?()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Created accounts (subscribed accounts owned by current user)
    public var createdAccounts: [TUIOfficialAccountInfo] {
        return subscribedAccounts.filter { $0.isOwner }
    }
    
    /// Followed accounts (subscribed accounts not owned by current user)
    public var followedAccounts: [TUIOfficialAccountInfo] {
        return subscribedAccounts.filter { !$0.isOwner }
    }
    
    /// Get last message for account
    /// - Parameter accountID: Account ID
    /// - Returns: Last message string if available
    public func getLastMessage(for accountID: String) -> String? {
        return lastMessagesCache[accountID]
    }
    
    // MARK: - Last Messages Loading
    
    /// Load last messages for subscribed accounts
    /// - Parameter completion: Completion handler
    public func loadLastMessages(completion: (() -> Void)? = nil) {
        let accountIDs = subscribedAccounts.map { $0.accountID }
        guard !accountIDs.isEmpty else {
            completion?()
            return
        }
        
        let conversationIDs = accountIDs.map { "c2c_\($0)" }
        
        V2TIMManager.sharedInstance()?.getConversationList(conversationIDList: conversationIDs, succ: { [weak self] conversationList in
            guard let self = self else { return }
            
            if let conversations = conversationList {
                for conversation in conversations {
                    guard let conversationID = conversation.conversationID,
                          conversationID.hasPrefix("c2c_") else { continue }
                    
                    let accountID = String(conversationID.dropFirst(4))
                    if let lastMessage = conversation.lastMessage {
                        let displayString = self.getMessageDisplayString(lastMessage)
                        self.lastMessagesCache[accountID] = displayString
                    }
                }
            }
            
            self.onDataUpdated?()
            completion?()
        }, fail: { [weak self] _, _ in
            self?.onDataUpdated?()
            completion?()
        })
    }
    
    /// Get display string for message using TUIMessageDataProvider
    private func getMessageDisplayString(_ message: V2TIMMessage) -> String {
        // Use TUIMessageDataProvider to parse message display string (including custom messages)
        if let displayString = TUIMessageDataProvider.getDisplayString(message: message), !displayString.isEmpty {
            return displayString
        }
        return ""
    }
    
    // MARK: - Account Operations
    
    /// Get account info by ID
    /// - Parameters:
    ///   - accountID: Account ID
    ///   - completion: Completion handler with account info
    public func getAccountInfo(
        accountID: String,
        completion: @escaping (TUIOfficialAccountInfo?, Error?) -> Void
    ) {
        V2TIMManager.sharedInstance().getOfficialAccountsInfo(officialAccountIDList: [accountID]) { [weak self] resultList in
            guard let self = self else { return }
            
            if let result = resultList?.first,
               result.resultCode == 0,
               let info = result.officialAccountInfo {
                let accountInfo = TUIOfficialAccountInfo()
                accountInfo.accountID = info.officialAccountID ?? ""
                accountInfo.accountName = info.officialAccountName ?? ""
                accountInfo.faceURL = info.faceUrl ?? ""
                accountInfo.accountDescription = info.introduction ?? ""
                accountInfo.subscriberCount = UInt(info.subscriberCount)
                accountInfo.ownerUserID = info.ownerUserID ?? ""
                accountInfo.isOwner = (info.ownerUserID == self.currentUserID)
                // Check if already subscribed using subscribeTime from SDK
                // subscribeTime > 0 means the user has subscribed to this account
                if info.subscribeTime > 0 {
                    accountInfo.followStatus = .followed
                } else {
                    accountInfo.followStatus = .notFollowed
                }
                completion(accountInfo, nil)
            } else {
                completion(nil, nil)
            }
        } fail: { code, desc in
            let errorMsg = desc ?? "Failed to get account info"
            completion(nil, NSError(domain: "TUIOfficialAccount", code: Int(code), userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        }
    }
    
    /// Follow an official account
    /// - Parameters:
    ///   - accountID: Account ID to follow
    ///   - completion: Completion handler with success status
    public func followAccount(
        accountID: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        V2TIMManager.sharedInstance().subscribeOfficialAccount(officialAccountID: accountID) { [weak self] in
            guard let self = self else { return }
            
            // Update local state
            if let index = self.recommendedAccounts.firstIndex(where: { $0.accountID == accountID }) {
                let account = self.recommendedAccounts[index]
                account.followStatus = .followed
                self.subscribedAccounts.append(account)
                self.recommendedAccounts.remove(at: index)
            }
            
            // Post notification
            NotificationCenter.default.post(
                name: TUIOfficialAccountFollowChangedNotification,
                object: nil,
                userInfo: [
                    "accountID": accountID,
                    "isFollowed": true
                ]
            )
            
            self.onDataUpdated?()
            completion(true, nil)
        } fail: { [weak self] code, desc in
            let errorMsg = desc ?? "Failed to follow account"
            self?.onError?(errorMsg)
            completion(false, NSError(domain: "TUIOfficialAccount", code: Int(code), userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        }
    }
    
    /// Unfollow an official account
    /// - Parameters:
    ///   - accountID: Account ID to unfollow
    ///   - completion: Completion handler with success status
    public func unfollowAccount(
        accountID: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        V2TIMManager.sharedInstance().unsubscribeOfficialAccount(officialAccountID: accountID) { [weak self] in
            guard let self = self else { return }
            
            // Update local state
            if let index = self.subscribedAccounts.firstIndex(where: { $0.accountID == accountID }) {
                let account = self.subscribedAccounts[index]
                account.followStatus = .notFollowed
                self.recommendedAccounts.insert(account, at: 0)
                self.subscribedAccounts.remove(at: index)
            }
            
            // Post notification
            NotificationCenter.default.post(
                name: TUIOfficialAccountFollowChangedNotification,
                object: nil,
                userInfo: [
                    "accountID": accountID,
                    "isFollowed": false
                ]
            )
            
            self.onDataUpdated?()
            completion(true, nil)
        } fail: { [weak self] code, desc in
            let errorMsg = desc ?? "Failed to unfollow account"
            self?.onError?(errorMsg)
            completion(false, NSError(domain: "TUIOfficialAccount", code: Int(code), userInfo: [NSLocalizedDescriptionKey: errorMsg]))
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleFollowChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let accountID = userInfo["accountID"] as? String,
              let isFollowed = userInfo["isFollowed"] as? Bool else {
            return
        }
        
        // Update local cache
        if isFollowed {
            if let index = recommendedAccounts.firstIndex(where: { $0.accountID == accountID }) {
                let account = recommendedAccounts[index]
                account.followStatus = .followed
                subscribedAccounts.append(account)
                recommendedAccounts.remove(at: index)
            }
        } else {
            if let index = subscribedAccounts.firstIndex(where: { $0.accountID == accountID }) {
                let account = subscribedAccounts[index]
                account.followStatus = .notFollowed
                recommendedAccounts.insert(account, at: 0)
                subscribedAccounts.remove(at: index)
            }
        }
        
        onDataUpdated?()
    }
}
