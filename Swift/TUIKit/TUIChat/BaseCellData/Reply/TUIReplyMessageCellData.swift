import Foundation
import ImSDK_Plus
import TIMCommon
import UIKit

class TUIReplyMessageCellData: TUIBubbleMessageCellData {
    var originMsgID: String?
    var msgAbstract: String?
    var sender: String?
    var faceURL: String?
    var originMsgType: V2TIMElemType = .ELEM_TYPE_NONE
    var originCellData: TUIMessageCellData?
    var quoteData: TUIReplyQuoteViewData?
    var showRevokedOriginMessage: Bool = false
    var content: String = ""
    var attributeString: NSAttributedString {
        return NSAttributedString(string: content)
    }

    var quoteSize: CGSize = .zero
    var senderSize: CGSize = .zero
    var quotePlaceholderSize: CGSize = .zero
    var replyContentSize: CGSize = .zero
    var onFinish: TUIReplyAsyncLoadFinish?
    var textColor: UIColor = .black
    var selectContent: String? = ""
    var emojiLocations: [[NSValue: NSAttributedString]] = []

    var onOriginMessageChange: ((V2TIMMessage?) -> Void)?
    var originMessage: V2TIMMessage? {
        didSet {
            onOriginMessageChange?(originMessage)
        }
    }

    override init(direction: TMsgDirection) {
        super.init(direction: direction)
        if direction == .incoming {
            self.cellLayout = TUIMessageCellLayout.incomingTextMessageLayout
        } else {
            self.cellLayout = TUIMessageCellLayout.outgoingTextMessageLayout
        }
        self.emojiLocations = []
    }

    override class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        guard let quoteInfo = message.quoteInfo,
              let originMsgID = quoteInfo.msgID, !originMsgID.isEmpty
        else {
            return TUIReplyMessageCellData(direction: .incoming)
        }

        let replyData = TUIReplyMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        replyData.reuseId = "TUIReplyMessageCell"
        replyData.originMsgID = originMsgID
        replyData.msgAbstract = ""
        replyData.sender = ""
        replyData.originMsgType = .ELEM_TYPE_NONE
        replyData.content = message.textElem?.text ?? ""
        return replyData
    }

    func updateQuoteInfo(from originCellData: TUIMessageCellData?, originMessage: V2TIMMessage?) {
        guard let originMessage = originMessage else { return }
        if (sender ?? "").isEmpty {
            sender = originCellData?.senderName.isEmpty == false
                ? originCellData?.senderName
                : (originMessage.nameCard ?? originMessage.friendRemark ?? originMessage.nickName ?? originMessage.sender ?? "")
        }
        if (msgAbstract ?? "").isEmpty {
            msgAbstract = TUIMessageDataProvider.getDisplayString(message: originMessage) ?? ""
        }
        originMsgType = originMessage.elemType
    }

    func quotePlaceholderSizeWithType(type: V2TIMElemType, data: TUIReplyQuoteViewData?) -> CGSize {
        guard let data = data else {
            return CGSize(width: 20, height: 20)
        }
        return data.contentSize(maxWidth: CGFloat(TReplyQuoteView_Max_Width) - 12)
    }

    func getQuoteData(originCellData: TUIMessageCellData?) -> TUIReplyQuoteViewData? {
        var quoteData: TUIReplyQuoteViewData? = nil
        if let classType = originCellData?.getReplyQuoteViewDataClass() {
            let hasRiskContent = originCellData?.innerMessage?.hasRiskContent ?? false
            if hasRiskContent && TIMConfig.isClassicEntrance() {
                let myData = TUITextReplyQuoteViewData()
                myData.text = TUIReplyPreviewData.displayAbstract(type: originMsgType, abstract: msgAbstract ?? "", withFileName: false, isRisk: hasRiskContent)
                quoteData = myData
            } else if let classType = classType as? TUIReplyQuoteViewData.Type {
                quoteData = classType.getReplyQuoteViewData(originCellData: originCellData)
            }
        }
        if quoteData == nil {
            let myData = TUITextReplyQuoteViewData()
            myData.text = TUIReplyPreviewData.displayAbstract(type: originMsgType, abstract: msgAbstract ?? "", withFileName: false, isRisk: false)
            quoteData = myData
        }

        quoteData?.originCellData = originCellData
        quoteData?.onFinish = { [weak self] in
            self?.onFinish?()
        }
        return quoteData
    }
}

class TUIReferenceMessageCellData: TUIReplyMessageCellData {
    var textSize: CGSize = .zero
    var textOrigin: CGPoint = .zero

    override class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        guard let quoteInfo = message.quoteInfo,
              let originMsgID = quoteInfo.msgID, !originMsgID.isEmpty
        else {
            return TUIReferenceMessageCellData(direction: .incoming)
        }

        let referenceData = TUIReferenceMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        referenceData.reuseId = TUIReferenceMessageCell_ReuseId
        referenceData.originMsgID = originMsgID
        referenceData.msgAbstract = ""
        referenceData.sender = ""
        referenceData.originMsgType = .ELEM_TYPE_NONE
        referenceData.content = message.textElem?.text ?? ""
        return referenceData
    }
}
