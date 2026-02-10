import Foundation
import TIMCommon

// 定义宏
let kGetUserStatusPageCount = 500

public class TUIContactViewDataProvider: NSObject, V2TIMFriendshipListener, V2TIMSDKListener {
    // 数据字典，负责按首字母分类好友信息（TCommonContactCellData）
    private(set) var dataDict: [String: [TUICommonContactCellData]] = [:]
    
    // 组列表，即当前好友的组信息
    private(set) var groupList: [String] = []
    
    // 标识当前加载过程是否完成
    @objc private(set) dynamic var isLoadFinished: Bool = false
    
    // 待处理的好友请求数量
    @objc public dynamic var pendencyCnt: UInt64 = 0
    
    public var contactMap: [String: TUICommonContactCellData] = [:]
    
    override public init() {
        super.init()
        V2TIMManager.sharedInstance().addFriendListener(listener: self)
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func loadContacts() {
        isLoadFinished = false
        V2TIMManager.sharedInstance().getFriendList { [weak self] infoList in
            guard let self, let infoList = infoList else { return }
            var dataDict: [String: [TUICommonContactCellData]] = [:]
            var groupList: [String] = []
            var nonameList: [TUICommonContactCellData] = []
            
            var contactMap: [String: TUICommonContactCellData] = [:]
            var userIDList: [String] = []
            
            for friend in infoList {
                let data = TUICommonContactCellData(friend: friend)
                // for online status
                data.onlineStatus = .unknown
                if let identifier = data.identifier {
                    contactMap[identifier] = data
                    userIDList.append(identifier)
                }
                
                if let group = data.title?.firstPinYin().uppercased() {
                    if group.isEmpty || !group.first!.isLetter {
                        nonameList.append(data)
                        continue
                    }
                    var list = dataDict[group] ?? []
                    list.append(data)
                    dataDict[group] = list
                    if !groupList.contains(group) {
                        groupList.append(group)
                    }
                }
            }
            
            groupList.sort { $0.localizedStandardCompare($1) == .orderedAscending }
            if !nonameList.isEmpty {
                groupList.append("#")
                dataDict["#"] = nonameList
            }
            for key in dataDict.keys {
                if var list = dataDict[key] {
                    list.sort { $0.compare(to: $1) == .orderedAscending }
                    dataDict[key] = list
                }
            }
            
            self.groupList = groupList
            self.dataDict = dataDict
            self.contactMap = contactMap
            self.isLoadFinished = true
            
            // refresh online status async
            self.asyncGetOnlineStatus(userIDList)
        } fail: { code, desc in
            print("getFriendList failed, code:\(code) desc:\(desc ?? "")")
        }
        
        loadFriendApplication()
    }
    
    public func loadFriendApplication() {
        V2TIMManager.sharedInstance().getFriendApplicationList { [weak self] result in
            guard let self = self, let result = result else { return }
            self.pendencyCnt = result.unreadCount
        } fail: { _, _ in }
    }
    
    func asyncGetOnlineStatus(_ userIDList: [String]) {
        if Thread.isMainThread {
            weak var weakSelf = self
            DispatchQueue.global().async {
                weakSelf?.asyncGetOnlineStatus(userIDList)
            }
            return
        }
        
        if userIDList.isEmpty {
            return
        }
        
        let getUserStatus: ([String]) -> Void = { [weak self] userIDList in
            V2TIMManager.sharedInstance().getUserStatus(userIDList: userIDList) { [weak self] result in
                guard let self, let result = result else { return }
                self.handleOnlineStatus(result)
            } fail: { code, desc in
                #if DEBUG
                if code == ERR_SDK_INTERFACE_NOT_SUPPORT.rawValue, TUIConfig.default().displayOnlineStatusIcon {
                    TUITool.makeToast(desc)
                }
                #endif
            }
        }
        
        let count = kGetUserStatusPageCount
        if userIDList.count > count {
            let subUserIDList = Array(userIDList.prefix(count))
            let pendingUserIDList = Array(userIDList.dropFirst(count))
            getUserStatus(subUserIDList)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.asyncGetOnlineStatus(pendingUserIDList)
            }
        } else {
            getUserStatus(userIDList)
        }
    }
    
    func asyncUpdateOnlineStatus() {
        if Thread.isMainThread {
            weak var weakSelf = self
            DispatchQueue.global().async {
                weakSelf?.asyncUpdateOnlineStatus()
            }
            return
        }
        
        // reset
        var userIDList: [String] = []
        for contact in contactMap.values {
            contact.onlineStatus = .offline
            if let identifier = contact.identifier {
                userIDList.append(identifier)
            }
        }
        
        // refresh table view on the main thread
        weak var weakSelf = self
        DispatchQueue.main.async {
            weakSelf?.isLoadFinished = true
            
            // fetch
            weakSelf?.asyncGetOnlineStatus(userIDList)
        }
    }
    
    func handleOnlineStatus(_ userStatusList: [V2TIMUserStatus]) {
        var changed = 0
        for userStatus in userStatusList {
            if let userID = userStatus.userID, let contact = contactMap[userID] {
                changed += 1
                contact.onlineStatus = (userStatus.statusType == V2TIMUserStatusType.USER_STATUS_ONLINE) ? TUIContactOnlineStatus.online : TUIContactOnlineStatus.offline
            }
        }
        if changed == 0 {
            return
        }
        
        // refresh table view on the main thread
        weak var weakSelf = self
        DispatchQueue.main.async {
            weakSelf?.isLoadFinished = true
        }
    }
    
    func clearApplicationCnt() {
        weak var weakSelf = self
        V2TIMManager.sharedInstance().setFriendApplicationRead {
            weakSelf?.pendencyCnt = 0
        } fail: { _, _ in }
    }
    
    // MARK: - V2TIMSDKListener

    public func onUserStatusChanged(userStatusList: [V2TIMUserStatus]) {
        handleOnlineStatus(userStatusList)
    }
    
    public func onConnectFailed(_ code: Int32, err: String?) {
        print("onConnectFailed, code: \(code), err: \(err ?? "")")
    }

    public func onConnectSuccess() {
        asyncUpdateOnlineStatus()
    }
    
    // MARK: - V2TIMFriendshipListener

    public func onFriendApplicationListAdded(applicationList: [V2TIMFriendApplication]) {
        loadFriendApplication()
    }
    
    public func onFriendApplicationListDeleted(userIDList: [Any]) {
        loadFriendApplication()
    }
    
    public func onFriendApplicationListRead() {
        loadFriendApplication()
    }
    
    public func onFriendListAdded(infoList: [V2TIMFriendInfo]) {
        loadContacts()
    }
    
    public func onFriendListDeleted(userIDList: [Any]) {
        loadContacts()
    }
    
    public func onFriendProfileChanged(infoList: [V2TIMFriendInfo]) {
        loadContacts()
    }
}
