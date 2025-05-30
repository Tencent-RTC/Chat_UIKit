import Foundation
import TIMCommon
import UIKit

public class TUILinkCellData: TUIBubbleMessageCellData {
    var text: String = ""
    var link: String = ""

    override public class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        guard let data = message.customElem?.data,
              let param = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        else {
            return TUILinkCellData(direction: .incoming)
        }

        let cellData = TUILinkCellData(direction: message.isSelf ? .outgoing : .incoming)
        cellData.msgID = message.msgID
        cellData.text = param["text"] as? String ?? ""
        cellData.link = param["link"] as? String ?? ""
        cellData.avatarUrl = URL(string: message.faceURL ?? "")
        return cellData
    }

    override public class func getDisplayString(message: V2TIMMessage) -> String {
        guard let data = message.customElem?.data,
              let param = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
        else {
            return ""
        }
        return param["text"] as? String ?? ""
    }

    func contentSize() -> CGSize {
        let textMaxWidth: CGFloat = 245.0
        let rect = text.boundingRect(
            with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 15)],
            context: nil
        )
        return CGSize(width: textMaxWidth + 15, height: rect.height + 56)
    }
}
