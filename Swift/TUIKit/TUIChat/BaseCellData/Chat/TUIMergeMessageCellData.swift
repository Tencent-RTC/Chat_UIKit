import Foundation
import TIMCommon

class TUIMergeMessageCellData: TUIMessageCellData {
    var title: String?
    var abstractList: [String]?
    var mergerElem: V2TIMMergerElem?
    var abstractSize: CGSize = .zero
    var abstractRow1Size: CGSize = .zero
    var abstractRow2Size: CGSize = .zero
    var abstractRow3Size: CGSize = .zero
    var abstractSendDetailList: [[String: NSAttributedString]] = []

    override class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        guard let elem = message.mergerElem else { return TUITextMessageCellData(direction: .incoming) }
        if elem.layersOverLimit {
            let limitCell = TUITextMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
            limitCell.content = TUISwift.timCommonLocalizableString("TUIKitRelayLayerLimitTips")
            return limitCell
        }

        let mergeData = TUIMergeMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        mergeData.title = elem.title
        if let abstractList = elem.abstractList {
            mergeData.abstractList = abstractList
            mergeData.abstractSendDetailList = formatAbstractSendDetailList(originAbstractList: abstractList)
        }
        mergeData.mergerElem = elem
        mergeData.reuseId = "TMergeMessageCell"
        return mergeData
    }

    override class func getDisplayString(message: V2TIMMessage) -> String {
        return "[\(TUISwift.timCommonLocalizableString("TUIKitRelayChatHistory"))]"
    }

    override func getReplyQuoteViewDataClass() -> AnyClass? {
        return NSClassFromString("TUIChat.TUIMergeReplyQuoteViewData")
    }

    override func getReplyQuoteViewClass() -> AnyClass? {
        return NSClassFromString("TUIChat.TUIMergeReplyQuoteView")
    }

    func abstractAttributedString() -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 4
        style.alignment = TUISwift.isRTL() ? .right : .left
        let attribute: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(red: 187 / 255.0, green: 187 / 255.0, blue: 187 / 255.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 12.0),
            .paragraphStyle: style
        ]

        let abstr = NSMutableAttributedString(string: "")
        guard let abstractList = abstractList else { return NSAttributedString() }
        for (i, ab) in abstractList.enumerated() where i < 4 {
            let resultStr = "\(ab)\n"
            let str = resultStr
            abstr.append(NSAttributedString(string: str, attributes: attribute))
        }
        return abstr
    }

    static func formatAbstractSendDetailList(originAbstractList: [String]) -> [[String: NSAttributedString]] {
        var array: [[String: NSAttributedString]] = []
        let style = NSMutableParagraphStyle()
        style.alignment = TUISwift.isRTL() ? .right : .left
        style.lineBreakMode = .byTruncatingTail
        let attribute: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(red: 187 / 255.0, green: 187 / 255.0, blue: 187 / 255.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 12.0),
            .paragraphStyle: style
        ]

        for (i, ab) in originAbstractList.enumerated() where i < 4 {
            let str = ab
            var splitStr = ":"
            if str.contains("\u{202C}:") {
                splitStr = "\u{202C}:"
            }
            let result = str.components(separatedBy: splitStr)
            var sender = ""
            var detail = ""
            if result.count > 0 {
                sender = result[0]
            }
            if result.count > 1 {
                detail = result[1].getLocalizableStringWithFaceContent()
            }
            var dic: [String: NSAttributedString] = [:]
            if !sender.isEmpty {
                let abstr = NSMutableAttributedString(string: sender, attributes: attribute)
                dic["sender"] = abstr
            }
            if !detail.isEmpty {
                let abstr = NSMutableAttributedString(string: detail, attributes: attribute)
                dic["detail"] = abstr
            }
            array.append(dic)
        }
        return array
    }

    func isArString(text: String) -> Bool {
        let isoLangCode = CFStringTokenizerCopyBestStringLanguage(text as CFString, CFRangeMake(0, text.count)) as String?
        return isoLangCode == "ar"
    }
}
