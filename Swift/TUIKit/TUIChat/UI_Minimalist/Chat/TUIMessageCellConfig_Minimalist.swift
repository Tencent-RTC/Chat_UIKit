import TIMCommon
import TUICore
import UIKit

// typealias MessageCellClass = TUIMessageCellProtocol.Type

public class TUIMessageCellConfig_Minimalist: NSObject {
    weak var tableView: UITableView?
    lazy var cellClassMaps: [String: AnyClass] = .init()
    lazy var heightCacheMaps: [String: CGFloat] = .init()
    static var gCustomMessageInfoMap: [String: [String: Any]] = .init()
    private static let kIsCustomMessageFromPlugin = "kIsCustomMessageFromPlugin"

    @objc public class func swiftLoad() {
        registerBuiltInCustomMessageInfo()
        registerExternalCustomMessageInfo()
    }

    func bindTableView(_ tableView: UITableView?) {
        guard let tableView = tableView else { return }
        self.tableView = tableView

        bindMessageCellClass(TUITextMessageCell_Minimalist.self, cellDataClass: TUITextMessageCellData.self, reuseID: TTextMessageCell_ReuseId)
        bindMessageCellClass(TUIVoiceMessageCell_Minimalist.self, cellDataClass: TUIVoiceMessageCellData.self, reuseID: TVoiceMessageCell_ReuseId)
        bindMessageCellClass(TUIImageMessageCell_Minimalist.self, cellDataClass: TUIImageMessageCellData.self, reuseID: TImageMessageCell_ReuseId)
        bindMessageCellClass(TUISystemMessageCell.self, cellDataClass: TUISystemMessageCellData.self, reuseID: TSystemMessageCell_ReuseId)
        bindMessageCellClass(TUIFaceMessageCell_Minimalist.self, cellDataClass: TUIFaceMessageCellData.self, reuseID: TFaceMessageCell_ReuseId)
        bindMessageCellClass(TUIVideoMessageCell_Minimalist.self, cellDataClass: TUIVideoMessageCellData.self, reuseID: TVideoMessageCell_ReuseId)
        bindMessageCellClass(TUIFileMessageCell_Minimalist.self, cellDataClass: TUIFileMessageCellData.self, reuseID: TFileMessageCell_ReuseId)
        bindMessageCellClass(TUIJoinGroupMessageCell_Minimalist.self, cellDataClass: TUIJoinGroupMessageCellData.self, reuseID: TJoinGroupMessageCell_ReuseId)
        bindMessageCellClass(TUIMergeMessageCell_Minimalist.self, cellDataClass: TUIMergeMessageCellData.self, reuseID: TMergeMessageCell_ReuserId)
        bindMessageCellClass(TUIReplyMessageCell_Minimalist.self, cellDataClass: TUIReplyMessageCellData.self, reuseID: TReplyMessageCell_ReuseId)
        bindMessageCellClass(TUIReferenceMessageCell_Minimalist.self, cellDataClass: TUIReferenceMessageCellData.self, reuseID: TUIReferenceMessageCell_ReuseId)

        TUIMessageCellConfig_Minimalist.enumerateCustomMessageInfo { [weak self] messageCellName, messageCellDataName, businessID, _ in
            guard let cellClass = NSClassFromString(messageCellName),
                  let cellDataClass = NSClassFromString(messageCellDataName) else { return }
            self?.bindMessageCellClass(cellClass, cellDataClass: cellDataClass, reuseID: businessID)
        }
    }

    func bindMessageCellClass(_ cellClass: AnyClass?, cellDataClass: AnyClass?, reuseID: String?) {
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

extension TUIMessageCellConfig_Minimalist {
    // MARK: - CustomMessageRegister

    static func registerBuiltInCustomMessageInfo() {
        registerCustomMessageCell("TUIChat.TUILinkCell_Minimalist", messageCellData: "TUIChat.TUILinkCellData", forBusinessID: BussinessID_TextLink)
        registerCustomMessageCell("TUIChat.TUIGroupCreatedCell_Minimalist", messageCellData: "TUIChat.TUIGroupCreatedCellData", forBusinessID: BussinessID_GroupCreate)
        registerCustomMessageCell("TUIChat.TUIEvaluationCell_Minimalist", messageCellData: "TUIChat.TUIEvaluationCellData", forBusinessID: BussinessID_Evaluation)
        registerCustomMessageCell("TUIChat.TUIOrderCell_Minimalist", messageCellData: "TUIChat.TUIOrderCellData", forBusinessID: BussinessID_Order)
        registerCustomMessageCell("TUIMessageCell_Minimalist", messageCellData: "TUIChat.TUITypingStatusCellData", forBusinessID: BussinessID_Typing)
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
        info[BussinessID] = businessID
        info[TMessageCell_Name] = messageCellName
        info[TMessageCell_Data_Name] = messageCellData
        info[kIsCustomMessageFromPlugin] = isPlugin

        gCustomMessageInfoMap[businessID] = info
    }

    static func enumerateCustomMessageInfo(_ callback: @escaping (String, String, String, Bool) -> Void) {
        for (_, info) in gCustomMessageInfoMap {
            guard let businessID = info[BussinessID] as? String,
                  let messageCellName = info[TMessageCell_Name] as? String,
                  let messageCellDataName = info[TMessageCell_Data_Name] as? String,
                  let isPlugin = info[kIsCustomMessageFromPlugin] as? Bool else { continue }
            callback(messageCellName, messageCellDataName, businessID, isPlugin)
        }
    }

    static func getCustomMessageCellDataClass(_ businessID: String) -> AnyClass? {
        guard let info = gCustomMessageInfoMap[businessID],
              let messageCellDataName = info[TMessageCell_Data_Name] as? String
        else {
            return nil
        }
        return NSClassFromString(messageCellDataName)
    }

    static func isPluginCustomMessageCellData(_ data: TUIMessageCellData) -> Bool {
        var flag = false
        for (_, info) in gCustomMessageInfoMap {
            if let businessID = info[BussinessID] as? String,
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
        return msg.msgID.isEmpty ? String(format: "%p", msg) : msg.msgID
    }

    static var screenWidth: CGFloat = 0
    func getHeightFromMessageCellData(_ cellData: TUIMessageCellData?) -> CGFloat {
        guard let cellData = cellData else { return 0 }
        if TUIMessageCellConfig_Minimalist.screenWidth == 0 {
            TUIMessageCellConfig_Minimalist.screenWidth = TUISwift.screen_Width()
        }
        let key = getHeightCacheKey(cellData)
        if let height = heightCacheMaps[key], height != 0 {
            return height
        }
        if let cellClass = cellClassMaps[String(describing: type(of: cellData))] {
            let height = cellClass.getHeight(cellData, withWidth: TUIMessageCellConfig_Minimalist.screenWidth)
            heightCacheMaps[key] = height
            return height
        }
        return 0
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
