//  TUIContactViewDataProvider_Minimalist.swift
//  TUIContact

import Foundation
import TIMCommon

/**
 * 【Module name】Message List View Model (TContactViewModel)
 * 【Function description】A view model that implements a message list.
 *  1. This view model is responsible for pulling friend lists, friend requests and loading related data from the server.
 *  2. At the same time, this view model will also group friends by the first latter of their nicknames, which helps the view maintain an "alphabet" on the
 * right side of the interface to facilitate quick retrieval of friends.
 */
class TUIContactViewDataProvider_Minimalist: NSObject {
    /**
     *  Data dictionary, responsible for classifying friend information (TCommonContactCellData) by initials.
     *  For example, Jack and James are stored in "J".
     */
    private(set) var dataDict: [String: [TUICommonContactCellData_Minimalist]] = [:]

    /**
     *  The group list, that is, the group information of the current friend.
     *  For example, if the current user has only one friend "Jack", there is only one element "J" in this list.
     *  The grouping information is up to 26 letters from A - Z and "#".
     */
    private(set) var groupList: [String] = []

    /**
     *  An identifier indicating whether the current loading process is complete
     *  YES: Loading is done; NO: Loading
     *  With this identifier, we can avoid reloading the data.
     */
    @objc dynamic var isLoadFinished: Bool = false

    /**
     *  Count of pending friend requests
     */
    @objc dynamic var pendencyCnt: UInt = 0

    public var contactMap: [String: TUICommonContactCellData_Minimalist] = [:]

    override init() {
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
            guard let self = self, let infoList = infoList else { return }
            var dataDict: [String: [TUICommonContactCellData_Minimalist]] = [:]
            var groupList: [String] = []
            var nonameList: [TUICommonContactCellData_Minimalist] = []

            var contactMap: [String: TUICommonContactCellData_Minimalist] = [:]
            var userIDList: [String] = []

            for friend in infoList {
                let data = TUICommonContactCellData_Minimalist(friend: friend)
                // for online status
                data.onlineStatus = .unknown
                let identifier = data.identifier
                if !identifier.isEmpty {
                    contactMap[identifier] = data
                    userIDList.append(identifier)
                }

                let group = data.title?.firstPinYin().uppercased() ?? ""
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

            groupList.sort()
            if !nonameList.isEmpty {
                groupList.append("#")
                dataDict["#"] = nonameList
            }
            for key in dataDict.keys {
                var sortedList = dataDict[key]
                sortedList?.sort { ($0.title ?? "") < ($1.title ?? "") }
                dataDict[key] = sortedList
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

    func loadFriendApplication() {
        V2TIMManager.sharedInstance().getFriendApplicationList { [weak self] result in
            guard let self = self, let result = result else { return }
            self.pendencyCnt = UInt(result.unreadCount)
        } fail: { _, _ in }
    }

    func asyncGetOnlineStatus(_ userIDList: [String]) {
        if Thread.isMainThread {
            DispatchQueue.global().async {
                self.asyncGetOnlineStatus(userIDList)
            }
            return
        }

        if userIDList.isEmpty {
            return
        }

        let getUserStatus: ([String]) -> Void = { [weak self] userIDList in
            guard let self = self else { return }
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
            let identifier = contact.identifier
            if !identifier.isEmpty {
                userIDList.append(identifier)
            }
        }

        // refresh table view on the main thread
        DispatchQueue.main.async {
            self.isLoadFinished = true

            // fetch
            self.asyncGetOnlineStatus(userIDList)
        }
    }

    func handleOnlineStatus(_ userStatusList: [V2TIMUserStatus]) {
        var changed = 0
        for userStatus in userStatusList {
            if let userID = userStatus.userID, let contact = contactMap[userID] {
                changed += 1
                contact.onlineStatus = (userStatus.statusType == .USER_STATUS_ONLINE) ? TUIContactOnlineStatus_Minimalist.online : TUIContactOnlineStatus_Minimalist.offline
            }
        }
        if changed == 0 {
            return
        }

        // refresh table view on the main thread
        DispatchQueue.main.async {
            self.isLoadFinished = true
        }
    }

    func clearApplicationCnt() {
        V2TIMManager.sharedInstance().setFriendApplicationRead { [weak self] in
            guard let self = self else { return }
            self.pendencyCnt = 0
        } fail: { _, _ in }
    }
}

extension TUIContactViewDataProvider_Minimalist: V2TIMSDKListener {
    func onUserStatusChanged(userStatusList: [V2TIMUserStatus]) {
        handleOnlineStatus(userStatusList)
    }

    func onConnectFailed(_ code: Int32, err: String?) {
        print("onConnectFailed, code: \(code), err: \(err ?? "")")
    }

    func onConnectSuccess() {
        asyncUpdateOnlineStatus()
    }
}

extension TUIContactViewDataProvider_Minimalist: V2TIMFriendshipListener {
    func onFriendApplicationListAdded(applicationList: [V2TIMFriendApplication]) {
        loadFriendApplication()
    }

    func onFriendApplicationListDeleted(userIDList: [Any]!) {
        loadFriendApplication()
    }

    func onFriendApplicationListRead() {
        loadFriendApplication()
    }

    func onFriendListAdded(infoList: [V2TIMFriendInfo]) {
        loadContacts()
    }

    func onFriendListDeleted(userIDList: [Any]!) {
        loadContacts()
    }

    func onFriendProfileChanged(infoList: [V2TIMFriendInfo]) {
        loadContacts()
    }
}
