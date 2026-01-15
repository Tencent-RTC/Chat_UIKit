import TIMCommon
import UIKit

public class TUIReplyMessageCell_Minimalist: TUIBubbleMessageCell_Minimalist, UITextViewDelegate, TUITextViewDelegate {
    var replyData: TUIReplyMessageCellData?
    var currentOriginView: TUIReplyQuoteView_Minimalist?

    lazy var senderLabel: UILabel = {
        let label = UILabel()
        label.text = "Alice:"
        label.font = UIFont.boldSystemFont(ofSize: 12.0)
        label.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_sender_text_color", defaultColor: "#888888")
        label.textAlignment = TUISwift.isRTL() ? .right : .left
        return label
    }()

    lazy var quoteView: UIView = {
        let view = UIView()
        view.backgroundColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_bg_color", defaultColor: "#4444440c")
        return view
    }()

    lazy var quoteBorderLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 68 / 255.0, green: 68 / 255.0, blue: 68 / 255.0, alpha: 0.1)
        return view
    }()

    lazy var textView: TUITextView = {
        textView = TUITextView()
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets.zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.delegate = self
        textView.tuiTextViewDelegate = self
        textView.font = UIFont.systemFont(ofSize: 16.0)
        textView.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_content_text_color", defaultColor: "#000000")
        return textView
    }()

    lazy var customOriginViewsCache: [String: TUIReplyQuoteView_Minimalist] = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        quoteView.addSubview(senderLabel)
        quoteView.addSubview(quoteBorderLine)

        bubbleView.addSubview(quoteView)
        bubbleView.addSubview(textView)

        bottomContainer = UIView()
        contentView.addSubview(bottomContainer)

        topContainer = UIView()
        topContainer.isUserInteractionEnabled = true
        contentView.addSubview(topContainer)
    }

    override public func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        guard let replyData = replyData else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_TopContainer_CellData": replyData]
        let hasExtension = TUICore.raiseExtension("TUICore_TUIChatExtension_TopContainer_MinimalistExtensionID", parentView: topContainer, param: param)
        topContainer.isHidden = !hasExtension

        if hasExtension {
            layoutTopContainer()
        }
    }

    override public func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_BottomContainer_CellData": replyData as Any]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID", parentView: bottomContainer, param: param)
    }

    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIReplyMessageCellData else { return }

        replyData = data
        senderLabel.text = "\(data.sender ?? ""):"
        if data.direction == .incoming {
            textView.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_content_recv_text_color", defaultColor: "#000000")
            senderLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_recv_text_color", defaultColor: "#888888")
            quoteView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_bg_color", defaultColor: "#4444440c")
        } else {
            textView.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_content_text_color", defaultColor: "#000000")
            senderLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_text_color", defaultColor: "#888888")
            quoteView.backgroundColor = UIColor.tui_color(withHex: "#6868680c")
        }

        if let font = textView.font {
            var emojiLocations = replyData?.emojiLocations
            let attrStr: NSAttributedString = data.content.getFormatEmojiString(withFont: font, emojiLocations: &emojiLocations)
            if let location = emojiLocations {
                replyData?.emojiLocations = location
            }
            textView.attributedText = attrStr
        }

        bottomContainer.isHidden = CGSizeEqualToSize(data.bottomContainerSize, CGSize.zero)

        data.onOriginMessageChange = { [weak self] _ in
            guard let self = self else { return }
            self.setNeedsUpdateConstraints()
            self.updateConstraintsIfNeeded()
            self.layoutIfNeeded()
        }

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override public func updateConstraints() {
        super.updateConstraints()
        updateUI(replyData)
        layoutBottomContainer()
        layoutTopContainer()
    }

    private func layoutTopContainer() {
        guard !topContainer.isHidden else { return }
        guard let replyData = replyData else { return }

        let topContainerSize = replyData.topContainerSize
        guard topContainerSize.width > 0 && topContainerSize.height > 0 else {
            topContainer.isHidden = true
            return
        }

        // Position topContainer at top-right corner of bubbleView
        topContainer.snp.remakeConstraints { make in
            make.trailing.equalTo(bubbleView.snp.trailing)
            make.centerY.equalTo(bubbleView.snp.top)
            make.size.equalTo(topContainerSize)
        }
    }

    private func updateUI(_ replyData: TUIReplyMessageCellData?) {
        currentOriginView = getCustomOriginView(replyData?.originCellData)
        hiddenAllCustomOriginViews(true)
        currentOriginView?.isHidden = false

        guard let replyData = replyData else { return }

        replyData.quoteData?.supportForReply = true
        replyData.quoteData?.showRevokedOriginMessage = replyData.showRevokedOriginMessage
        if let quoteData = replyData.quoteData {
            currentOriginView?.fill(with: quoteData)
        }

        quoteView.snp.remakeConstraints { make in
            make.leading.equalTo(bubbleView).offset(16)
            make.top.equalTo(12)
            make.trailing.equalTo(bubbleView).offset(-16)
            make.height.equalTo(replyData.quoteSize.height)
        }

        quoteBorderLine.snp.remakeConstraints { make in
            make.leading.top.bottom.equalTo(quoteView)
            make.width.equalTo(3)
        }

        textView.snp.remakeConstraints { make in
            make.leading.equalTo(quoteView).offset(4)
            make.top.equalTo(quoteView.snp.bottom).offset(12)
            make.trailing.equalTo(quoteView).offset(-4)
            make.bottom.equalTo(bubbleView).offset(-4)
        }

        senderLabel.snp.remakeConstraints { make in
            make.leading.equalTo(textView)
            make.top.equalTo(3)
            make.size.equalTo(replyData.senderSize)
        }

        let hideSenderLabel = (replyData.originCellData?.innerMessage?.status == .MSG_STATUS_LOCAL_REVOKED) && !replyData.showRevokedOriginMessage
        senderLabel.isHidden = hideSenderLabel

        currentOriginView?.snp.remakeConstraints { make in
            make.leading.equalTo(senderLabel)
            if hideSenderLabel {
                make.centerY.equalTo(quoteView)
            } else {
                make.top.equalTo(senderLabel.snp.bottom).offset(4)
            }
            make.trailing.lessThanOrEqualTo(quoteView)
            make.height.equalTo(replyData.quotePlaceholderSize)
        }
    }

    private func getCustomOriginView(_ originCellData: TUIMessageCellData?) -> TUIReplyQuoteView_Minimalist {
        let reuseId = originCellData != nil ? String(describing: type(of: originCellData!)) : String(describing: TUITextMessageCellData.self)
        var view: TUIReplyQuoteView_Minimalist? = nil
        var reuse = false

        if let cachedView = customOriginViewsCache[reuseId] {
            view = cachedView
            reuse = true
        }

        if view == nil {
            var classType: AnyClass? = originCellData?.getReplyQuoteViewClass()
            var clsStr = classType.map { String(describing: $0) } ?? ""
            if !clsStr.isEmpty && !clsStr.contains("_Minimalist") {
                clsStr = "TUIChat." + clsStr + "_Minimalist"
                classType = NSClassFromString(clsStr)
            }
            if let classType = classType as? TUIReplyQuoteView_Minimalist.Type {
                view = classType.init()
            }
        }

        if view == nil {
            view = TUITextReplyQuoteView_Minimalist()
        }

        if let quoteView = view as? TUITextReplyQuoteView_Minimalist {
            quoteView.textLabel.textColor = (replyData?.direction == .incoming) ? TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_recv_text_color", defaultColor: "#888888") : TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_text_color", defaultColor: "#888888")
        } else if let quoteView = view as? TUIMergeReplyQuoteView_Minimalist {
            quoteView.titleLabel.textColor = (replyData?.direction == .incoming) ? TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_recv_text_color", defaultColor: "#888888") : TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_text_color", defaultColor: "#888888")
        }

        if !reuse {
            customOriginViewsCache[reuseId] = view
            quoteView.addSubview(view!)
        }

        view?.isHidden = true
        return view!
    }

    private func hiddenAllCustomOriginViews(_ hidden: Bool) {
        for (_, view) in customOriginViewsCache {
            view.isHidden = hidden
            view.reset()
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        // Use frame-based layout for messageModifyRepliesButton to avoid constraint update loop
        layoutMessageModifyRepliesButton()
    }

    private func layoutMessageModifyRepliesButton() {
        guard let replyData = replyData else { return }
        guard !CGSizeEqualToSize(replyData.bottomContainerSize, CGSize.zero) else { return }
        
        if !messageModifyRepliesButton.isHidden {
            let oldRect = messageModifyRepliesButton.frame
            let newRect = CGRect(x: oldRect.origin.x, y: bottomContainer.frame.maxY, width: oldRect.size.width, height: oldRect.size.height)
            messageModifyRepliesButton.frame = newRect
        }

        for view in replyAvatarImageViews {
            let oldRect = view.frame
            view.frame = CGRect(x: oldRect.origin.x, y: bottomContainer.frame.maxY + 5, width: oldRect.size.width, height: oldRect.size.height)
        }
    }

    private func layoutBottomContainer() {
        guard let replyData = replyData else { return }
        guard !CGSizeEqualToSize(replyData.bottomContainerSize, CGSize.zero) else {
            return
        }

        let size = replyData.bottomContainerSize
        bottomContainer.snp.remakeConstraints { make in
            if replyData.direction == .incoming {
                make.leading.equalTo(container)
            } else {
                make.trailing.equalTo(container)
            }
            make.top.equalTo(bubbleView.snp.bottom).offset((messageData?.messageContainerAppendSize.height ?? 0) + 6)
            make.size.equalTo(size)
        }
    }

    // MARK: - TUITextViewDelegate

    public func onLongPressTextViewMessage(_ textView: UITextView) {
        delegate?.onLongPressMessage(self)
    }

    // MARK: - TUIMessageCellProtocol

    override public class func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat {
        guard let data = data as? TUIReplyMessageCellData else {
            assertionFailure("data must be kind of TUIReplyMessageCellData")
            return CGFloat.zero
        }
        var height = super.getHeight(data, withWidth: width)
        if data.bottomContainerSize.height > 0 {
            height += data.bottomContainerSize.height + 6
        }
        return height
    }

    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let replyCellData = data as? TUIReplyMessageCellData else {
            assertionFailure("data must be kind of TUIReplyMessageCellData")
            return CGSize.zero
        }

        var height: CGFloat = 0
        var quoteHeight: CGFloat = 0
        var quoteWidth: CGFloat = 0

        let quoteMinWidth: CGFloat = 100
        let quoteMaxWidth = CGFloat(TReplyQuoteView_Max_Width)
        let quotePlaceHolderMarginWidth: CGFloat = 12

        // Calculate the size of label which displays the sender's display name
        let senderFont = UIFont.boldSystemFont(ofSize: 12.0)
        let senderSize = "0".size(withAttributes: [.font: senderFont])
        let senderRect = replyCellData.sender?.boundingRect(with: CGSize(width: quoteMaxWidth, height: senderSize.height),
                                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                            attributes: [.font: senderFont],
                                                            context: nil)

        var messageRevokeRect = CGRect.zero
        let showRevokeStr = (replyCellData.originCellData?.innerMessage?.status == .MSG_STATUS_LOCAL_REVOKED) &&
            !replyCellData.showRevokedOriginMessage
        if showRevokeStr {
            let msgRevokeStr = TUISwift.timCommonLocalizableString("TUIKitRepliesOriginMessageRevoke")
            messageRevokeRect = msgRevokeStr.boundingRect(with: CGSize(width: quoteMaxWidth, height: senderSize.height),
                                                          options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                          attributes: [.font: senderFont],
                                                          context: nil)
        }

        // Calculate the size of customize quote placeholder view
        let placeholderSize = replyCellData.quotePlaceholderSizeWithType(type: replyCellData.originMsgType, data: replyCellData.quoteData)

        // Calculate the size of label which displays the content of replying to the original message
        let font = UIFont.systemFont(ofSize: 16.0)
        var locations: [[NSValue: NSAttributedString]]? = nil
        let attributeString = replyCellData.content.getFormatEmojiString(withFont: font, emojiLocations: &locations)
        let replyContentRect = attributeString.boundingRect(with: CGSize(width: quoteMaxWidth, height: CGFloat(Int.max)),
                                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                            context: nil)

        // Calculate the size of quote view based on the content
        quoteWidth = senderRect?.size.width ?? 0
        if quoteWidth < placeholderSize.width {
            quoteWidth = placeholderSize.width
        }
        if quoteWidth < replyContentRect.size.width {
            quoteWidth = replyContentRect.size.width
        }
        quoteWidth += quotePlaceHolderMarginWidth
        if quoteWidth > quoteMaxWidth {
            quoteWidth = quoteMaxWidth
        }
        if quoteWidth < quoteMinWidth {
            quoteWidth = quoteMinWidth
        }

        quoteHeight = 3 + (senderRect?.size.height ?? 0) + 4 + placeholderSize.height + 6

        if showRevokeStr {
            quoteWidth = max(quoteWidth, messageRevokeRect.size.width)
            quoteHeight = 3 + 4 + messageRevokeRect.size.height + 6
        }

        replyCellData.senderSize = CGSize(width: quoteWidth, height: (senderRect?.size.height ?? 0))
        replyCellData.quotePlaceholderSize = placeholderSize
        replyCellData.replyContentSize = CGSize(width: replyContentRect.size.width, height: replyContentRect.size.height)
        replyCellData.quoteSize = CGSize(width: quoteWidth, height: quoteHeight)

        // Calculate the height of cell
        height = 12 + quoteHeight + 12 + replyCellData.replyContentSize.height + 12

        let replyContentRect2 = attributeString.boundingRect(with: CGSize(width: CGFloat(Int.max), height: font.lineHeight),
                                                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                             context: nil)

        // Determine whether the width of the last line exceeds the position of the message status. If it exceeds, the message status will be wrapped.
        if replyContentRect2.size.width.truncatingRemainder(dividingBy: quoteWidth) == 0 ||
            replyContentRect2.size.width.truncatingRemainder(dividingBy: quoteWidth) + replyCellData.msgStatusSize.width > quoteWidth
        {
            height += replyCellData.msgStatusSize.height
        }

        return CGSize(width: quoteWidth + CGFloat(TReplyQuoteView_Margin_Width), height: height)
    }
}
