//  TUIContactSelectViewDataProvider_Minimalist.swift
//  TUIContact

import Foundation
import ImSDK_Plus

typealias ContactSelectFilterBlock_Minimalist = (TUICommonContactSelectCellData_Minimalist) -> Bool

/**
 * 【Module name】Friend selection interface view model (TContactSelectViewModel)
 * 【Function description】Implement the friend selection interface view model.
 *  This view model is responsible for pulling friend lists, friend requests and loading related data from the server.
 *  At the same time, this view model will also group friends according to the initials of their nicknames, which helps the view maintain an "alphabet" on the
 * right side of the interface to quickly retrieve friends.
 */
class TUIContactSelectViewDataProvider_Minimalist: NSObject {
    /**
     *  Data dictionary, responsible for classifying friend information (TCommonContactCellData) by initials.
     *  For example, Jack and James are stored in "J".
     */
    private(set) var dataDict: [String: [TUICommonContactSelectCellData_Minimalist]] = [:]

    /**
     *  The group list, that is, the group information of the current friend.
     *  For example, if the current user has only one friend "Jack", there is only one element "J" in this list.
     *  The grouping information is up to 26 letters from A - Z and "#".
     */
    @objc dynamic var groupList: [String] = []

    /**
     *  An identifier indicating whether the current loading process is complete
     *  YES: Loading is done; NO: Loading
     *  With this identifier, we can avoid reloading the data.
     */
    @objc dynamic var isLoadFinished: Bool = false

    /**
     *
     * Filter to disable contacts
     */
    var disableFilter: ContactSelectFilterBlock_Minimalist?

    /**
     *
     * Filter to display contacts
     */
    var avaliableFilter: ContactSelectFilterBlock_Minimalist?

    func loadContacts() {
        isLoadFinished = false

        V2TIMManager.sharedInstance().getFriendList { [weak self] infoList in
            guard let self = self, let infoList = infoList else { return }
            var arr: [V2TIMUserFullInfo] = []
            for friend in infoList {
                // Filter AI friends (userID containing "@RBT#")
                if friend.userID?.contains("@RBT#") == true {
                    continue
                }
                arr.append(friend.userFullInfo)
            }
            self.fillList(profiles: arr, displayNames: nil)
        } fail: { _, _ in
            // Handle error
        }
    }

    func setSourceIds(_ ids: [String]) {
        setSourceIds(ids, displayNames: nil)
    }

    func setSourceIds(_ ids: [String], displayNames: [String: String]?) {
        V2TIMManager.sharedInstance().getUsersInfo(ids) { [weak self] infoList in
            guard let self = self, let infoList = infoList else { return }
            self.fillList(profiles: infoList, displayNames: displayNames)
        } fail: { _, _ in
            // Handle error
        }
    }

    private func fillList(profiles: [V2TIMUserFullInfo], displayNames: [String: String]?) {
        var dataDict: [String: [TUICommonContactSelectCellData_Minimalist]] = [:]
        var groupList: [String] = []
        var nonameList: [TUICommonContactSelectCellData_Minimalist] = []

        for profile in profiles {
            let data = TUICommonContactSelectCellData_Minimalist()
            if let userID = profile.userID {
                let showName = displayNames?[userID] ?? profile.showName()
                data.title = showName
                data.identifier = userID
            }

            if let faceURL = profile.faceURL, !faceURL.isEmpty {
                data.avatarUrl = URL(string: faceURL)!
            }

            if let avaliableFilter = avaliableFilter, !avaliableFilter(data) {
                continue
            }
            if let disableFilter = disableFilter {
                data.isEnabled = !disableFilter(data)
            }

            let group = data.title.firstPinYin().uppercased()
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
            sortedList?.sort { $0.title < $1.title }
            dataDict[key] = sortedList
        }
        self.groupList = groupList
        self.dataDict = dataDict
        isLoadFinished = true
    }
}
