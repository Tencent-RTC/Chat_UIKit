import TIMCommon
import TUICore
import UIKit

public class TUITextMessageCellData: TUIBubbleMessageCellData {
    public var isAudioCall: Bool = false
    public var isVideoCall: Bool = false
    public var isCaller: Bool = false
    public var showUnreadPoint: Bool = false

    public var emojiLocations: [[NSValue: NSAttributedString]]? = []
    public var textSize: CGSize = .zero
    public var textOrigin: CGPoint = .zero

    private var attributedString: NSMutableAttributedString?
    private var size: CGSize = .zero
    private var containerWidth: CGFloat = 0.0

    public var content: String = "" {
        didSet {
            if oldValue != content {
                attributedString = nil
            }
        }
    }

    override init(direction: TMsgDirection) {
        super.init(direction: direction)
        if direction == .incoming {
            self.cellLayout = TUIMessageCellLayout.incomingTextMessageLayout
        } else {
            self.cellLayout = TUIMessageCellLayout.outgoingTextMessageLayout
        }
    }

    required init() {
        fatalError("init() has not been implemented")
    }

    public override class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        let textData = TUITextMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        if let textElem = message.textElem {
            textData.content = textElem.text ?? ""
        }
        textData.reuseId = "TTextMessageCell"
        textData.status = .initStatus
        return textData
    }

    public override class func getDisplayString(message: V2TIMMessage) -> String {
        if let textElem = message.textElem, let text = textElem.text {
            return text.getLocalizableStringWithFaceContent()
        }
        return ""
    }

    public override func getReplyQuoteViewDataClass() -> AnyClass? {
        return NSClassFromString("TUIChat.TUITextReplyQuoteViewData")
    }

    public override func getReplyQuoteViewClass() -> AnyClass? {
        return NSClassFromString("TUIChat.TUITextReplyQuoteView")
    }

    func getContentAttributedString(textFont: UIFont) -> NSAttributedString {
        if attributedString == nil {
            emojiLocations = []
            attributedString = content.getFormatEmojiString(withFont: textFont, emojiLocations: &emojiLocations)
            if isAudioCall || isVideoCall {
                let attachment = NSTextAttachment()
                var image: UIImage?
                if isAudioCall {
                    image = TUISwift.tuiChatCommonBundleImage("audio_call")
                }
                if isVideoCall {
                    image = isCaller ? TUISwift.tuiChatCommonBundleImage("video_call_self") : TUISwift.tuiChatCommonBundleImage("video_call")
                }
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: -(textFont.lineHeight - textFont.pointSize) / 2, width: 16, height: 16)
                let imageString = NSAttributedString(attachment: attachment)
                let spaceString = NSAttributedString(string: "  ", attributes: [.font: textFont])
                if isCaller {
                    attributedString?.append(spaceString)
                    attributedString?.append(imageString)
                } else {
                    attributedString?.insert(spaceString, at: 0)
                    attributedString?.insert(imageString, at: 0)
                }
            }
        }
        return attributedString ?? NSAttributedString()
    }

    func getContentAttributedStringSize(attributeString: NSAttributedString, maxTextSize: CGSize) -> CGSize {
        let rect = attributeString.boundingRect(with: maxTextSize, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let width = ceil(rect.size.width)
        let height = ceil(rect.size.height)
        return CGSize(width: width, height: height)
    }
}
