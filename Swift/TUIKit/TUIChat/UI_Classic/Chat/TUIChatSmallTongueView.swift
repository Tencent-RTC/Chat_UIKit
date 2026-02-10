import TIMCommon
import TUICore
import UIKit

let kTongueHeight: CGFloat = 35
let kTongueImageWidth: CFloat = 12
let kTongueImageHeight: CGFloat = 12
let kTongueLeftSpace: CGFloat = 10
let kTongueMiddleSpace: CGFloat = 5
let kTongueRightSpace: CGFloat = 10
let kTongueFontSize: CGFloat = 13

@objc class TUIChatSmallTongue: NSObject {
    var type: TUIChatSmallTongueType = .none
    var parentView: UIView?
    var unreadMsgCount: Int = 0
    var atMsgSeqs: [Int] = []
    var atTipsStr: String?
}

@objc protocol TUIChatSmallTongueViewDelegate: NSObjectProtocol {
    @objc optional func onChatSmallTongueClick(_ tongue: TUIChatSmallTongue)
}

public class TUIChatSmallTongueView: UIView {
    weak var delegate: TUIChatSmallTongueViewDelegate?
    private var tongue: TUIChatSmallTongue?
    private var imageView: UIImageView?
    private var label: UILabel?

    @objc public class func swiftLoad() {

    }

    @objc public class func onThemeChanged() {
        gImageCache = nil
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = TUISwift.tuiChatDynamicColor("chat_small_tongue_bg_color", defaultColor: "#FFFFFF")
        // border
        layer.borderWidth = 0.2
        layer.borderColor = TUISwift.tuiChatDynamicColor("chat_small_tongue_line_color", defaultColor: "#E5E5E5").cgColor
        layer.cornerRadius = 2
        layer.masksToBounds = true

        // shadow
        layer.shadowColor = TUISwift.rgba(0, g: 0, b: 0, a: 0.15).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = .zero
        layer.shadowRadius = 2
        clipsToBounds = false

        // tap
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        addGestureRecognizer(tap)
    }

    @objc private func onTap() {
        guard let tongue = tongue else { return }
        delegate?.onChatSmallTongueClick?(tongue)
    }

    func setTongue(_ tongue: TUIChatSmallTongue?) {
        self.tongue = tongue
        if imageView == nil {
            imageView = UIImageView()
            addSubview(imageView!)
        }
        imageView?.image = TUIChatSmallTongueView.getTongueImage(tongue)

        if label == nil {
            label = UILabel()
            label?.font = UIFont.systemFont(ofSize: kTongueFontSize)
            addSubview(label!)
        }
        label?.text = TUIChatSmallTongueView.getTongueText(tongue)
        label?.textAlignment = .natural // Assuming TUITextRTLAlignmentLeading maps to .natural
        label?.textColor = TUISwift.tuiChatDynamicColor("chat_drop_down_color", defaultColor: "#147AFF")

        imageView?.snp.remakeConstraints { make in
            make.width.height.equalTo(kTongueImageWidth)
            make.leading.equalTo(kTongueLeftSpace)
            make.top.equalTo(10)
        }

        label?.snp.remakeConstraints { make in
            make.trailing.lessThanOrEqualTo(self.snp.trailing).offset(-kTongueRightSpace)
            make.height.equalTo(kTongueImageHeight)
            make.leading.equalTo(imageView!.snp.trailing).offset(kTongueMiddleSpace)
            make.top.equalTo(10)
        }
    }

    static func getTongueWidth(_ tongue: TUIChatSmallTongue?) -> CGFloat {
        let tongueText = getTongueText(tongue)
        let titleSize = (tongueText as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: kTongueHeight),
            options: .usesLineFragmentOrigin,
            attributes: [.font: UIFont.systemFont(ofSize: kTongueFontSize)],
            context: nil
        ).size
        let imageWidth = kTongueLeftSpace + CGFloat(kTongueImageWidth) + kTongueMiddleSpace
        let tongueWidth = imageWidth + ceil(titleSize.width) + kTongueRightSpace
        return tongueWidth
    }

    static var titleCacheFormat: [Int: String]?
    static func getTongueText(_ tongue: TUIChatSmallTongue?) -> String {
        guard let tongue = tongue else { return "" }
        if titleCacheFormat == nil {
            titleCacheFormat = [Int: String]()
            titleCacheFormat?[TUIChatSmallTongueType.scrollToBoom.rawValue] = TUISwift.timCommonLocalizableString("TUIKitChatBackToLatestLocation")
            titleCacheFormat?[TUIChatSmallTongueType.receiveNewMsg.rawValue] = TUISwift.timCommonLocalizableString("TUIKitChatNewMessages")
        }

        if tongue.type == .someoneAt {
            var atMeStr = TUISwift.timCommonLocalizableString("TUIKitConversationTipsAtMe")
            var atAllStr = TUISwift.timCommonLocalizableString("TUIKitConversationTipsAtAll")
            if let atTipsStr = tongue.atTipsStr {
                if atTipsStr.contains(atMeStr) {
                    atMeStr = atMeStr.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    titleCacheFormat?[TUIChatSmallTongueType.someoneAt.rawValue] = atMeStr
                } else if atTipsStr.contains(atAllStr) {
                    atAllStr = atAllStr.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
                    titleCacheFormat?[TUIChatSmallTongueType.someoneAt.rawValue] = atAllStr
                }
            }
        }

        if tongue.type == .receiveNewMsg {
            let unreadCount = tongue.unreadMsgCount > 99 ? "99+" : "\(tongue.unreadMsgCount)"
            return String(format: titleCacheFormat?[TUIChatSmallTongueType.receiveNewMsg.rawValue] ?? "", unreadCount)
        } else {
            return titleCacheFormat?[tongue.type.rawValue] ?? ""
        }
    }

    static var gImageCache: [Int: UIImage]?
    static func getTongueImage(_ tongue: TUIChatSmallTongue?) -> UIImage {
        guard let tongue = tongue else { return UIImage() }
        if gImageCache == nil {
            gImageCache = [Int: UIImage]()
            gImageCache?[TUIChatSmallTongueType.scrollToBoom.rawValue] = TUISwift.tuiChatBundleThemeImage("chat_drop_down_img", defaultImage: "drop_down")
            gImageCache?[TUIChatSmallTongueType.receiveNewMsg.rawValue] = TUISwift.tuiChatBundleThemeImage("chat_drop_down_img", defaultImage: "drop_down")
            gImageCache?[TUIChatSmallTongueType.someoneAt.rawValue] = TUISwift.tuiChatBundleThemeImage("chat_pull_up_img", defaultImage: "pull_up")
        }
        return gImageCache?[tongue.type.rawValue] ?? UIImage()
    }
}

class TUIChatSmallTongueManager {
    private static var gTongueView: TUIChatSmallTongueView?
    private static var gTongue: TUIChatSmallTongue?
    private static var gBottomMargin: CGFloat = 0

    static func showTongue(_ tongue: TUIChatSmallTongue, delegate:
        TUIChatSmallTongueViewDelegate?)
    {
        if let gTongue = gTongue,
           tongue.type == gTongue.type,
           tongue.parentView == gTongue.parentView,
           tongue.unreadMsgCount == gTongue.unreadMsgCount,
           tongue.atMsgSeqs == gTongue.atMsgSeqs,
           !(gTongueView?.isHidden ?? false)
        {
            return
        }
        gTongue = tongue

        if let gTongueView = gTongueView {
            gTongueView.removeFromSuperview()
        } else {
            gTongueView = TUIChatSmallTongueView()
        }

        let tongueWidth = TUIChatSmallTongueView.getTongueWidth(gTongue)

        let margin = TUISwift.bottom_SafeHeight() + CGFloat(TTextView_Height) + 20 + kTongueHeight + gBottomMargin
        let y = tongue.parentView!.mm_h - margin
        if TUISwift.isRTL() {
            let frame = CGRect(x: 16,
                               y: y,
                               width: tongueWidth,
                               height: kTongueHeight)
            gTongueView!.frame = frame
        } else {
            let frame = CGRect(x: tongue.parentView!.mm_w - tongueWidth - 16,
                               y: y,
                               width: tongueWidth,
                               height: kTongueHeight)
            gTongueView!.frame = frame
        }

        gTongueView!.delegate = delegate
        gTongueView!.setTongue(gTongue)
        tongue.parentView?.addSubview(gTongueView!)
    }

    static func removeTongue(type: TUIChatSmallTongueType) {
        if type != gTongue?.type {
            return
        }
        removeTongue()
    }

    static func removeTongue() {
        gTongue = nil
        gTongueView?.removeFromSuperview()
        gTongueView = nil
    }

    static func hideTongue(_ isHidden: Bool) {
        gTongueView?.isHidden = isHidden
    }

    static func adaptTongueBottomMargin(_ margin: CGFloat) {
        gBottomMargin = margin
    }
}
