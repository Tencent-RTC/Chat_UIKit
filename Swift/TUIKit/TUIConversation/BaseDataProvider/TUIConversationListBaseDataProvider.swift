import Foundation
import ImSDK_Plus
import TIMCommon
import TUICore

public protocol TUIConversationListDataProviderDelegate: AnyObject {
    func getConversationDisplayString(_ conversation: V2TIMConversation) -> String?
    func insertConversations(at indexPaths: [IndexPath])
    func reloadConversations(at indexPaths: [IndexPath])
    func deleteConversation(at indexPaths: [IndexPath])
    func reloadAllConversations()
    func updateMarkUnreadCount(_ markUnreadCount: Int, markHideUnreadCount: Int)
}

public extension TUIConversationListDataProviderDelegate {
    func getConversationDisplayString(_ conversation: V2TIMConversation) -> String? { return "" }
    func insertConversations(at indexPaths: [IndexPath]) {}
    func reloadConversations(at indexPaths: [IndexPath]) {}
    func deleteConversation(at indexPaths: [IndexPath]) {}
    func reloadAllConversations() {}
    func updateMarkUnreadCount(_ markUnreadCount: Int, markHideUnreadCount: Int) {}
}

let kPageSize: UInt32 = 100
public let gGroup_conversationFoldListMockID: String = "group_conversationFoldListMockID"

open class TUIConversationListBaseDataProvider: NSObject, V2TIMConversationListener, V2TIMGroupListener, V2TIMSDKListener, V2TIMAdvancedMsgListener, TUINotificationProtocol {
    public var filter: V2TIMConversationListFilter?
    public var pageSize: UInt32 = kPageSize
    var pageIndex: UInt64 = 0
    var isLastPage: Bool = false
    public weak var delegate: TUIConversationListDataProviderDelegate?
    public var conversationList: [TUIConversationCellData] = []
    private var lastMessageDisplayMap: [String: String] = [:]
    private var deletingConversationList: [String] = []

    lazy var conversationFoldListData: TUIConversationCellData = {
        var conversationFoldListData = TUIConversationCellData()
        if let cls = getConversationCellClass() as? TUIConversationCellData.Type {
            conversationFoldListData = cls.init()
            conversationFoldListData.conversationID = gGroup_conversationFoldListMockID
            conversationFoldListData.title = TUISwift.timCommonLocalizableString("TUIKitConversationMarkFoldGroups")
            conversationFoldListData.avatarImage = TUISwift.tuiCoreBundleThemeImage("", defaultImage: "default_fold_group")
            conversationFoldListData.isNotDisturb = true
        }
        return conversationFoldListData
    }()

    public lazy var markUnreadMap: [String: TUIConversationCellData] = {
        var markUnreadMap = [String: TUIConversationCellData]()
        return markUnreadMap
    }()

    public lazy var markHideMap: [String: TUIConversationCellData] = {
        var markHideMap = [String: TUIConversationCellData]()
        return markHideMap
    }()

    lazy var markFoldMap: [String: TUIConversationCellData] = {
        var markFoldMap = [String: TUIConversationCellData]()
        return markFoldMap
    }()

    override init() {
        super.init()
        filter = V2TIMConversationListFilter()
        V2TIMManager.sharedInstance().addConversationListener(listener: self)
        V2TIMManager.sharedInstance().addGroupListener(listener: self)
        V2TIMManager.sharedInstance().addIMSDKListener(listener: self)
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: self)
        TUICore.registerEvent("TUICore_TUIConversationNotify", subKey: "TUICore_TUIConversationNotify_RemoveConversationSubKey", object: self)
        NotificationCenter.default.addObserver(self, selector: #selector(onLoginSucc), name: NSNotification.Name("TUILoginSuccessNotification"), object: nil)
    }

    open func loadNexPageConversations() {
        if isLastPage {
            return
        }
        guard let filter = filter else { return }
        V2TIMManager.sharedInstance().getConversationListByFilter(filter: filter, nextSeq: pageIndex, count: pageSize) { [weak self] list, nextSeq, isFinished in
            guard let self = self, let list = list else { return }
            self.pageIndex = nextSeq
            self.isLastPage = isFinished
            self.preprocess(list)
        } fail: { [weak self] code, desc in
            guard let self = self else { return }
            self.isLastPage = true
            print("[TUIConversation] \(#function), code:\(code), desc:\(String(describing: desc))")
        }
    }

    public func addConversationList(_ conversationList: [TUIConversationCellData]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.addConversationList(conversationList)
            }
            return
        }
        handleInsertConversationList(conversationList)
    }

    func removeConversation(_ conversation: TUIConversationCellData) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.removeConversation(conversation)
            }
            return
        }
        handleRemoveConversation(conversation)
    }

    func clearHistoryMessage(_ conversation: TUIConversationCellData) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.clearHistoryMessage(conversation)
            }
            return
        }
        if let groupID = conversation.groupID {
            handleClearGroupHistoryMessage(groupID)
        } else if let userID = conversation.userID {
            handleClearC2CHistoryMessage(userID)
        }
    }

    func pinConversation(_ conversation: TUIConversationCellData, pin: Bool) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.pinConversation(conversation, pin: pin)
            }
            return
        }
        handlePinConversation(conversation, pin: pin)
    }

    func hideConversation(_ conversation: TUIConversationCellData) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.hideConversation(conversation)
            }
            return
        }
        handleHideConversation(conversation)
    }

    open func preprocess(_ v2Convs: [V2TIMConversation]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.preprocess(v2Convs)
            }
            return
        }

        var conversationMap: [String: Int] = [:]
        for item in conversationList {
            if let conversationID = item.conversationID {
                conversationMap[conversationID] = conversationList.firstIndex(of: item)
            }
        }

        var duplicateDataList: [TUIConversationCellData] = []
        var addedDataList: [TUIConversationCellData] = []
        var markHideDataList: [TUIConversationCellData] = []
        var markFoldDataList: [TUIConversationCellData] = []

        for conv in v2Convs {
            if filteConversation(conv) {
                continue
            }

            let cellData = cellDataForConversation(conv)
            if let _ = markHideMap[cellData.conversationID] {
                if !TUIConversationCellData.isMarkedByHideType(conv.markList) {
                    markHideMap.removeValue(forKey: cellData.conversationID!)
                }
            } else {
                if TUIConversationCellData.isMarkedByHideType(conv.markList) {
                    markHideMap[cellData.conversationID] = cellData
                }
            }

            if let _ = markFoldMap[cellData.conversationID] {
                if !TUIConversationCellData.isMarkedByFoldType(conv.markList) {
                    markFoldMap.removeValue(forKey: cellData.conversationID!)
                }
            } else {
                if TUIConversationCellData.isMarkedByFoldType(conv.markList) {
                    markFoldMap[cellData.conversationID] = cellData
                }
            }

            if TUIConversationCellData.isMarkedByHideType(conv.markList) ||
                TUIConversationCellData.isMarkedByFoldType(conv.markList)
            {
                if TUIConversationCellData.isMarkedByHideType(conv.markList) {
                    markHideDataList.append(cellData)
                }
                if TUIConversationCellData.isMarkedByFoldType(conv.markList) {
                    markFoldDataList.append(cellData)
                }
                continue
            }

            if let _ = conversationMap[cellData.conversationID!] {
                duplicateDataList.append(cellData)
            } else {
                addedDataList.append(cellData)
            }
            if let _ = markUnreadMap[cellData.conversationID!] {
                if !TUIConversationCellData.isMarkedByUnReadType(conv.markList) {
                    markUnreadMap.removeValue(forKey: cellData.conversationID)
                }
            } else {
                if TUIConversationCellData.isMarkedByUnReadType(conv.markList) {
                    markUnreadMap[cellData.conversationID] = cellData
                }
            }
        }

        if !markFoldDataList.isEmpty {
            var cellRecent: TUIConversationCellData?
            for cellData in markFoldDataList {
                if !cellData.isMarkAsHide {
                    cellRecent = cellData
                    break
                }
            }
            if let cellRecent = cellRecent, let _ = cellRecent.foldSubTitle {
                if cellRecent.orderKey > conversationFoldListData.orderKey {
                    if conversationFoldListData.orderKey == 0 {
                        if TUIConversationListBaseDataProvider.getConversationFoldListSettings_FoldItemIsUnread() {
                            conversationFoldListData.isMarkAsUnread = true
                        }
                    } else {
                        conversationFoldListData.isMarkAsUnread = true
                        TUIConversationListBaseDataProvider.cacheConversationFoldListSettings_FoldItemIsUnread(true)
                        TUIConversationListBaseDataProvider.cacheConversationFoldListSettings_HideFoldItem(false)
                    }
                }
                conversationFoldListData.subTitle = cellRecent.foldSubTitle
                conversationFoldListData.orderKey = cellRecent.orderKey
            }

            if !TUIConversationListBaseDataProvider.getConversationFoldListSettings_HideFoldItem() {
                if let _ = conversationMap[conversationFoldListData.conversationID] {
                    duplicateDataList.append(conversationFoldListData)
                } else if let conversationGroup = filter?.conversationGroup, conversationGroup.count == 0 {
                    addedDataList.append(conversationFoldListData)
                }
            }
            conversationFoldListData.isLocalConversationFoldList = true
        } else {
            updateFoldGroupNameWhileKickOffOrDismissed()
        }

        if !duplicateDataList.isEmpty {
            sortDataList(&duplicateDataList)
            handleUpdateConversationList(duplicateDataList, positions: conversationMap)
        }

        if !addedDataList.isEmpty {
            sortDataList(&addedDataList)
            handleInsertConversationList(addedDataList)
        }


        updateMardHide(&markHideDataList)

        updateMarkUnreadCount()

        updateMarkFold(&markFoldDataList)

        asnycGetLastMessageDisplay(duplicateDataList, addedDataList: addedDataList)
    }

    private func updateMardHide(_ markHideDataList: inout [TUIConversationCellData]) {
        if !markHideDataList.isEmpty {
            sortDataList(&markHideDataList)
            var pRemoveCellUIList: [TUIConversationCellData] = []
            var pMarkHideDataMap: [String: TUIConversationCellData] = [:]
            for item in markHideDataList {
                if let conversationID = item.conversationID {
                    pRemoveCellUIList.append(item)
                    pMarkHideDataMap[conversationID] = item
                }
            }
            for item in conversationList {
                if let _ = pMarkHideDataMap[item.conversationID] {
                    pRemoveCellUIList.append(item)
                }
            }
            for item in pRemoveCellUIList {
                handleHideConversation(item)
            }
        }
    }

    open func updateMarkUnreadCount() {
        var markUnreadCount = 0
        for (_, obj) in markUnreadMap {
            if !obj.isNotDisturb {
                markUnreadCount += 1
            }
        }

        var markHideUnreadCount = 0
        for (_, obj) in markHideMap {
            if !obj.isNotDisturb {
                if obj.isMarkAsUnread {
                    markHideUnreadCount += 1
                } else {
                    markHideUnreadCount += obj.unreadCount
                }
            }
        }

        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "TUIKitNotification_onConversationMarkUnreadCountChanged"),
                                        object: nil,
                                        userInfo: [
                                            "TUIKitNotification_onConversationMarkUnreadCountChanged_DataProvider": self,
                                            "TUIKitNotification_onConversationMarkUnreadCountChanged_MarkUnreadCount": NSNumber(value: markUnreadCount),
                                            "TUIKitNotification_onConversationMarkUnreadCountChanged_MarkHideUnreadCount": NSNumber(value: markHideUnreadCount),
                                            "TUIKitNotification_onConversationMarkUnreadCountChanged_MarkUnreadMap": markUnreadMap,
                                        ])
    }

    private func updateMarkFold(_ markFoldDataList: inout [TUIConversationCellData]) {
        if !markFoldDataList.isEmpty {
            sortDataList(&markFoldDataList)
            var pRemoveCellUIList: [TUIConversationCellData] = []
            var pMarkFoldDataMap: [String: TUIConversationCellData] = [:]
            for item in markFoldDataList {
                if let conversationID = item.conversationID {
                    pRemoveCellUIList.append(item)
                    pMarkFoldDataMap[conversationID] = item
                }
            }
            for item in conversationList {
                if let _ = pMarkFoldDataMap[item.conversationID] {
                    pRemoveCellUIList.append(item)
                }
            }
            // If a collapsed session appears in the home page List, it needs to be hidden. Note that the history cannot be deleted.
            for item in pRemoveCellUIList {
                handleHideConversation(item)
            }
        }
    }

    func asnycGetLastMessageDisplay(_ duplicateDataList: [TUIConversationCellData], addedDataList: [TUIConversationCellData]) {
        // Implement this method
    }

    open func handleInsertConversationList(_ conversationList: [TUIConversationCellData]) {
        self.conversationList.append(contentsOf: conversationList)
        sortDataList(&self.conversationList)
        var indexPaths: [IndexPath] = []
        for item in conversationList {
            if let index = self.conversationList.firstIndex(of: item) {
                indexPaths.append(IndexPath(row: index, section: 0))
            }
        }
        delegate?.insertConversations(at: indexPaths)
        updateOnlineStatus(conversationList)
    }

    open func handleUpdateConversationList(_ conversationList: [TUIConversationCellData], positions: [String: Int]) {
        if conversationList.isEmpty {
            return
        }

        for item in conversationList {
            if item.isLocalConversationFoldList {
                continue
            }
            if let position = positions[item.conversationID], position < self.conversationList.count {
                let cellData = self.conversationList[position]
                item.onlineStatus = cellData.onlineStatus
                self.conversationList[position] = item
            }
        }

        sortDataList(&self.conversationList)

        var minIndex = self.conversationList.count - 1
        var maxIndex = 0

        var conversationMap: [String: TUIConversationCellData] = [:]
        for item in self.conversationList {
            if let conversationID = item.conversationID {
                conversationMap[conversationID] = item
            }
        }

        for cellData in conversationList {
            if let item = conversationMap[cellData.conversationID] {
                if let previous = positions[item.conversationID], let current = self.conversationList.firstIndex(of: item) {
                    minIndex = minIndex < min(previous, current) ? minIndex : min(previous, current)
                    maxIndex = maxIndex > max(previous, current) ? maxIndex : max(previous, current)
                }
            }
        }

        if minIndex > maxIndex {
            return
        }

        var indexPaths: [IndexPath] = []
        for index in minIndex ... maxIndex {
            indexPaths.append(IndexPath(row: index, section: 0))
        }
        delegate?.reloadConversations(at: indexPaths)
    }

    private func handleRemoveConversation(_ conversation: TUIConversationCellData) {
        if let index = conversationList.firstIndex(of: conversation) {
            conversationList.remove(at: index)
            delegate?.deleteConversation(at: [IndexPath(row: index, section: 0)])

            deletingConversationList.append(conversation.conversationID)
            V2TIMManager.sharedInstance().deleteConversation(conversation: conversation.conversationID) { [weak self] in
                guard let self = self else { return }
                self.deletingConversationList.removeAll(where: { $0 == conversation.conversationID })
                if let _ = markUnreadMap[conversation.conversationID!] {
                    self.markUnreadMap.removeValue(forKey: conversation.conversationID!)
                }
                self.updateMarkUnreadCount()
            } fail: { [weak self] code, desc in
                guard let self = self else { return }
                print("deleteConversation failed, conversationID:\(String(describing: conversation.conversationID)) code:\(code) desc:\(String(describing: desc))")
                self.deletingConversationList.removeAll(where: { $0 == conversation.conversationID })
            }
        }
    }

    func handleHideConversation(_ conversation: TUIConversationCellData) {
        if let index = conversationList.firstIndex(of: conversation) {
            conversationList.remove(at: index)
            delegate?.deleteConversation(at: [IndexPath(row: index, section: 0)])
        }
    }

    public func sortDataList(_ dataList: inout [TUIConversationCellData]) {
        dataList.sort { $0.orderKey > $1.orderKey }
    }

    private func cellDataOfGroupID(_ groupID: String) -> TUIConversationCellData? {
        var cellData: TUIConversationCellData? = nil
        let conversationID = "group_\(groupID)"
        for item in conversationList {
            if item.conversationID == conversationID {
                cellData = item
                break
            }
        }
        return cellData
    }

    private func dealFoldcellDataOfGroupID(_ groupID: String) {
        let conversationID = "group_\(groupID)"
        if let cellData = markFoldMap[conversationID] {
            V2TIMManager.sharedInstance().deleteConversation(conversation: cellData.conversationID) { [weak self] in
                guard let self = self else { return }
                self.markFoldMap.removeValue(forKey: conversationID)
                self.updateFoldGroupNameWhileKickOffOrDismissed()
            } fail: { _, _ in
                // to do
            }
        }
    }

    private func updateFoldGroupNameWhileKickOffOrDismissed() {
        var cellRecent: TUIConversationCellData?
        for (_, obj) in markFoldMap {
            if !obj.isMarkAsHide {
                if cellRecent == nil {
                    cellRecent = obj
                } else if obj.orderKey > cellRecent!.orderKey {
                    cellRecent = obj
                }
            }
        }

        if let cellRecent = cellRecent {
            if let foldSubTitle = cellRecent.foldSubTitle {
                conversationFoldListData.subTitle = foldSubTitle
            }
            var conversationMap: [String: Int] = [:]
            for item in conversationList {
                if let conversationID = item.conversationID {
                    conversationMap[conversationID] = conversationList.firstIndex(of: item)
                }
            }
            let conversationFoldListDataList = [conversationFoldListData]
            handleUpdateConversationList(conversationFoldListDataList, positions: conversationMap)
        } else {
            hideConversation(conversationFoldListData)
        }
    }

    public func onNotifyEvent(_ key: String, subKey: String, object anObject: Any?, param: [AnyHashable: Any]?) {
        if key == "TUICore_TUIConversationNotify", subKey == "TUICore_TUIConversationNotify_RemoveConversationSubKey" {
            if let param = param, let conversationID = param["TUICore_TUIConversationNotify_RemoveConversationSubKey_ConversationID"] as? String {
                if let removeConversation = conversationList.first(where: { $0.conversationID == conversationID }) {
                    self.removeConversation(removeConversation)
                } else {
                    V2TIMManager.sharedInstance().deleteConversation(conversation: conversationID) { [weak self] in
                        guard let self = self else { return }
                        self.updateMarkUnreadCount()
                    } fail: { _, _ in
                        // to do
                    }
                }
            }
        }
    }

    private func updateOnlineStatus(_ conversationList: [TUIConversationCellData]) {
        if conversationList.isEmpty {
            return
        }
        if !TUILogin.isUserLogined() {
            return
        }

        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.updateOnlineStatus(conversationList)
            }
            return
        }

        var userIDList: [String] = []
        var positionMap: [String: Int] = [:]
        for item in conversationList {
            if item.onlineStatus == .online {
                item.onlineStatus = .offline
            }
            if let userID = item.userID {
                userIDList.append(userID)
            }
            if let conversationID = item.conversationID {
                positionMap[conversationID] = self.conversationList.firstIndex(of: item)
            }
        }
        handleUpdateConversationList(conversationList, positions: positionMap)

        asyncGetOnlineStatus(userIDList)
    }

    public func asyncGetOnlineStatus(_ userIDList: [String]) {
        if userIDList.isEmpty {
            return
        }
        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async {
                self.asyncGetOnlineStatus(userIDList)
            }
            return
        }
        // get
        DispatchQueue.global(qos: .userInitiated).async {
            V2TIMManager.sharedInstance().getUserStatus(userIDList: userIDList) { [weak self] result in
                guard let self = self, let result = result else { return }
                self.handleOnlineStatus(result)
            } fail: { code, desc in
#if DEBUG
                if code == ERR_SDK_INTERFACE_NOT_SUPPORT.rawValue, TUIConfig.default().displayOnlineStatusIcon {
                    TUITool.makeToast(desc)
                }
#endif
            }
            // subscribe for the users who was deleted from friend list
            V2TIMManager.sharedInstance().subscribeUserStatus(userIDList: userIDList) {
                // to do
            } fail: { _, _ in
                // to do
            }
        }
    }

    public func handleOnlineStatus(_ userStatusList: [V2TIMUserStatus]) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.handleOnlineStatus(userStatusList)
            }
            return
        }
        var positonMap = [String: Int]()
        for item in conversationList {
            if let conversationID = item.conversationID, let _ = item.userID {
                positonMap[conversationID] = conversationList.firstIndex(of: item)
            }
        }
        var changedConversation = [TUIConversationCellData]()
        for item in userStatusList {
            let conversationID = "c2c_\(item.userID ?? "")"
            if let position = positonMap[conversationID] {
                let conversation = conversationList[position]
                if conversation.conversationID == conversationID {
                    switch item.statusType {
                    case V2TIMUserStatusType.USER_STATUS_ONLINE:
                        conversation.onlineStatus = .online
                    case .USER_STATUS_OFFLINE, .USER_STATUS_UNLOGINED:
                        conversation.onlineStatus = .offline
                    default:
                        conversation.onlineStatus = .unknown
                    }
                    changedConversation.append(conversation)
                }
            }
        }
        if !changedConversation.isEmpty {
            handleUpdateConversationList(changedConversation, positions: positonMap)
        }
    }

    // MARK: - V2TIMConversationListener

    public func onNewConversation(conversationList: [V2TIMConversation]) {
        preprocess(conversationList)
    }

    public func onConversationChanged(conversationList: [V2TIMConversation]) {
        preprocess(conversationList)
    }

    public func onConversationDeleted(conversationIDList: [String]) {
        let cacheConversationList = conversationList
        for item in cacheConversationList {
            if conversationIDList.contains(item.conversationID!) {
                if let index = conversationList.firstIndex(of: item) {
                    conversationList.remove(at: index)
                    delegate?.deleteConversation(at: [IndexPath(row: index, section: 0)])
                    if let _ = markUnreadMap[item.conversationID!] {
                        markUnreadMap.removeValue(forKey: item.conversationID!)
                    }
                    updateMarkUnreadCount()
                }
            }
        }
    }

    // MARK: - V2TIMGroupListener

    public func getGroupName(_ cellData: TUIConversationCellData) -> String {
        _ = cellData.groupID
        if let title = cellData.title {
            return title
        } else if let groupID = cellData.groupID {
            return groupID
        }
        return ""
    }

    public func onGroupDismissed(groupID: String?, opUser: V2TIMGroupMemberInfo) {
        if let groupID = groupID {
            if let data = cellDataOfGroupID(groupID) {
                let groupName = getGroupName(data)
                TUITool.makeToast(String(format: TUISwift.timCommonLocalizableString("TUIKitGroupDismssTipsFormat"), groupName))
                handleRemoveConversation(data)
            } else {
                dealFoldcellDataOfGroupID(groupID)
            }
        }
    }

    public func onGroupRecycled(groupID: String?, opUser: V2TIMGroupMemberInfo) {
        if let groupID = groupID {
            if let data = cellDataOfGroupID(groupID) {
                let groupName = getGroupName(data)
                TUITool.makeToast(String(format: TUISwift.timCommonLocalizableString("TUIKitGroupRecycledTipsFormat"), groupName))
                handleRemoveConversation(data)
            } else {
                dealFoldcellDataOfGroupID(groupID)
            }
        }
    }

    public func onMemberKicked(groupID: String?, opUser: V2TIMGroupMemberInfo, memberList: [V2TIMGroupMemberInfo]) {
        let kicked = memberList.contains { $0.userID == TUILogin.getUserID() }
        if !kicked {
            return
        }
        if let groupID = groupID {
            if let data = cellDataOfGroupID(groupID) {
                let groupName = getGroupName(data)
                TUITool.makeToast(String(format: TUISwift.timCommonLocalizableString("TUIKitGroupKickOffTipsFormat"), groupName))
                handleRemoveConversation(data)
            } else {
                dealFoldcellDataOfGroupID(groupID)
            }
        }
    }
    
    public func onQuitFromGroup(groupID: String?) {
        if let groupID = groupID {
            if let data = cellDataOfGroupID(groupID) {
                let groupName = getGroupName(data)
                TUITool.makeToast(String(format: TUISwift.timCommonLocalizableString("TUIKitGroupDropoutTipsFormat"), groupName))
                handleRemoveConversation(data)
            } else {
                dealFoldcellDataOfGroupID(groupID)
            }
        }
    }

    public func onGroupInfoChanged(groupID: String?, changeInfoList: [V2TIMGroupChangeInfo]) {
        if let groupID = groupID, let _ = cellDataOfGroupID(groupID) {
            let conversationID = "group_\(groupID)"
            V2TIMManager.sharedInstance().getConversation(conversationID: conversationID) { [weak self] conv in
                guard let self = self, let conv = conv else { return }
                self.preprocess([conv])
            } fail: { code, desc in
                print("[TUIConversation] \(#function), code:\(code), desc:\(String(describing: desc))")
            }
        }
    }

    // MARK: - V2TIMSDKListener

    public func onUserStatusChanged(userStatusList: [V2TIMUserStatus]) {
        handleOnlineStatus(userStatusList)
    }

    public func onConnectFailed(_ code: Int32, err: String?) {
        print("\(#function)")
    }

    public func onConnectSuccess() {
        print("\(#function)")
        if !conversationList.isEmpty {
            let conversationList = Array(conversationList)
            updateOnlineStatus(conversationList)
        }
    }

    @objc public func onLoginSucc() {
        print("\(#function)")
        if !conversationList.isEmpty {
            let conversationList = Array(conversationList)
            updateOnlineStatus(conversationList)
        }
    }

    // MARK: - V2TIMAdvancedMsgListener

    public func onRecvNewMessage(msg: V2TIMMessage) {
        let userID = msg.userID
        let groupID = msg.groupID
        var conversationID = ""

        if TUIConversationListBaseDataProvider.isTypingBusinessMessage(msg) {
            return
        }

        if let userID = userID {
            conversationID = "c2c_\(userID)"
        }
        if let groupID = groupID {
            conversationID = "group_\(groupID)"
        }

        if let targetCellData = conversationList.first(where: { $0.conversationID == conversationID }) {
            let existInHidelist = targetCellData.isMarkAsHide
            let existInUnreadlist = targetCellData.isMarkAsUnread
            if existInHidelist || existInUnreadlist {
                cancelHideAndUnreadMarkConversation(conversationID, existInHidelist: existInHidelist, existInUnreadlist: existInUnreadlist)
            }
        } else {
            V2TIMManager.sharedInstance().getConversation(conversationID: conversationID) { [weak self] conv in
                guard let self = self, let conv = conv else { return }
                let cellData = self.cellDataForConversation(conv)
                let existInHidelist = cellData.isMarkAsHide
                let existInUnreadlist = cellData.isMarkAsUnread
                if existInHidelist || existInUnreadlist {
                    self.cancelHideAndUnreadMarkConversation(conversationID, existInHidelist: existInHidelist, existInUnreadlist: existInUnreadlist)
                }
            } fail: { code, desc in
                print("[TUIConversation] \(#function), code:\(code), desc:\(String(describing: desc))")
            }
        }
    }

    public func cancelHideAndUnreadMarkConversation(_ conversationID: String, existInHidelist: Bool, existInUnreadlist: Bool) {
        let markHideNumber = NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue)
        let markUnreadNumber = NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_UNREAD.rawValue)
        if existInHidelist && existInUnreadlist {
            V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: markHideNumber, enableMark: false) { _ in
                V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: markUnreadNumber, enableMark: false) { _ in
                    // Handle result if needed
                } fail: { code, desc in
                    print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
                }
            } fail: { code, desc in
                print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
            }
        } else if existInHidelist {
            V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: markHideNumber, enableMark: false) { _ in
                // Handle result if needed
            } fail: { code, desc in
                print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
            }
        } else if existInUnreadlist {
            V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: markUnreadNumber, enableMark: false) { _ in
                // Handle result if needed
            } fail: { code, desc in
                print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
            }
        } else {
            // nothing to do
        }
    }

    // MARK: - SDK Data Process

    public func handleClearGroupHistoryMessage(_ groupID: String) {
        V2TIMManager.sharedInstance().clearGroupHistoryMessage(groupID: groupID) {
            print("[TUIConversation] \(#function) success")
        } fail: { code, desc in
            print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
        }
    }

    public func handleClearC2CHistoryMessage(_ userID: String) {
        V2TIMManager.sharedInstance().clearC2CHistoryMessage(userID: userID) {
            print("[TUIConversation] \(#function) success")
        } fail: { code, desc in
            print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
        }
    }

    public func handlePinConversation(_ conversation: TUIConversationCellData, pin: Bool) {
        DispatchQueue.main.async {
            V2TIMManager.sharedInstance().pinConversation(conversationID: conversation.conversationID, isPinned: pin) {
                print("[TUIConversation] \(#function) success")
            } fail: { code, desc in
                print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
            }
        }
    }

    public func cellDataForConversation(_ conversation: V2TIMConversation) -> TUIConversationCellData {
        if let cls = getConversationCellClass() as? TUIConversationCellData.Type {
            let data = cls.init()
            data.conversationID = conversation.conversationID
            data.groupID = conversation.groupID
            data.groupType = conversation.groupType
            data.userID = conversation.userID
            data.title = conversation.showName
            data.faceUrl = conversation.faceUrl
            data.subTitle = getLastDisplayString(conversation)
            data.foldSubTitle = getLastDisplayStringForFoldList(conversation)
            data.atTipsStr = getGroupAtTipString(conversation)
            data.atMsgSeqs = getGroupatMsgSeqs(conversation)
            data.time = getLastDisplayDate(conversation)
            data.isOnTop = conversation.isPinned
            data.unreadCount = Int(conversation.unreadCount)
            data.draftText = conversation.draftText
            data.isNotDisturb = isConversationNotDisturb(conversation)
            data.orderKey = conversation.orderKey
            data.avatarImage = (conversation.type == .C2C ?
                TUISwift.defaultAvatarImage() : TUISwift.defaultGroupAvatarImage(byGroupType: conversation.groupType))
            data.onlineStatus = .unknown
            data.isMarkAsUnread = TUIConversationCellData.isMarkedByUnReadType(conversation.markList)
            data.isMarkAsHide = TUIConversationCellData.isMarkedByHideType(conversation.markList)
            data.isMarkAsFolded = TUIConversationCellData.isMarkedByFoldType(conversation.markList)
            data.lastMessage = conversation.lastMessage
            data.innerConversation = conversation
            data.conversationGroupList = conversation.conversationGroupList
            data.conversationMarkList = conversation.markList
            return data
        }
        return TUIConversationCellData()
    }

    public func isConversationNotDisturb(_ conversation: V2TIMConversation) -> Bool {
        return (conversation.groupType != "Meeting") && (conversation.recvOpt == .RECEIVE_NOT_NOTIFY_MESSAGE)
    }

    public func getLastDisplayStringForFoldList(_ conversation: V2TIMConversation) -> NSMutableAttributedString {
        let attributeString = NSMutableAttributedString(string: "")
        let attributeDict: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.d_systemRed()]
        attributeString.setAttributes(attributeDict, range: NSRange(location: 0, length: attributeString.length))
        let showName = "\(conversation.showName ?? ""): "
        attributeString.append(NSMutableAttributedString(string: showName))
        var lastMsgStr = ""
        // Attempt to get externally customized display information
        lastMsgStr = (delegate?.getConversationDisplayString(conversation) ?? "")
        // If there is no external customization, get the lastMsg display information through the message module
        if lastMsgStr.isEmpty, let lastMessage = conversation.lastMessage {
            lastMsgStr = getDisplayStringFromService(lastMessage)
        }
        // If there is no lastMsg display information and no draft information, return nil directly
        if lastMsgStr.isEmpty {
            return attributeString
        }
        attributeString.append(NSMutableAttributedString(string: lastMsgStr))
        return attributeString
    }

    public func getLastDisplayString(_ conversation: V2TIMConversation) -> NSMutableAttributedString {
        // subclass overide
        return NSMutableAttributedString(string: "")
    }

    public func getGroupatMsgSeqs(_ conv: V2TIMConversation) -> [NSNumber]? {
        guard let groupAtInfolist = conv.groupAtInfolist else { return nil }
        var seqList = [NSNumber]()
        for atInfo in groupAtInfolist {
            seqList.append(NSNumber(value: atInfo.seq))
        }
        return seqList.count > 0 ? seqList : nil
    }

    public func getLastDisplayDate(_ conv: V2TIMConversation) -> Date? {
        if let draftText = conv.draftText, !draftText.isEmpty {
            return conv.draftTimestamp
        }
        if let lastMessage = conv.lastMessage {
            return lastMessage.timestamp
        }
        return Date.distantPast
    }

    public func getGroupAtTipString(_ conv: V2TIMConversation) -> String {
        guard let groupAtInfolist = conv.groupAtInfolist else { return "" }
        var atTipsStr = ""
        var atMe = false
        var atAll = false
        for atInfo in groupAtInfolist {
            switch atInfo.atType {
            case .AT_ME:
                atMe = true
                continue
            case .AT_ALL:
                atAll = true
                continue
            case .AT_ALL_AT_ME:
                atMe = true
                atAll = true
                continue
            default:
                continue
            }
        }
        if atMe && !atAll {
            atTipsStr = TUISwift.timCommonLocalizableString("TUIKitConversationTipsAtMe")
        }
        if !atMe && atAll {
            atTipsStr = TUISwift.timCommonLocalizableString("TUIKitConversationTipsAtAll")
        }
        if atMe && atAll {
            atTipsStr = TUISwift.timCommonLocalizableString("TUIKitConversationTipsAtMeAndAll")
        }
        return atTipsStr
    }

    public func getDraftContent(_ conv: V2TIMConversation) -> String? {
        guard let draft = conv.draftText else { return "" }
        do {
            let jsonDict = try JSONSerialization.jsonObject(with: draft.data(using: .utf8)!, options: .mutableLeaves) as? [String: Any]
            if let jsonDict = jsonDict, let draftContent = jsonDict["content"] as? String {
                return draftContent
            }
        } catch {
            let nsError = error as NSError
            let code = nsError.code
            let description = nsError.localizedDescription
            print("[TUIConversation] \(#function) code:\(code), desc:\(description)")
        }
        return draft
    }

    public func filteConversation(_ conversation: V2TIMConversation) -> Bool {
        if let conversationID = conversation.conversationID,
           deletingConversationList.contains(conversationID)
        {
            return true
        }
        if (conversation.userID == nil || conversation.userID!.isEmpty) &&
            (conversation.groupID == nil || conversation.groupID!.isEmpty)
        {
            return true
        }
        if conversation.type == .UNKNOWN {
            return true
        }
        if conversation.groupType == "AVChatRoom" {
            return true
        }
        if getLastDisplayDate(conversation) == nil {
            if conversation.unreadCount != 0 {
                V2TIMManager.sharedInstance().cleanConversationUnreadMessageCount(conversationID: conversation.conversationID, cleanTimestamp: 0, cleanSequence: 0) {
                    // Handle result if needed
                } fail: { code, description in
                    print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: description))")
                }
            }
            return true
        }
        return false
    }

    public func markConversationHide(_ data: TUIConversationCellData) {
        handleHideConversation(data)
        guard let conversationID = data.conversationID else { return }
        V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue), enableMark: true) { _ in
            // Handle result if needed
        } fail: { code, desc in
            print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: desc))")
        }
    }

    public func markConversationAsRead(_ conv: TUIConversationCellData) {
        guard let conversationID = conv.conversationID else { return }
        V2TIMManager.sharedInstance().cleanConversationUnreadMessageCount(conversationID: conversationID, cleanTimestamp: 0, cleanSequence: 0) {
            // Handle result if needed
        } fail: { code, description in
            print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: description))")
        }
        V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_UNREAD.rawValue), enableMark: false) { _ in
            // Handle result if needed
        } fail: { code, description in
            print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: description))")
        }
    }

    public func markConversationAsUnRead(_ conv: TUIConversationCellData) {
        guard let conversationID = conv.conversationID else { return }
        V2TIMManager.sharedInstance().markConversation(conversationIDList: [conversationID], markType: NSNumber(value: V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_UNREAD.rawValue), enableMark: true) { _ in
            // Handle result if needed
        } fail: { code, description in
            print("[TUIConversation] \(#function) code:\(code), desc:\(String(describing: description))")
        }
    }

    public class func isTypingBusinessMessage(_ message: V2TIMMessage) -> Bool {
        guard let customElem = message.customElem else { return false }
        guard let data = customElem.data else { return false }
        do {
            let param = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            if let param = param, let businessID = param["businessID"] as? String, businessID == "user_typing_status" {
                return true
            }
            if let src = param!["src"] as? String, src == "12" {
                return true
            }
        } catch {
            let nsError = error as NSError
            let code = nsError.code
            let description = nsError.localizedDescription
            print("[TUIConversation] \(#function) parse customElem data error: \(description)")
        }
        return false
    }

    public class func cacheConversationFoldListSettings_HideFoldItem(_ flag: Bool) {
        if let userID = TUILogin.getUserID() {
            let key = "hide_fold_item_\(userID)"
            UserDefaults.standard.set(flag, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }

    public class func cacheConversationFoldListSettings_FoldItemIsUnread(_ flag: Bool) {
        if let userID = TUILogin.getUserID() {
            let key = "fold_item_is_unread_\(userID)"
            UserDefaults.standard.set(flag, forKey: key)
            UserDefaults.standard.synchronize()
        }
    }

    public class func getConversationFoldListSettings_HideFoldItem() -> Bool {
        if let userID = TUILogin.getUserID() {
            let key = "hide_fold_item_\(userID)"
            return UserDefaults.standard.bool(forKey: key)
        }
        return false
    }

    public class func getConversationFoldListSettings_FoldItemIsUnread() -> Bool {
        if let userID = TUILogin.getUserID() {
            let key = "fold_item_is_unread_\(userID)"
            return UserDefaults.standard.bool(forKey: key)
        }
        return false
    }

    // MARK: Override func

    public func getConversationCellClass() -> AnyClass? {
        // subclass override
        return nil
    }

    public func getDisplayStringFromService(_ msg: V2TIMMessage) -> String {
        // subclass override
        return ""
    }
}

// extension Optional where Wrapped == String {
//    var isNilOrEmpty: Bool {
//        return self?.isEmpty ?? true
//    }
// }
