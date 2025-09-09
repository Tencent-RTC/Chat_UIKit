import TIMCommon
import TUICore
import UIKit

// typealias MessageCellClass = TUIMessageCellProtocol.Type

public class TUIMessageCellConfig: NSObject {
    weak var tableView: UITableView?
    lazy var cellClassMaps: [String: TUIMessageCellProtocol.Type] = .init()
    lazy var heightCacheMaps: [String: CGFloat] = .init()
    static var gCustomMessageInfoMap: [String: [String: Any]] = .init()
    private static let kIsCustomMessageFromPlugin = "kIsCustomMessageFromPlugin"

    @objc public class func swiftLoad() {
        registerBuiltInCustomMessageInfo()
        registerExternalCustomMessageInfo()
    }

    class func setMaxTextSize(_ maxTextSize: CGSize) {
        TUITextMessageCell.setMaxTextSize(maxTextSize)
    }

    func bindTableView(_ tableView: UITableView?) {
        guard let tableView = tableView else { return }
        self.tableView = tableView

        bindMessageCellClass(TUITextMessageCell.self, cellDataClass: TUITextMessageCellData.self, reuseID: "TTextMessageCell")
        bindMessageCellClass(TUIVoiceMessageCell.self, cellDataClass: TUIVoiceMessageCellData.self, reuseID: "TVoiceMessaageCell")
        bindMessageCellClass(TUIImageMessageCell.self, cellDataClass: TUIImageMessageCellData.self, reuseID: "TImageMessageCell")
        bindMessageCellClass(TUISystemMessageCell.self, cellDataClass: TUISystemMessageCellData.self, reuseID: "TSystemMessageCell")
        bindMessageCellClass(TUIFaceMessageCell.self, cellDataClass: TUIFaceMessageCellData.self, reuseID: "TFaceMessageCell")
        bindMessageCellClass(TUIVideoMessageCell.self, cellDataClass: TUIVideoMessageCellData.self, reuseID: "TVideoMessageCell")
        bindMessageCellClass(TUIFileMessageCell.self, cellDataClass: TUIFileMessageCellData.self, reuseID: "TFileMessageCell")
        bindMessageCellClass(TUIJoinGroupMessageCell.self, cellDataClass: TUIJoinGroupMessageCellData.self, reuseID: "TJoinGroupMessageCell")
        bindMessageCellClass(TUIMergeMessageCell.self, cellDataClass: TUIMergeMessageCellData.self, reuseID: "TMergeMessageCell")
        bindMessageCellClass(TUIReplyMessageCell.self, cellDataClass: TUIReplyMessageCellData.self, reuseID: "TUIReplyMessageCell")
        bindMessageCellClass(TUIReferenceMessageCell.self, cellDataClass: TUIReferenceMessageCellData.self, reuseID: "TUIReferenceMessageCell")

        TUIMessageCellConfig.enumerateCustomMessageInfo { [weak self] messageCellName, messageCellDataName, businessID, _ in
            guard let cellClass = NSClassFromString(messageCellName) as? TUIMessageCellProtocol.Type,
                  let cellDataClass = NSClassFromString(messageCellDataName) else { return }
            self?.bindMessageCellClass(cellClass, cellDataClass: cellDataClass, reuseID: businessID)
        }
    }

    func bindMessageCellClass(_ cellClass: TUIMessageCellProtocol.Type?, cellDataClass: AnyClass?, reuseID: String?) {
        assert(cellClass != nil, "The UITableViewCell can not be nil")
        assert(cellDataClass != nil, "The cell data class can not be nil")
        assert((reuseID?.count ?? 0) > 0, "The reuse identifier can not be nil")

        guard let cellClass = cellClass else { return }
        guard let cellDataClass = cellDataClass else { return }
        guard let reuseID = reuseID else { return }
        tableView?.register(cellClass, forCellReuseIdentifier: reuseID)
        cellClassMaps[String(describing: cellDataClass)] = cellClass
    }
}

extension TUIMessageCellConfig {
    // MARK: - CustomMessageRegister

    static func registerBuiltInCustomMessageInfo() {
        registerCustomMessageCell("TUIChat.TUILinkCell", messageCellData: "TUIChat.TUILinkCellData", forBusinessID: "text_link")
        registerCustomMessageCell("TUIChat.TUIGroupCreatedCell", messageCellData: "TUIChat.TUIGroupCreatedCellData", forBusinessID: "group_create")
        registerCustomMessageCell("TUIChat.TUIEvaluationCell", messageCellData: "TUIChat.TUIEvaluationCellData", forBusinessID: "evaluation")
        registerCustomMessageCell("TUIChat.TUIOrderCell", messageCellData: "TUIChat.TUIOrderCellData", forBusinessID: "order")
        registerCustomMessageCell("TUIMessageCell", messageCellData: "TUIChat.TUITypingStatusCellData", forBusinessID: "user_typing_status")
        registerCustomMessageCell("TUISystemMessageCell", messageCellData: "TUIChat.TUILocalTipsCellData", forBusinessID: "local_tips")
        registerCustomMessageCell("TUIChat.TUIChatbotMessageCell", messageCellData: "TUIChat.TUIChatbotMessageCellData", forBusinessID: "chatbotPlugin")
        registerCustomMessageCell("TUIChat.TUIChatbotMessagePlaceholderCell", messageCellData: "TUIChat.TUIChatbotMessagePlaceholderCellData", forBusinessID: "TUIChatbotMessagePlaceholderCellData")
    }

    static func registerExternalCustomMessageInfo() {
        /*
         Insert your own custom message UI here, your businessID can not be same with built-in
         Example:
         registerCustomMessageCell(#your message cell#, messageCellData: #your message cell data#, forBusinessID: #your id#)
         */
    }

    static func registerCustomMessageCell(_ messageCellName: String, messageCellData: String, forBusinessID businessID: String) {
        registerCustomMessageCell(messageCellName, messageCellData: messageCellData, forBusinessID: businessID, isPlugin: false)
    }

    static func registerCustomMessageCell(_ messageCellName: String, messageCellData: String, forBusinessID businessID: String, isPlugin: Bool) {
        assert(!messageCellName.isEmpty, "message cell name can not be nil")
        assert(!messageCellData.isEmpty, "message cell data name can not be nil")
        assert(!businessID.isEmpty, "businessID can not be nil")
        assert(gCustomMessageInfoMap[businessID] == nil, "businessID can not be same with the exists")

        var info = [String: Any]()
        info["businessID"] = businessID
        info["TMessageCell_Name"] = messageCellName
        info["TMessageCell_Data_Name"] = messageCellData
        info[kIsCustomMessageFromPlugin] = isPlugin

        gCustomMessageInfoMap[businessID] = info
    }

    static func enumerateCustomMessageInfo(_ callback: @escaping (String, String, String, Bool) -> Void) {
        for (_, info) in gCustomMessageInfoMap {
            guard let businessID = info["businessID"] as? String,
                  let messageCellName = info["TMessageCell_Name"] as? String,
                  let messageCellDataName = info["TMessageCell_Data_Name"] as? String,
                  let isPlugin = info[kIsCustomMessageFromPlugin] as? Bool else { continue }
            callback(messageCellName, messageCellDataName, businessID, isPlugin)
        }
    }

    static func getCustomMessageCellDataClass(_ businessID: String) -> TUIMessageCellDataDelegate.Type? {
        guard let info = gCustomMessageInfoMap[businessID],
              let messageCellDataName = info["TMessageCell_Data_Name"] as? String
        else {
            return nil
        }
        if let name = NSClassFromString(messageCellDataName) as? TUIMessageCellDataDelegate.Type {
            return name
        }
        return nil
    }

    static func isPluginCustomMessageCellData(_ data: TUIMessageCellData) -> Bool {
        var flag = false
        for (_, info) in gCustomMessageInfoMap {
            if let businessID = info["businessID"] as? String,
               let isPlugin = info[kIsCustomMessageFromPlugin] as? Bool,
               isPlugin && data.reuseId == businessID
            {
                flag = true
                continue
            }
        }

        return flag
    }

    // MARK: - MessageCellHeight

    func getHeightCacheKey(_ msg: TUIMessageCellData) -> String {
        if let msgID = msg.msgID, !msgID.isEmpty {
            return msgID
        } else {
            return String(format: "%p", msg)
        }
    }

    static var screenWidth: CGFloat = 0
    func getHeightFromMessageCellData(_ cellData: TUIMessageCellData?) -> CGFloat {
        guard let cellData = cellData else { return 0 }
        if TUIMessageCellConfig.screenWidth == 0 {
            TUIMessageCellConfig.screenWidth = TUISwift.screen_Width()
        }
        let key = getHeightCacheKey(cellData)
        guard let height = heightCacheMaps[key] else {
            if let cellClass = cellClassMaps[String(describing: type(of: cellData))] {
                let height = cellClass.getHeight(cellData, withWidth: TUIMessageCellConfig.screenWidth)
                heightCacheMaps[key] = height
                return height
            }
            return 0
        }
        return height
    }

    func getEstimatedHeightFromMessageCellData(_ cellData: TUIMessageCellData) -> CGFloat {
        let key = getHeightCacheKey(cellData)
        if let cachedHeight = heightCacheMaps[key], cachedHeight > 0 {
            return CGFloat(cachedHeight)
        }
        return UITableView.automaticDimension
    }

    func removeHeightCacheOfMessageCellData(_ cellData: TUIMessageCellData) {
        let key = getHeightCacheKey(cellData)
        heightCacheMaps.removeValue(forKey: key)
    }
}
