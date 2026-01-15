import Foundation
import TIMCommon
import TUICore

@objc protocol TUIGroupInfoDataProviderDelegate_Minimalist: NSObjectProtocol {
    @objc func pushNavigationController() -> UINavigationController?
    @objc func didSelectMembers()
    @objc func didSelectGroupNick(_ cell: TUICommonTextCell)
    @objc func didSelectAddOption(_ cell: UITableViewCell)
    @objc func didSelectCommon()
    @objc func didSelectOnNotDisturb(_ cell: TUICommonSwitchCell)
    @objc func didSelectOnTop(_ cell: TUICommonSwitchCell)
    @objc func didSelectOnFoldConversation(_ cell: TUICommonSwitchCell)
    @objc func didSelectOnChangeBackgroundImage(_ cell: TUICommonTextCell)
    @objc func didDeleteGroup(_ cell: TUIButtonCell)
    @objc func didClearAllHistory(_ cell: TUIButtonCell)
    @objc func didSelectGroupNotice()
    @objc func didAddMembers()
    @objc optional func didSelectVoiceSetting(_ cell: TUICommonTextCell)
}

class TUIGroupInfoDataProvider_Minimalist: NSObject, V2TIMGroupListener {
    var addOptionData: TUICommonTextCellData?
    var inviteOptionData: TUICommonTextCellData?
    var groupNickNameCellData: TUICommonTextCellData?
    private(set) var profileCellData: TUIProfileCardCellData?
    private(set) var selfInfo: V2TIMGroupMemberFullInfo?
    private var groupID: String
    var groupInfo: V2TIMGroupInfo?
    var membersData: [TUIGroupMemberCellData_Minimalist] = []
    var groupMembersCellData: TUIGroupMembersCellData?
    @objc dynamic var dataList: [[Any]] = []
    weak var delegate: TUIGroupInfoDataProviderDelegate_Minimalist?
    private var firstLoadData: Bool = false

    init(groupID: String) {
        self.groupID = groupID
        super.init()
        V2TIMManager.sharedInstance().addGroupListener(listener: self)
    }

    // MARK: - V2TIMGroupListener

    func onMemberEnter(groupID: String?, memberList: [V2TIMGroupMemberInfo]) {
        loadData()
    }

    func onMemberLeave(groupID: String?, member: V2TIMGroupMemberInfo) {
        loadData()
    }

    func onMemberInvited(groupID: String?, opUser: V2TIMGroupMemberInfo, memberList: [V2TIMGroupMemberInfo]) {
        loadData()
    }

    func onMemberKicked(groupID: String?, opUser: V2TIMGroupMemberInfo, memberList: [V2TIMGroupMemberInfo]) {
        loadData()
    }

    func onGrantAdministrator(groupID: String?, opUser: V2TIMGroupMemberInfo!, memberList: [V2TIMGroupMemberInfo]!) {
        loadData()
    }
    
    func onRevokeAdministrator(groupID: String?, opUser: V2TIMGroupMemberInfo!, memberList: [V2TIMGroupMemberInfo]!) {
        loadData()
    }
    
    func onGroupInfoChanged(groupID: String?, changeInfoList: [V2TIMGroupChangeInfo]) {
        guard groupID == self.groupID else { return }
        loadData()
    }
    
    func loadData() {
        guard !groupID.isEmpty else {
            TUITool.makeToastError(Int(ERR_INVALID_PARAMETERS.rawValue), msg: "invalid groupID")
            return
        }
        firstLoadData = true
        let group = DispatchGroup()
        
        group.enter()
        getGroupInfo {
            group.leave()
        }
        
        group.enter()
        getGroupMembers {
            group.leave()
        }
        
        group.enter()
        getSelfInfoInGroup {
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.setupData()
        }
    }

    func updateGroupInfo(_ callback: (() -> Void)?) {
        guard !groupID.isEmpty else {
            TUITool.makeToastError(Int(ERR_INVALID_PARAMETERS.rawValue), msg: "invalid groupID")
            return
        }
        
        let group = DispatchGroup()
        
        group.enter()
        getGroupInfo {
            group.leave()
        }
        
        group.enter()
        getGroupMembers {
            group.leave()
        }
        
        group.enter()
        getSelfInfoInGroup {
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.setupData()
            callback?()
        }
    }

    func makeToastError(_ code: Int, msg: String) {
        if !firstLoadData {
            TUITool.makeToastError(code, msg: msg)
        }
    }

    func transferGroupOwner(_ groupID: String, member: String, succ: @escaping V2TIMSucc, fail: @escaping V2TIMFail) {
        V2TIMManager.sharedInstance().transferGroupOwner(groupID: groupID, memberUserID: member, succ: succ, fail: fail)
    }

    func updateGroupAvatar(_ url: String, succ: @escaping V2TIMSucc, fail: @escaping V2TIMFail) {
        let info = V2TIMGroupInfo()
        info.groupID = groupID
        info.faceURL = url
        V2TIMManager.sharedInstance().setGroupInfo(info: info, succ: succ, fail: fail)
    }
    
    private func getGroupInfo(callback: @escaping () -> Void) {
        V2TIMManager.sharedInstance().getGroupsInfo([groupID]) { [weak self] groupResultList in
            guard let self else { return }
            self.groupInfo = groupResultList?.first?.info
            callback()
        } fail: { [weak self] code, msg in
            guard let self else { return }
            callback()
            self.makeToastError(Int(code), msg: msg ?? "")
        }
    }

    private func getGroupMembers(callback: @escaping () -> Void) {
        V2TIMManager.sharedInstance().getGroupMemberList(groupID, filter: UInt32(V2TIMGroupMemberFilter.GROUP_MEMBER_FILTER_ALL.rawValue), nextSeq: 0) { [weak self] _, memberList in
            guard let self, let memberList = memberList else { return }
            var membersData: [TUIGroupMemberCellData_Minimalist] = []
            for fullInfo in memberList {
                let data = TUIGroupMemberCellData_Minimalist()
                data.identifier = fullInfo.userID
                data.name = fullInfo.userID
                data.avatarUrl = fullInfo.faceURL
                data.showAccessory = true
                if let nameCard = fullInfo.nameCard, !nameCard.isEmpty {
                    data.name = nameCard
                } else if let friendRemark = fullInfo.friendRemark, !friendRemark.isEmpty {
                    data.name = friendRemark
                } else if let nickName = fullInfo.nickName, !nickName.isEmpty {
                    data.name = nickName
                }
                if fullInfo.userID == V2TIMManager.sharedInstance().getLoginUser() {
                    self.selfInfo = fullInfo
                    continue
                } else {
                    membersData.append(data)
                }
            }
            self.membersData = membersData
            callback()
        } fail: { [weak self] code, msg in
            guard let self else { return }
            self.membersData = []
            self.makeToastError(Int(code), msg: msg ?? "")
            callback()
        }
    }

    private func getSelfInfoInGroup(callback: @escaping () -> Void) {
        guard let loginUserID = V2TIMManager.sharedInstance().getLoginUser(), !loginUserID.isEmpty else {
            callback()
            return
        }
        V2TIMManager.sharedInstance().getGroupMembersInfo(groupID: groupID, memberList: [loginUserID]) { [weak self] memberList in
            guard let self else { return }
            self.selfInfo = memberList?.first(where: { $0.userID == loginUserID })
            callback()
        } fail: { [weak self] code, msg in
            guard let self else { return }
            self.makeToastError(Int(code), msg: msg ?? "")
            callback()
        }
    }
    
    func createSelfData() -> TUIGroupMemberCellData_Minimalist {
        let data = TUIGroupMemberCellData_Minimalist()
        data.identifier = V2TIMManager.sharedInstance().getLoginUser()
        data.avatarUrl = TUILogin.getFaceUrl() ?? ""

        data.showAccessory = true

        data.name = TUISwift.timCommonLocalizableString("YOU")
        data.showAccessory = false
        guard let groupInfo = groupInfo else { return data }
        if isSuperAdmin() {
            data.detailName = TUISwift.timCommonLocalizableString("TUIKitMembersRoleSuper")
        } else if canManager() {
            data.detailName = TUISwift.timCommonLocalizableString("TUIKitMembersRoleAdmin")
        } else {
            data.detailName = TUISwift.timCommonLocalizableString("TUIKitMembersRoleMember")
        }
        return data
    }

    func setupData() {
        var dataList: [[Any]] = []
        guard let groupInfo = groupInfo else { return }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.muteAndPin) {
            var avatarAndInfoArray: [Any] = []

            // Mute Notifications
            let muteData = TUICommonSwitchCellData()
            if groupInfo.groupType != "Meeting" {
                muteData.isOn = (groupInfo.recvOpt == .RECEIVE_NOT_NOTIFY_MESSAGE)
                muteData.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileMessageDoNotDisturb")
                muteData.cswitchSelector = #selector(didSelectOnNotDisturb(_:))
                avatarAndInfoArray.append(muteData)
            }

            // Minimize
            let minimize = TUICommonSwitchCellData()
            minimize.title = TUISwift.timCommonLocalizableString("TUIKitConversationMarkFold")
            minimize.displaySeparatorLine = true
            minimize.cswitchSelector = #selector(didSelectOnFoldConversation(_:))
            if muteData.isOn {
                avatarAndInfoArray.append(minimize)
            }

            // Pin
            let pinData = TUICommonSwitchCellData()
            pinData.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileStickyOnTop")
            avatarAndInfoArray.append(pinData)
            dataList.append(avatarAndInfoArray)

            V2TIMManager.sharedInstance().getConversation(conversationID: "group_\(groupID)") { [weak self] conv in
                guard let self = self, let conv = conv else { return }
                if let markList = conv.markList {
                    minimize.isOn = Self.isMarkedByFoldType(markList)
                }
                pinData.cswitchSelector = #selector(self.didSelectOnTop(_:))
                pinData.isOn = conv.isPinned
                if minimize.isOn {
                    pinData.isOn = false
                    pinData.disableChecked = true
                }
                self.dataList = dataList
            } fail: { _, _ in
                // Handle failure
            }
        }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.manage) {
            var groupInfoArray: [Any] = []

            // Notice
            let notice = TUIGroupNoticeCellData()
            notice.name = TUISwift.timCommonLocalizableString("TUIKitGroupNotice")
            notice.desc = groupInfo.notification ?? TUISwift.timCommonLocalizableString("TUIKitGroupNoticeNull")
            notice.target = self
            notice.selector = #selector(didSelectNotice)
            groupInfoArray.append(notice)

            // Manage
            var param: [String: Any] = [
                "pushVC": delegate?.pushNavigationController() as Any,
                "groupID": groupID
            ]
            let extensionList = TUICore.getExtensionList("TUICore_TUIChatExtension_GroupProfileSettingsItemExtension_MinimalistExtensionID", param: param)
            for info in extensionList {
                if let text = info.text, let onClicked = info.onClicked {
                    let manageData = TUICommonTextCellData()
                    manageData.key = text
                    manageData.value = ""
                    manageData.tui_extValueObj = info
                    manageData.showAccessory = true
                    manageData.cselector = #selector(groupProfileExtensionButtonClick(_:))
                    if info.weight == 100 {
                        if canManager() {
                            groupInfoArray.append(manageData)
                        }
                    } else {
                        groupInfoArray.append(manageData)
                    }
                }
            }

            // Group Type
            let typeData = TUICommonTextCellData()
            typeData.key = TUISwift.timCommonLocalizableString("TUIKitGroupProfileType")
            typeData.value = Self.getGroupTypeName(groupInfo)
            groupInfoArray.append(typeData)

            // Group Joining Method
            let joinData = TUICommonTextCellData()
            joinData.key = TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinType")

            if canManager() {
                joinData.cselector = #selector(didSelectAddOption(_:))
                joinData.showAccessory = true
            }
            joinData.value = Self.getAddOption(groupInfo)

            groupInfoArray.append(joinData)
            addOptionData = joinData

            // Group Inviting Method
            let inviteOptionData = TUICommonTextCellData()
            inviteOptionData.key = TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteType")
            if canManager() {
                inviteOptionData.cselector = #selector(didSelectAddOption(_:))
                inviteOptionData.showAccessory = true
            }
            inviteOptionData.value = Self.getApproveOption(groupInfo)
            groupInfoArray.append(inviteOptionData)
            self.inviteOptionData = inviteOptionData

            dataList.append(groupInfoArray)
        }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.alias) {
            // My Alias in Group
            let aliasData = TUICommonTextCellData()
            aliasData.key = TUISwift.timCommonLocalizableString("TUIKitGroupProfileAlias")
            aliasData.value = selfInfo?.nameCard ?? ""
            aliasData.cselector = #selector(didSelectGroupNick(_:))
            aliasData.showAccessory = true
            groupNickNameCellData = aliasData
            dataList.append([aliasData])
        }
        
        // Voice message settings section (after alias)
        let extensionParam: [String: Any] = [
            "groupID": groupID,
            "pushVC": delegate?.pushNavigationController() as Any
        ]
        let voiceExtensionList = TUICore.getExtensionList(
            "TUICore_TUIChatExtension_GroupProfileSettingsSwitch_MinimalistExtensionID",
            param: extensionParam
        )
        
        if !voiceExtensionList.isEmpty {
            var voiceSettingsArray: [Any] = []
            for info in voiceExtensionList {
                if let infoData = info.data,
                   let displayValue = infoData["displayValue"] as? String {
                    let textData = TUICommonTextCellData()
                    textData.key = info.text ?? ""
                    textData.value = displayValue
                    textData.showAccessory = true
                    textData.cselector = #selector(didSelectVoiceSetting(_:))
                    textData.tui_extValueObj = info
                    voiceSettingsArray.append(textData)
                }
            }
            if !voiceSettingsArray.isEmpty {
                dataList.append(voiceSettingsArray)
            }
        }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.background) {
            // Background
            let changeBackgroundImageItem = TUICommonTextCellData()
            changeBackgroundImageItem.key = TUISwift.timCommonLocalizableString("ProfileSetBackgroundImage")
            changeBackgroundImageItem.cselector = #selector(didSelectOnChangeBackgroundImage(_:))
            changeBackgroundImageItem.showAccessory = true
            dataList.append([changeBackgroundImageItem])
        }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.members) {
            // Group Members
            var memberArray: [Any] = []

            let countData = TUICommonTextCellData()
            countData.key = TUISwift.timCommonLocalizableString("TUIKitGroupProfileMember")
            countData.value = String(format: TUISwift.timCommonLocalizableString("TUIKitGroupProfileMemberCount"), groupInfo.memberCount)
            countData.cselector = #selector(didSelectMembers)
            countData.showAccessory = true
            memberArray.append(countData)

            let addMembers = TUIGroupButtonCellData_Minimalist()
            addMembers.title = TUISwift.timCommonLocalizableString("TUIKitAddMembers")
            addMembers.style = TUIButtonStyle(rawValue: 3)!
            addMembers.isInfoPageLeftButton = true
            addMembers.cbuttonSelector = #selector(didAddMembers)
            if groupInfo.canInviteMember() {
                memberArray.append(addMembers)
            }

            memberArray.append(createSelfData())

            var otherMemberCount = 0
            for memberObj in membersData {
                memberArray.append(memberObj)
                otherMemberCount += 1
                if otherMemberCount > 1 {
                    break
                }
            }
            dataList.append(memberArray)
        }

        var buttonArray: [Any] = []
        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.clearChatHistory) {
            // Clear Chat History
            let clearHistory = TUIGroupButtonCellData_Minimalist()
            clearHistory.title = TUISwift.timCommonLocalizableString("TUIKitClearAllChatHistory")
            clearHistory.style = TUIButtonStyle(rawValue: 2)!
            clearHistory.cbuttonSelector = #selector(didClearAllHistory(_:))
            buttonArray.append(clearHistory)
        }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.deleteAndLeave) {
            // Delete and Leave
            let quitButton = TUIGroupButtonCellData_Minimalist()
            quitButton.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileDeleteAndExit")
            quitButton.style = TUIButtonStyle(rawValue: 2)!
            quitButton.cbuttonSelector = #selector(didDeleteGroup(_:))
            buttonArray.append(quitButton)
        }

        if isSuperAdmin() && !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.transfer) {
            // Transfer Group
            var param: [String: Any] = [
                "pushVC": delegate?.pushNavigationController() as Any,
                "groupID": groupID
            ]
            let updateGroupInfoCallback: () -> Void = { [weak self] in
                self?.updateGroupInfo(nil)
            }
            param["updateGroupInfoCallback"] = updateGroupInfoCallback
            let extensionList = TUICore.getExtensionList(TUICore_TUIChatExtension_GroupProfileBottomItemExtension_MinimalistExtensionID, param: param)
            for info in extensionList {
                if let text = info.text, let onClicked = info.onClicked {
                    let transferButton = TUIGroupButtonCellData_Minimalist()
                    transferButton.title = text
                    transferButton.style = TUIButtonStyle(rawValue: 2)!
                    transferButton.tui_extValueObj = info
                    transferButton.cbuttonSelector = #selector(groupProfileExtensionButtonClick(_:))
                    buttonArray.append(transferButton)
                }
            }
        }

        if groupInfo.canDismissGroup() && !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.dismiss) {
            // Disband Group
            let deleteButton = TUIGroupButtonCellData_Minimalist()
            deleteButton.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileDissolve")
            deleteButton.style = TUIButtonStyle(rawValue: 2)!
            deleteButton.cbuttonSelector = #selector(didDeleteGroup(_:))
            buttonArray.append(deleteButton)
        }

        if !TUIGroupConfig.shared.isItemHiddenInGroupConfig(.report) {
            // Report
            let reportButton = TUIGroupButtonCellData_Minimalist()
            reportButton.title = TUISwift.timCommonLocalizableString("TUIKitGroupProfileReport")
            reportButton.style = TUIButtonStyle(rawValue: 2)!
            reportButton.cbuttonSelector = #selector(didReportGroup(_:))
            buttonArray.append(reportButton)
        }

        if buttonArray.count > 1 {
            if let lastCellData = buttonArray.last as? TUIGroupButtonCellData_Minimalist {
                lastCellData.hideSeparatorLine = true
            }
            dataList.append(buttonArray)
        }

        self.dataList = dataList
    }

    // MARK: TUIGroupInfoDataProvider_MinimalistDelegate_Minimalist

    @objc func groupProfileExtensionButtonClick(_ cell: TUICommonTextCell) {
        // Implemented through self.delegate, because of TUIButtonCellData cbuttonSelector mechanism
    }

    @objc func didAddMembers() {
        delegate?.didAddMembers()
    }

    @objc func didSelectMembers() {
        delegate?.didSelectMembers()
    }

    @objc func didSelectGroupNick(_ cell: TUICommonTextCell) {
        delegate?.didSelectGroupNick(cell)
    }

    @objc func didSelectAddOption(_ cell: UITableViewCell) {
        delegate?.didSelectAddOption(cell)
    }

    @objc func didSelectCommon() {
        delegate?.didSelectCommon()
    }

    @objc func didSelectOnNotDisturb(_ cell: TUICommonSwitchCell) {
        delegate?.didSelectOnNotDisturb(cell)
    }

    @objc func didSelectOnTop(_ cell: TUICommonSwitchCell) {
        delegate?.didSelectOnTop(cell)
    }

    @objc func didSelectOnFoldConversation(_ cell: TUICommonSwitchCell) {
        delegate?.didSelectOnFoldConversation(cell)
    }

    @objc func didSelectOnChangeBackgroundImage(_ cell: TUICommonTextCell) {
        delegate?.didSelectOnChangeBackgroundImage(cell)
    }
    
    @objc func didSelectVoiceSetting(_ cell: TUICommonTextCell) {
        delegate?.didSelectVoiceSetting?(cell)
    }

    @objc func didDeleteGroup(_ cell: TUIButtonCell) {
        delegate?.didDeleteGroup(cell)
    }

    @objc func didClearAllHistory(_ cell: TUIButtonCell) {
        delegate?.didClearAllHistory(cell)
    }

    @objc func didSelectNotice() {
        delegate?.didSelectGroupNotice()
    }

    @objc func didReportGroup(_ cell: TUIButtonCell) {
        if let url = URL(string: "https://cloud.tencent.com/act/event/report-platform") {
            TUITool.openLink(with: url)
        }
    }

    private func getShowMembers(_ members: [TUIGroupMemberCellData_Minimalist]) -> [TUIGroupMemberCellData_Minimalist] {
        var tmpArray: [TUIGroupMemberCellData_Minimalist] = []
        let maxCount = TGroupMembersCell_Column_Count * TGroupMembersCell_Row_Count
        for i in 0 ..< min(members.count, Int(maxCount)) {
            tmpArray.append(members[i])
        }
        if groupInfo?.canInviteMember() == true {
            let add = TUIGroupMemberCellData_Minimalist()
            add.avatarImage = TUISwift.tuiContactCommonBundleImage("add")
            add.tag = 1
            tmpArray.append(add)
        }
        if canRemoveMember() {
            let delete = TUIGroupMemberCellData_Minimalist()
            delete.avatarImage = TUISwift.tuiContactCommonBundleImage("delete")
            delete.tag = 2
            tmpArray.append(delete)
        }
        return tmpArray
    }

    func setGroupAddOpt(_ opt: V2TIMGroupAddOpt) {
        let info = V2TIMGroupInfo()
        info.groupID = groupID
        info.groupAddOpt = opt

        V2TIMManager.sharedInstance().setGroupInfo(info: info) { [weak self] in
            self?.groupInfo?.groupAddOpt = opt
            self?.addOptionData?.value = TUIGroupInfoDataProvider_Minimalist.getAddOptionWithV2AddOpt(opt)
        } fail: { [weak self] code, desc in
            guard let self else { return }
            self.makeToastError(Int(code), msg: desc ?? "")
        }
    }

    func setGroupApproveOpt(_ opt: V2TIMGroupAddOpt) {
        let info = V2TIMGroupInfo()
        info.groupID = groupID
        info.groupApproveOpt = opt

        V2TIMManager.sharedInstance().setGroupInfo(info: info) { [weak self] in
            guard let self else { return }
            self.groupInfo?.groupApproveOpt = opt
            if let groupInfo = groupInfo {
                self.inviteOptionData?.value = TUIGroupInfoDataProvider_Minimalist.getApproveOption(groupInfo)
            }
        } fail: { [weak self] code, desc in
            guard let self else { return }
            self.makeToastError(Int(code), msg: desc ?? "")
        }
    }

    func setGroupReceiveMessageOpt(_ opt: V2TIMReceiveMessageOpt, succ: @escaping V2TIMSucc, fail: @escaping V2TIMFail) {
        V2TIMManager.sharedInstance().setGroupReceiveMessageOpt(groupID: groupID, opt: opt, succ: succ, fail: fail)
    }

    func setGroupName(_ groupName: String, _ succ: V2TIMSucc?, _ fail: V2TIMFail?) {
        let info = V2TIMGroupInfo()
        info.groupID = groupID
        info.groupName = groupName

        V2TIMManager.sharedInstance().setGroupInfo(info: info) { [weak self] in
            self?.profileCellData?.name = groupName
            succ?()
        } fail: { [weak self] code, msg in
            guard let self else { return }
            self.makeToastError(Int(code), msg: msg ?? "")
            fail?(code, msg)
        }
    }

    func setGroupNotification(_ notification: String) {
        let info = V2TIMGroupInfo()
        info.groupID = groupID
        info.notification = notification

        V2TIMManager.sharedInstance().setGroupInfo(info: info) { [weak self] in
            self?.profileCellData?.signature = notification
        } fail: { [weak self] code, msg in
            guard let self else { return }
            self.makeToastError(Int(code), msg: msg ?? "")
        }
    }

    func setGroupMemberNameCard(_ nameCard: String) {
        guard let userID = V2TIMManager.sharedInstance().getLoginUser() else { return }
        let info = V2TIMGroupMemberFullInfo()
        info.userID = userID
        info.nameCard = nameCard

        V2TIMManager.sharedInstance().setGroupMemberInfo(groupID: groupID, info: info) { [weak self] in
            self?.groupNickNameCellData?.value = nameCard
            self?.selfInfo?.nameCard = nameCard
        } fail: { [weak self] code, msg in
            guard let self else { return }
            self.makeToastError(Int(code), msg: msg ?? "")
        }
    }

    func dismissGroup(succ: @escaping V2TIMSucc, fail: @escaping V2TIMFail) {
        V2TIMManager.sharedInstance().dismissGroup(groupID: groupID, succ: succ, fail: fail)
    }

    func quitGroup(succ: @escaping V2TIMSucc, fail: @escaping V2TIMFail) {
        V2TIMManager.sharedInstance().quitGroup(groupID: groupID, succ: succ, fail: fail)
    }

    func clearAllHistory(succ: @escaping V2TIMSucc, fail: @escaping V2TIMFail) {
        V2TIMManager.sharedInstance().clearGroupHistoryMessage(groupID: groupID, succ: succ, fail: fail)
    }
    
    private func canRemoveMember() -> Bool {
        return selfInfo != nil && TUIGroupInfoDataProvider_Minimalist.isMeOwnerByGroupMemberInfo(selfInfo!)
    }
    
    private func canManager() -> Bool {
        return selfInfo != nil && TUIGroupInfoDataProvider_Minimalist.isMeOwnerByGroupMemberInfo(selfInfo!)
    }
    
    private func isSuperAdmin() -> Bool {
        return selfInfo != nil && TUIGroupInfoDataProvider_Minimalist.isMeSuperByGroupMemberInfo(selfInfo!)
    }

    // MARK: - Static Methods

    static func getGroupTypeName(_ groupInfo: V2TIMGroupInfo) -> String {
        switch groupInfo.groupType {
        case "Work":
            return TUISwift.timCommonLocalizableString("TUIKitWorkGroup")
        case "Public":
            return TUISwift.timCommonLocalizableString("TUIKitPublicGroup")
        case "Meeting":
            return TUISwift.timCommonLocalizableString("TUIKitChatRoom")
        case "Community":
            return TUISwift.timCommonLocalizableString("TUIKitCommunity")
        default:
            return ""
        }
    }

    static func getAddOption(_ groupInfo: V2TIMGroupInfo) -> String {
        switch groupInfo.groupAddOpt {
        case .GROUP_ADD_FORBID:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinDisable")
        case .GROUP_ADD_AUTH:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdminApprove")
        case .GROUP_ADD_ANY:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileAutoApproval")
        default:
            return ""
        }
    }

    static func getAddOptionWithV2AddOpt(_ opt: V2TIMGroupAddOpt) -> String {
        switch opt {
        case .GROUP_ADD_FORBID:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileJoinDisable")
        case .GROUP_ADD_AUTH:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdminApprove")
        case .GROUP_ADD_ANY:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileAutoApproval")
        default:
            return ""
        }
    }

    static func getApproveOption(_ groupInfo: V2TIMGroupInfo) -> String {
        switch groupInfo.groupApproveOpt {
        case .GROUP_ADD_FORBID:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileInviteDisable")
        case .GROUP_ADD_AUTH:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileAdminApprove")
        case .GROUP_ADD_ANY:
            return TUISwift.timCommonLocalizableString("TUIKitGroupProfileAutoApproval")
        default:
            return ""
        }
    }

    static func isMarkedByFoldType(_ markList: [NSNumber]) -> Bool {
        return markList.contains { $0.intValue == V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_FOLD.rawValue }
    }

    static func isMarkedByHideType(_ markList: [NSNumber]) -> Bool {
        return markList.contains { $0.intValue == V2TIMConversationMarkType.CONVERSATION_MARK_TYPE_HIDE.rawValue }
    }

    
    static func isMeOwnerByGroupMemberInfo(_ groupMemberFullInfo: V2TIMGroupMemberFullInfo) -> Bool {
        return groupMemberFullInfo.role == V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_ADMIN.rawValue || groupMemberFullInfo.role == V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_SUPER.rawValue
    }
    
    static func isMeSuperByGroupMemberInfo(_ groupMemberFullInfo: V2TIMGroupMemberFullInfo) -> Bool {
        return groupMemberFullInfo.role == V2TIMGroupMemberRole.GROUP_MEMBER_ROLE_SUPER.rawValue
    }
}
