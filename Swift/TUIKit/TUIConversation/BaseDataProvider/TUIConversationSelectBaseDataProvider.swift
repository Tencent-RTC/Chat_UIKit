import Foundation
import TIMCommon
import UIKit

class TUIConversationSelectBaseDataProvider: NSObject {
    @objc dynamic var dataList: [TUIConversationCellData] = []

    lazy var localConvList: [V2TIMConversation] = {
        var localConvList = [V2TIMConversation]()
        return localConvList
    }()

    override init() {
        super.init()
    }

    func loadConversations() {
        V2TIMManager.sharedInstance().getConversationList(nextSeq: 0, count: INT_MAX) { [weak self] list, _, _ in
            guard let self = self, let list = list else { return }
            self.updateConversation(list)
        } fail: { _, _ in
            print("getConversationList failed")
        }
    }

    private func updateConversation(_ convList: [V2TIMConversation]) {
        for conv in convList {
            if let index = localConvList.firstIndex(where: { $0.conversationID == conv.conversationID }) {
                localConvList[index] = conv
            } else {
                localConvList.append(conv)
            }
        }

        var dataList: [TUIConversationCellData] = []
        for conv in localConvList {
            if filteConversation(conv) {
                continue
            }
            if let cls = getConversationCellClass() as? TUIConversationCellData.Type {
                let data = cls.init()
                data.conversationID = conv.conversationID
                data.groupID = conv.groupID
                data.userID = conv.userID
                data.title = conv.showName
                data.faceUrl = conv.faceUrl
                data.unreadCount = 0
                data.draftText = ""
                data.subTitle = NSMutableAttributedString(string: "")
                if conv.type == .C2C {
                    data.avatarImage = TUISwift.defaultAvatarImage()
                } else {
                    data.avatarImage = TUISwift.defaultGroupAvatarImage(byGroupType: conv.groupType)
                }
                dataList.append(data)
            }
        }

        sortDataList(&dataList)
        self.dataList = dataList
    }

    private func filteConversation(_ conv: V2TIMConversation) -> Bool {
        if conv.groupType == "AVChatRoom" {
            return true
        }
        // Filter AI conversations (conversations containing "@RBT#")
        if let conversationID = conv.conversationID,
           conversationID.contains("@RBT#") {
            return true
        }
        return false
    }

    private func sortDataList(_ dataList: inout [TUIConversationCellData]) {
        dataList.sort { (obj1: TUIConversationCellData, obj2: TUIConversationCellData) -> Bool in
            if let time1 = obj1.time, let time2 = obj2.time {
                return time2.compare(time1) == .orderedDescending
            }
            return obj1.time != nil
        }

        let topList = TUIConversationPin.sharedInstance.topConversationList
        var existTopListSize = 0

        for convID in topList() {
            if let index = dataList.firstIndex(where: { $0.conversationID == convID }) {
                dataList[index].isOnTop = true

                if index != existTopListSize {
                    let cellData = dataList[index]
                    dataList.remove(at: index)
                    dataList.insert(cellData, at: existTopListSize)
                    existTopListSize += 1
                }
            }
        }
    }

    func getConversationCellClass() -> AnyClass? {
        return nil
    }
}
