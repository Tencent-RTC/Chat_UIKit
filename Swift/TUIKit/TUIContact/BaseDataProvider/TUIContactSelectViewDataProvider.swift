import Foundation
import TIMCommon
import TUICore

class TUIContactSelectViewDataProvider: NSObject {
    // Data dictionary, responsible for categorizing friend information by the first letter
    private(set) var dataDict: [String: [TUICommonContactSelectCellData]] = [:]
    
    // Group list, i.e., the current group information of friends
    @objc private(set) dynamic var groupList: [String] = []
    
    // Indicates whether the current loading process is finished
    @objc private(set) dynamic var isLoadFinished: Bool = false
    
    // Disable contact filter
    var disableFilter: ((TUICommonContactSelectCellData) -> Bool)?
    
    // Available contact filter
    var avaliableFilter: ((TUICommonContactSelectCellData) -> Bool)?
    
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
            // Handle error if needed
        }
    }
    
    func setSourceIds(_ ids: [String]) {
        setSourceIds(ids, displayNames: nil)
    }
    
    func setSourceIds(_ ids: [String], displayNames: [String: String]?) {
        V2TIMManager.sharedInstance().getUsersInfo(ids) { [weak self] infoList in
            guard let self, let infoList = infoList else { return }
            self.fillList(profiles: infoList, displayNames: displayNames)
        } fail: { _, _ in
            // Handle error if needed
        }
    }
    
    private func fillList(profiles: [V2TIMUserFullInfo], displayNames: [String: String]?) {
        var dataDict: [String: [TUICommonContactSelectCellData]] = [:]
        var groupList: [String] = []
        var nonameList: [TUICommonContactSelectCellData] = []
        
        for profile in profiles {
            let data = TUICommonContactSelectCellData()
            var showName = ""
            if let displayNames = displayNames, let userID = profile.userID, let name = displayNames[userID] {
                showName = name
            }
            if showName.isEmpty {
                showName = profile.showName()
            }
            data.title = showName
            if let faceURL = profile.faceURL, !faceURL.isEmpty {
                data.avatarUrl = URL(string: faceURL) ?? URL(fileURLWithPath: "")
            }
            if let userID = profile.userID {
                data.identifier = userID
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
        for var list in dataDict.values {
            list.sort { $0.title < $1.title }
        }
        
        self.groupList = groupList
        self.dataDict = dataDict
        isLoadFinished = true
    }
}
