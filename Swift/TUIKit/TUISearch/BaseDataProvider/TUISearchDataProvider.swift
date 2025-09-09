import Foundation
import TIMCommon
import UIKit

let kSearchChatHistoryConversationId = "Id"
let kSearchChatHistoryConverationInfo = "conversation"
let kSearchChatHistoryConversationMsgs = "msgs"

let kMaxNumOfPerModule = 3

struct TUISearchResultModule: OptionSet {
    let rawValue: Int

    static let all = TUISearchResultModule(rawValue: 1 << 0)
    static let contact = TUISearchResultModule(rawValue: 1 << 1)
    static let group = TUISearchResultModule(rawValue: 1 << 2)
    static let chatHistory = TUISearchResultModule(rawValue: 1 << 3)
}

typealias TUISearchParamKey = String
let TUISearchChatHistoryParamKeyConversationId: TUISearchParamKey = "TUISearchChatHistoryParamKeyConversationId"
let TUISearchChatHistoryParamKeyCount: TUISearchParamKey = "TUISearchChatHistoryParamKeyCount"
let TUISearchChatHistoryParamKeyPage: TUISearchParamKey = "TUISearchChatHistoryParamKeyPage"
let TUISearchDefaultPageSize: UInt = 20

func titleForModule(_ module: TUISearchResultModule, isHeader: Bool) -> String {
    var headerTitle = ""
    var footerTitle = ""
    switch module {
    case .contact:
        headerTitle = TUISwift.timCommonLocalizableString("TUIKitSearchItemHeaderTitleContact")
        footerTitle = TUISwift.timCommonLocalizableString("TUIKitSearchItemFooterTitleContact")
    case .group:
        headerTitle = TUISwift.timCommonLocalizableString("TUIKitSearchItemHeaderTitleGroup")
        footerTitle = TUISwift.timCommonLocalizableString("TUIKitSearchItemFooterTitleGroup")
    case .chatHistory:
        headerTitle = TUISwift.timCommonLocalizableString("TUIkitSearchItemHeaderTitleChatHistory")
        footerTitle = TUISwift.timCommonLocalizableString("TUIKitSearchItemFooterTitleChatHistory")
    default:
        break
    }
    return isHeader ? headerTitle : footerTitle
}

protocol TUISearchResultDelegate: AnyObject {
    func onSearchResults(_ results: [Int: [TUISearchResultCellModel]], forModules modules: TUISearchResultModule)
    func onSearchError(_ errMsg: String)
}

class TUISearchDataProvider: NSObject {
    weak var delegate: TUISearchResultDelegate?
    private(set) var resultSet = [Int: [TUISearchResultCellModel]]()

    func searchForKeyword(_ keyword: String, forModules modules: TUISearchResultModule, param: [TUISearchParamKey: Any]?) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.searchForKeyword(keyword, forModules: modules, param: param)
            }
            return
        }

        if keyword.isEmpty {
            resultSet.removeAll()
            delegate?.onSearchResults(resultSet, forModules: modules)
            return
        }

        let group = DispatchGroup()
        var request = false

        // Contact
        if modules == .all || modules.contains(.contact) {
            request = true
            group.enter()
            searchContacts(keyword) { [weak self] succ, _, results in
                guard let self = self else { return }
                if succ, let results = results {
                    DispatchQueue.main.async {
                        if !results.isEmpty {
                            self.resultSet[TUISearchResultModule.contact.rawValue] = results
                        } else {
                            self.resultSet.removeValue(forKey: TUISearchResultModule.contact.rawValue)
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        // Group
        if modules == .all || modules.contains(.group) {
            request = true
            group.enter()
            searchGroups(keyword) { [weak self] succ, _, results in
                guard let self = self else { return }
                if succ, let results = results {
                    DispatchQueue.main.async {
                        if !results.isEmpty {
                            self.resultSet[TUISearchResultModule.group.rawValue] = results
                        } else {
                            self.resultSet.removeValue(forKey: TUISearchResultModule.group.rawValue)
                        }
                        group.leave()
                    }
                } else {
                    group.leave()
                }
            }
        }

        // Chat history
        if modules == .all || modules.contains(.chatHistory) {
            request = true
            group.enter()
            searchChatHistory(keyword, param: param) { [weak self] succ, _, results in
                guard let self = self else { return }
                if succ, let results = results {
                    DispatchQueue.main.async {
                        if !results.isEmpty {
                            self.resultSet[TUISearchResultModule.chatHistory.rawValue] = results
                        } else {
                            self.resultSet.removeValue(forKey: TUISearchResultModule.chatHistory.rawValue)
                        }
                    }
                }
                group.leave()
            }
        }

        if !request {
            delegate?.onSearchError("search module not exists")
            return
        }

        group.notify(queue: .main) {
            self.delegate?.onSearchResults(self.resultSet, forModules: modules)
        }
    }

    private func searchContacts(_ keyword: String, callback: @escaping (Bool, String?, [TUISearchResultCellModel]?) -> Void) {
        guard !keyword.isEmpty else {
            callback(false, "invalid parameters, keyword is null", nil)
            return
        }

        let param = V2TIMFriendSearchParam()
        param.keywordList = [keyword]
        param.isSearchUserID = true
        param.isSearchNickName = true
        param.isSearchRemark = true
        V2TIMManager.sharedInstance().searchFriends(searchParam: param, succ: { infoList in
            guard let infoList = infoList else { return }
            var arrayM = [TUISearchResultCellModel]()
            for result in infoList {
                let cellModel = TUISearchResultCellModel()
                var title = result.friendInfo.friendRemark
                if title == nil || title!.isEmpty {
                    title = result.friendInfo.userFullInfo.nickName
                }
                if title == nil || title!.isEmpty {
                    title = result.friendInfo.userID
                }

                var why = ""
                if let userID = result.friendInfo?.userID?.lowercased() {
                    why = userID
                }

                cellModel.titleAttributeString = TUISearchDataProvider.attributeString(withText: title, key: keyword)
                cellModel.detailsAttributeString = TUISearchDataProvider.attributeString(withText: why, key: keyword)
                cellModel.groupID = nil
                cellModel.avatarUrl = result.friendInfo.userFullInfo.faceURL ?? ""
                cellModel.avatarImage = TUISwift.defaultAvatarImage()
                cellModel.context = result.friendInfo
                arrayM.append(cellModel)
            }
            callback(true, nil, arrayM)
        }, fail: { _, desc in
            callback(false, desc, nil)
        })
    }

    private func searchGroups(_ keyword: String, callback: @escaping (Bool, String?, [TUISearchResultCellModel]?) -> Void) {
        guard !keyword.isEmpty else {
            callback(false, "invalid parameters, keyword is null", nil)
            return
        }

        let param = TUISearchGroupParam()
        param.keywordList = [keyword]
        param.isSearchGroupID = true
        param.isSearchGroupName = true
        param.isSearchGroupMember = true
        param.isSearchMemberRemark = true
        param.isSearchMemberUserID = true
        param.isSearchMemberNickName = true
        param.isSearchMemberNameCard = true
        TUISearchGroupDataProvider.searchGroups(param, succ: { resultSet in
            var arrayM = [TUISearchResultCellModel]()
            for result in resultSet {
                guard let groupInfo = result.groupInfo else { return }
                let cellModel = TUISearchResultCellModel()
                var title = groupInfo.groupName
                if title == nil {
                    title = groupInfo.groupID
                }
                cellModel.titleAttributeString = TUISearchDataProvider.attributeString(withText: title, key: keyword)
                cellModel.detailsAttributeString = nil
                cellModel.groupID = groupInfo.groupID
                cellModel.groupType = groupInfo.groupType
                if let groupType = groupInfo.groupType {
                    cellModel.avatarImage = TUISwift.defaultGroupAvatarImage(byGroupType: groupType)
                }
                cellModel.avatarUrl = groupInfo.faceURL
                cellModel.context = groupInfo
                arrayM.append(cellModel)

                if result.matchField == .groupID {
                    let text = String(format: TUISwift.timCommonLocalizableString("TUIKitSearchResultMatchGroupIDFormat"), result.matchValue ?? "")
                    cellModel.detailsAttributeString = TUISearchDataProvider.attributeString(withText: text, key: keyword)
                } else if let members = result.matchMembers, result.matchField == .member, !members.isEmpty {
                    var text = TUISwift.timCommonLocalizableString("TUIKitSearchResultMatchGroupMember")
                    for (i, memberResult) in members.enumerated() {
                        text += memberResult.memberMatchValue ?? ""
                        if i < members.count - 1 {
                            text += "、"
                        }
                    }
                    cellModel.detailsAttributeString = TUISearchDataProvider.attributeString(withText: text, key: keyword)
                }
            }
            callback(true, nil, arrayM)
        }, fail: { _, desc in
            callback(false, desc, nil)
        })
    }

    private func searchChatHistory(_ keyword: String, param: [TUISearchParamKey: Any]?, callback: @escaping (Bool, String?, [TUISearchResultCellModel]?) -> Void) {
        guard !keyword.isEmpty else {
            callback(false, "invalid parameters, keyword is null", nil)
            return
        }

        var pageSize = TUISearchDefaultPageSize
        var pageIndex: UInt = 0
        var conversationID: String?
        var displayWithConversation = true

        if let allKeys = param?.keys {
            if allKeys.contains(TUISearchChatHistoryParamKeyCount) {
                pageSize = param?[TUISearchChatHistoryParamKeyCount] as? UInt ?? TUISearchDefaultPageSize
            }
            if allKeys.contains(TUISearchChatHistoryParamKeyPage) {
                pageIndex = param?[TUISearchChatHistoryParamKeyPage] as? UInt ?? 0
            }
            if allKeys.contains(TUISearchChatHistoryParamKeyConversationId) {
                conversationID = param?[TUISearchChatHistoryParamKeyConversationId] as? String
                displayWithConversation = false
            }
        }

        let searchParam = V2TIMMessageSearchParam()
        searchParam.keywordList = [keyword]
        searchParam.messageTypeList = nil
        searchParam.conversationID = conversationID
        searchParam.searchTimePosition = 0
        searchParam.searchTimePeriod = 0
        searchParam.pageIndex = pageIndex
        searchParam.pageSize = pageSize
        V2TIMManager.sharedInstance().searchLocalMessages(param: searchParam, succ: { searchResult in
            guard let searchResult = searchResult, searchResult.totalCount > 0 else {
                callback(true, nil, [])
                return
            }

            var conversationIds = [String]()
            var conversationInfoMap = [String: V2TIMConversation]()
            var conversationMessageMap = [String: [V2TIMMessage]]()
            var conversationCountMap = [String: UInt]()
            if let items = searchResult.messageSearchResultItems {
                for searchItem in items {
                    let messageCount = searchItem.messageCount
                    let messageList = searchItem.messageList
                    if let conversationID = searchItem.conversationID, !conversationID.isEmpty {
                        conversationIds.append(conversationID)
                        conversationMessageMap[conversationID] = messageList
                        conversationCountMap[conversationID] = messageCount
                    }
                }
            }

            if conversationIds.isEmpty {
                callback(true, nil, [])
                return
            }

            V2TIMManager.sharedInstance().getConversationList(conversationIDList: conversationIds, succ: { list in
                guard let list = list else { return }
                for conversation in list {
                    if let conversationID = conversation.conversationID {
                        conversationInfoMap[conversationID] = conversation
                    }
                }
                var arrayM = [TUISearchResultCellModel]()
                for conversationId in conversationIds {
                    guard let conv = conversationInfoMap[conversationId] else {
                        continue
                    }

                    let messageList = conversationMessageMap[conversationId] ?? []
                    let count = conversationCountMap[conversationId] ?? 0
                    if displayWithConversation {
                        let cellModel = TUISearchResultCellModel()
                        var desc = String(format: TUISwift.timCommonLocalizableString("TUIKitSearchResultDisplayChatHistoryCountFormat"), count)
                        if messageList.count == 1, let firstMessage = messageList.first {
                            desc = TUISearchDataProvider.matchedText(forMessage: firstMessage, withKey: keyword)
                        }
                        cellModel.title = conv.showName
                        cellModel.detailsAttributeString = TUISearchDataProvider.attributeString(withText: desc, key: messageList.count == 1 ? keyword : nil)
                        cellModel.groupID = conv.groupID
                        if let groupType = conv.groupType {
                            cellModel.avatarImage = conv.type.rawValue == TUISearchResultModule.group.rawValue ? TUISwift.defaultGroupAvatarImage(byGroupType: groupType) : TUISwift.defaultAvatarImage()
                        }
                        cellModel.groupType = conv.groupType
                        cellModel.avatarUrl = conv.faceUrl
                        cellModel.context = [
                            kSearchChatHistoryConversationId: conversationId,
                            kSearchChatHistoryConverationInfo: conv,
                            kSearchChatHistoryConversationMsgs: messageList
                        ]
                        arrayM.append(cellModel)
                    } else {
                        for message in messageList {
                            let cellModel = TUISearchResultCellModel()
                            cellModel.title = message.nickName ?? message.sender
                            let desc = TUISearchDataProvider.matchedText(forMessage: message, withKey: keyword)
                            cellModel.detailsAttributeString = TUISearchDataProvider.attributeString(withText: desc, key: keyword)
                            cellModel.groupID = conv.groupID
                            cellModel.groupType = conv.groupType
                            cellModel.avatarUrl = message.faceURL
                            if let groupType = conv.groupType {
                                cellModel.avatarImage = conv.type.rawValue == TUISearchResultModule.group.rawValue ? TUISwift.defaultGroupAvatarImage(byGroupType: groupType) : TUISwift.defaultAvatarImage()
                            }
                            cellModel.context = message
                            arrayM.append(cellModel)
                        }
                    }
                }
                arrayM.last?.hideSeparatorLine = true

                callback(true, nil, arrayM)
            }, fail: { _, desc in
                callback(false, desc, nil)
            })
        }, fail: { code, desc in
            callback(false, desc, nil)
            if code == ERR_SDK_INTERFACE_NOT_SUPPORT.rawValue {
                TUITool.postUnsupportNotification(ofService: TUISwift.timCommonLocalizableString("TUIKitErrorUnsupportIntefaceSearch"))
            }
        })
    }

    static func attributeString(withText text: String?, key: String?) -> NSAttributedString? {
        guard let text = text, !text.isEmpty else {
            return nil
        }

        guard let key = key, !key.isEmpty, text.lowercased().contains(key.lowercased()) else {
            return NSAttributedString(string: text, attributes: [.foregroundColor: UIColor.darkGray])
        }

        let attr = NSMutableAttributedString(string: text, attributes: [.foregroundColor: UIColor.darkGray])

        let lowerTextArray = Array(text.lowercased())
        let lowerKeyArray = Array(key.lowercased())
        var loc = 0
        while loc <= lowerTextArray.count - lowerKeyArray.count {
            let subArray = lowerTextArray[loc ..< loc + lowerKeyArray.count]
            if subArray.elementsEqual(lowerKeyArray) {
                let nsRange = NSRange(location: loc, length: lowerKeyArray.count)
                attr.addAttribute(.foregroundColor, value: TUISwift.timCommonDynamicColor("primary_theme_color", defaultColor: "#147AFF"), range: nsRange)
                loc += lowerKeyArray.count
            } else {
                loc += 1
            }
        }
        return NSAttributedString(attributedString: attr)
    }

    static func matchedText(forMessage msg: V2TIMMessage, withKey key: String) -> String {
        guard !key.isEmpty else {
            return ""
        }

        switch msg.elemType {
        case V2TIMElemType.ELEM_TYPE_TEXT:
            if let text = msg.textElem?.text, text.tui_contains(key) {
                return text
            }
        case V2TIMElemType.ELEM_TYPE_IMAGE:
            if let path = msg.imageElem?.path, path.tui_contains(key) {
                return path
            }
        case V2TIMElemType.ELEM_TYPE_SOUND:
            if let path = msg.soundElem?.path, path.tui_contains(key) {
                return path
            }
        case V2TIMElemType.ELEM_TYPE_VIDEO:
            if let path = msg.videoElem?.videoPath, path.tui_contains(key) {
                return path
            } else if let path = msg.videoElem?.snapshotPath, path.tui_contains(key) {
                return path
            } else {
                return ""
            }
        case V2TIMElemType.ELEM_TYPE_FILE:
            if let path = msg.fileElem?.path, path.tui_contains(key) {
                return path
            }
        case V2TIMElemType.ELEM_TYPE_MERGER:
            if let abs = msg.mergerElem?.abstractList?.joined(separator: ","),
               let title = msg.mergerElem?.title
            {
                if title.tui_contains(key) {
                    return title
                } else if abs.tui_contains(key) {
                    return abs
                } else {
                    return ""
                }
            }
        default:
            return ""
        }
        return ""
    }
}
