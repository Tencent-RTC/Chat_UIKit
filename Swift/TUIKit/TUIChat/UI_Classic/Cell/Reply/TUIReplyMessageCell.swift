import TIMCommon
import UIKit

public class TUIReplyMessageCell: TUIBubbleMessageCell, UITextViewDelegate, TUITextViewDelegate {
    var replyData: TUIReplyMessageCellData?
    var currentOriginView: TUIReplyQuoteView?
    public var selectContent: String?
    var selectAllContentCallback: ((Bool) -> Void)?

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

    public lazy var textView: TUITextView = {
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

    lazy var customOriginViewsCache: [String: TUIReplyQuoteView] = .init()

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

        topContainer = TUIPassthroughView()
        topContainer.isUserInteractionEnabled = true
        topContainer.clipsToBounds = false
        contentView.addSubview(topContainer)
    }

    override public func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_BottomContainer_CellData": replyData as Any]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID", parentView: bottomContainer, param: param)
    }

    override public func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        guard let replyData = replyData else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_TopContainer_CellData": replyData]
        let hasExtension = TUICore.raiseExtension("TUICore_TUIChatExtension_TopContainer_ClassicExtensionID", parentView: topContainer, param: param)
        topContainer.isHidden = !hasExtension

        if hasExtension {
            layoutTopContainer()
        }
    }

    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIReplyMessageCellData else { return }

        replyData = data
        senderLabel.text = "\(data.sender ?? ""):"
        var location = replyData?.emojiLocations
        textView.attributedText = data.content.getFormatEmojiString(withFont: textView.font ?? UIFont(), emojiLocations: &location)
        if let location = location {
            replyData?.emojiLocations = location
        }

        bottomContainer.isHidden = data.bottomContainerSize == .zero

        if data.direction == .incoming {
            textView.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_content_recv_text_color", defaultColor: "#000000")
            senderLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_recv_text_color", defaultColor: "#888888")
            quoteView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_bg_color", defaultColor: "#4444440c")
        } else {
            textView.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_content_text_color", defaultColor: "#000000")
            senderLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_text_color", defaultColor: "#888888")
            quoteView.backgroundColor = UIColor.tui_color(withHex: "#6868680c")
        }

        var emojiLocations = replyData?.emojiLocations
        if let font = textView.font {
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

        let hasRiskContent = messageData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            textView.snp.remakeConstraints { make in
                make.leading.equalTo(quoteView).offset(4)
                make.top.equalTo(quoteView.snp.bottom).offset(12)
                make.trailing.lessThanOrEqualTo(quoteView).offset(-4)
                make.size.equalTo(replyData.replyContentSize)
            }

            securityStrikeView.snp.remakeConstraints { make in
                make.top.equalTo(textView.snp.bottom)
                make.width.equalTo(bubbleView)
                make.bottom.equalTo(container)
            }
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

    private func getCustomOriginView(_ originCellData: TUIMessageCellData?) -> TUIReplyQuoteView {
        var reuseId = originCellData != nil ? String(describing: type(of: originCellData!)) : String(describing: TUITextMessageCellData.self)
        var view: TUIReplyQuoteView? = nil
        var reuse = false

        let hasRiskContent = originCellData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            reuseId = "hasRiskContent"
        }

        if let cachedView = customOriginViewsCache[reuseId] {
            view = cachedView
            reuse = true
        }

        if hasRiskContent && view == nil {
            let quoteView = TUITextReplyQuoteView()
            view = quoteView
        }

        if view == nil {
            let classType: AnyClass? = originCellData?.getReplyQuoteViewClass()
            if let classType = classType as? TUIReplyQuoteView.Type {
                view = classType.init()
            }
        }

        if view == nil {
            view = TUITextReplyQuoteView()
        }

        if let quoteView = view as? TUITextReplyQuoteView {
            quoteView.textLabel.textColor = (replyData?.direction == .incoming) ? TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_recv_text_color", defaultColor: "#888888") : TUISwift.tuiChatDynamicColor("chat_reply_message_quoteView_text_color", defaultColor: "#888888")
        } else if let quoteView = view as? TUIMergeReplyQuoteView {
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
        updateUI(replyData)
        layoutBottomContainer()
    }

    private func layoutBottomContainer() {
        guard let replyData = replyData else { return }
        guard !CGSizeEqualToSize(replyData.bottomContainerSize, CGSize.zero) else {
            return
        }

        let size = replyData.bottomContainerSize
        bottomContainer.snp.remakeConstraints { make in
            make.top.equalTo(bubbleView.snp.bottom).offset(8)
            make.size.equalTo(size)
            if replyData.direction == .outgoing {
                make.trailing.equalTo(container)
            } else {
                make.leading.equalTo(container)
            }
        }

        if !messageModifyRepliesButton.isHidden {
            let oldRect = messageModifyRepliesButton.frame
            let newRect = CGRect(x: oldRect.origin.x, y: bottomContainer.frame.maxY, width: oldRect.size.width, height: oldRect.size.height)
            messageModifyRepliesButton.frame = newRect
        }
    }

    // MARK: - TUITextViewDelegate

    public func onLongPressTextViewMessage(_ textView: UITextView) {
        delegate?.onLongPressMessage(self)
    }

    // MARK: - UITextViewDelegate

    public func textViewDidChangeSelection(_ textView: UITextView) {
        let selectedString = textView.attributedText.attributedSubstring(from: textView.selectedRange)
        if let selectAllContentCallback = selectAllContentCallback, selectedString.length > 0 {
            selectAllContentCallback(selectedString.length == textView.attributedText.length)
        }
        if selectedString.length > 0 {
            let attributedString = NSMutableAttributedString()
            attributedString.append(selectedString)
            var offsetLocation = 0
            for emojiLocation in replyData?.emojiLocations ?? [] {
                if let key = emojiLocation.keys.first,
                   let originStr = emojiLocation[key]
                {
                    var currentRange = key.rangeValue
                    currentRange.location += offsetLocation
                    if currentRange.location >= textView.selectedRange.location {
                        currentRange.location -= textView.selectedRange.location
                        if currentRange.location + currentRange.length <= attributedString.length {
                            attributedString.replaceCharacters(in: currentRange, with: originStr)
                            offsetLocation += originStr.length - currentRange.length
                        }
                    }
                }
            }
            selectContent = attributedString.string
        } else {
            selectContent = nil
        }
    }

    // MARK: - TUIMessageCellProtocol

    override public class func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat {
        guard let data = data as? TUIReplyMessageCellData else {
            assertionFailure("data must be kind of TUIReplyMessageCellData")
            return CGFloat.zero
        }
        var height = super.getHeight(data, withWidth: width)
        if data.bottomContainerSize.height > 0 {
            height += data.bottomContainerSize.height + TUISwift.kScale375(6)
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

        var lineSpacingChecked = false
        if quoteWidth > quoteMaxWidth {
            quoteWidth = quoteMaxWidth
            lineSpacingChecked = true
        }
        if quoteWidth < quoteMinWidth {
            quoteWidth = quoteMinWidth
        }

        if showRevokeStr {
            quoteWidth = max(quoteWidth, messageRevokeRect.size.width)
            quoteHeight = 3 + 4 + messageRevokeRect.size.height + 6
        }

        quoteHeight = 3 + (senderRect?.size.height ?? 0) + 4 + placeholderSize.height + 6

        replyCellData.senderSize = CGSize(width: quoteWidth, height: (senderRect?.size.height ?? 0))
        replyCellData.quotePlaceholderSize = placeholderSize
        replyCellData.replyContentSize = CGSize(width: replyContentRect.size.width, height: replyContentRect.size.height)
        replyCellData.quoteSize = CGSize(width: quoteWidth, height: quoteHeight)

        // Calculate the height of cell
        height = 12 + quoteHeight + 12 + replyCellData.replyContentSize.height + 12

        let replyContentRect2 = attributeString.boundingRect(with: CGSize(width: CGFloat(Int.max), height: font.lineHeight),
                                                             options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                             context: nil)

        if lineSpacingChecked {
            if Int(replyContentRect2.size.width) % Int(quoteWidth) == 0 ||
                Int(replyContentRect2.size.width) % Int(quoteWidth) + Int(font.lineHeight) > Int(quoteWidth)
            {
                height += font.lineHeight
            }
        }

        var size = CGSize(width: quoteWidth + CGFloat(TReplyQuoteView_Margin_Width), height: height)

        let hasRiskContent = replyCellData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            size.width = max(size.width, 200)
            size.height += kTUISecurityStrikeViewTopLineMargin
            size.height += CGFloat(kTUISecurityStrikeViewTopLineToBottom)
        }

        return size
    }
}
