import TIMCommon
import UIKit

public class TUIReferenceMessageCell_Minimalist: TUIBubbleMessageCell_Minimalist, UITextViewDelegate, TUITextViewDelegate {
    var referenceData: TUIReferenceMessageCellData?
    var selectContent: String?
    var selectAllContentCallback: TUIReferenceSelectAllContentCallback?
    var currentOriginView: TUIReplyQuoteView_Minimalist?
    var longPressGesture: UILongPressGestureRecognizer?

    lazy var senderLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 12.0)
        label.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_sender_text_color", defaultColor: "#888888")
        return label
    }()

    lazy var quoteLineView: UIImageView = .init()

    lazy var quoteView: UIView = {
        let view = UIView()
        view.backgroundColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_bg_color", defaultColor: "#4444440c")
        view.layer.cornerRadius = 10.0
        view.layer.masksToBounds = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(quoteViewOnTap))
        view.addGestureRecognizer(tap)
        return view
    }()

    lazy var textView: TUITextView = {
        textView = TUITextView()
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.delegate = self
        textView.tuiTextViewDelegate = self
        textView.font = UIFont.systemFont(ofSize: 16.0)
        textView.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_content_text_color", defaultColor: "#000000")
        return textView
    }()

    lazy var customOriginViewsCache: [String: UIView] = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        bubbleView.addSubview(textView)
        quoteView.addSubview(senderLabel)
        contentView.addSubview(quoteLineView)
        contentView.addSubview(quoteView)
        bottomContainer = UIView()
        contentView.addSubview(bottomContainer)

        topContainer = UIView()
        topContainer.isUserInteractionEnabled = true
        contentView.addSubview(topContainer)
    }

    override public func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        guard let referenceData = referenceData else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_TopContainer_CellData": referenceData]
        let hasExtension = TUICore.raiseExtension("TUICore_TUIChatExtension_TopContainer_MinimalistExtensionID", parentView: topContainer, param: param)
        topContainer.isHidden = !hasExtension

        if hasExtension {
            layoutTopContainer()
        }
    }

    override public func fill(with data: TUICommonCellData) {
        guard let data = data as? TUIReferenceMessageCellData else { return }
        super.fill(with: data)
        referenceData = data
        senderLabel.text = "\(data.sender ?? ""):"
        senderLabel.rtlAlignment = TUITextRTLAlignment.leading
        selectContent = data.content
        var location: [[NSValue: NSAttributedString]]? = data.emojiLocations
        textView.attributedText = data.content.getFormatEmojiString(withFont: textView.font!, emojiLocations: &location)
        if let location = location {
            data.emojiLocations = location
        }

        if TUISwift.isRTL() {
            textView.textAlignment = .right
        } else {
            textView.textAlignment = .left
        }

        var lineImage: UIImage? = nil
        if bubbleData.direction == .incoming {
            lineImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("msg_reply_line_income"))
        } else {
            lineImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("msg_reply_line_outcome"))
        }
        lineImage = lineImage?.rtlImageFlippedForRightToLeftLayoutDirection()

        let ei = NSCoder.uiEdgeInsets(for: "{10,0,20,0}")
        let rtlEI = rtlEdgeInsetsWithInsets(ei)
        quoteLineView.image = lineImage?.resizableImage(withCapInsets: rtlEI, resizingMode: .stretch)
        bottomContainer.isHidden = CGSizeEqualToSize(data.bottomContainerSize, .zero)

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

    override public func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        guard let referenceData = referenceData else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_BottomContainer_CellData": referenceData]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID", parentView: bottomContainer ?? UIView(), param: param)
    }

    func updateUI(with referenceData: TUIReferenceMessageCellData?) {
        guard let referenceData = referenceData else { return }
        currentOriginView = getCustomOriginView(referenceData.originCellData)
        hiddenAllCustomOriginViews(true)
        currentOriginView?.isHidden = false

        if let quoteData = referenceData.quoteData {
            quoteData.supportForReply = false
            quoteData.showRevokedOriginMessage = referenceData.showRevokedOriginMessage
            currentOriginView?.fill(with: quoteData)
        }

        if referenceData.direction == .incoming {
            textView.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_content_recv_text_color", defaultColor: "#000000")
            senderLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_recv_text_color", defaultColor: "#888888")
            quoteView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_bg_color", defaultColor: "#4444440c")
        } else {
            textView.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_content_text_color", defaultColor: "#000000")
            senderLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_text_color", defaultColor: "#888888")
            quoteView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_bg_color", defaultColor: "#4444440c")
        }

        textView.textColor = referenceData.textColor
        textView.snp.remakeConstraints { make in
            make.leading.equalTo(bubbleView).offset(referenceData.textOrigin.x)
            make.top.equalTo(bubbleView).offset(referenceData.textOrigin.y)
            make.size.equalTo(referenceData.textSize)
        }

        quoteView.snp.remakeConstraints { make in
            if referenceData.direction == .incoming {
                make.leading.equalTo(bubbleView).offset(15)
            } else {
                make.trailing.equalTo(bubbleView).offset(-15)
            }
            make.top.equalTo(bubbleView.snp.bottom).offset((messageData?.messageContainerAppendSize.height ?? 0) + 6)
            make.size.equalTo(referenceData.quoteSize)
        }

        senderLabel.snp.remakeConstraints { make in
            make.leading.equalTo(quoteView).offset(6)
            make.top.equalTo(quoteView).offset(8)
            make.size.equalTo(referenceData.senderSize)
        }

        let hideSenderLabel = (referenceData.originCellData?.innerMessage?.status == .MSG_STATUS_LOCAL_REVOKED) && !referenceData.showRevokedOriginMessage
        senderLabel.isHidden = hideSenderLabel

        currentOriginView?.snp.remakeConstraints { make in
            if hideSenderLabel {
                make.leading.equalTo(quoteView).offset(6)
                make.top.equalTo(quoteView).offset(8)
                make.trailing.equalTo(quoteView)
                make.height.equalTo(referenceData.quotePlaceholderSize.height)
            } else {
                make.leading.equalTo(senderLabel.snp.trailing).offset(4)
                make.top.equalTo(senderLabel).offset(1)
                make.trailing.equalTo(quoteView)
                make.height.equalTo(referenceData.quotePlaceholderSize.height)
            }
        }

        quoteLineView.snp.remakeConstraints { make in
            make.top.equalTo(bubbleView.snp.bottom)
            make.bottom.equalTo(quoteView.snp.centerY)
            make.width.equalTo(17)
            if referenceData.direction == .incoming {
                make.leading.equalTo(container).offset(-1)
            } else {
                make.trailing.equalTo(container)
            }
        }
    }

    private func getCustomOriginView(_ originCellData: TUIMessageCellData?) -> TUIReplyQuoteView_Minimalist? {
        let reuseId = originCellData != nil ? String(describing: type(of: originCellData!)) : String(describing: TUITextMessageCellData.self)
        var view: TUIReplyQuoteView_Minimalist? = nil
        var reuse = false

        if let cachedView = customOriginViewsCache[reuseId] as? TUIReplyQuoteView_Minimalist {
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
            if referenceData?.direction == .incoming {
                quoteView.textLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_recv_text_color", defaultColor: "#888888")
            } else {
                quoteView.textLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_text_color", defaultColor: "#888888")
            }
        } else if let quoteView = view as? TUIMergeReplyQuoteView_Minimalist {
            if referenceData?.direction == .incoming {
                quoteView.titleLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_recv_text_color", defaultColor: "#888888")
            } else {
                quoteView.titleLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_text_color", defaultColor: "#888888")
            }
        }

        if !reuse {
            customOriginViewsCache[reuseId] = view
            quoteView.addSubview(view!)
        }

        view!.isHidden = true
        return view
    }

    private func hiddenAllCustomOriginViews(_ hidden: Bool) {
        for (_, view) in customOriginViewsCache {
            if let view = view as? TUIReplyQuoteView_Minimalist {
                view.isHidden = hidden
                view.reset()
            }
        }
    }

    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override public func updateConstraints() {
        super.updateConstraints()
        updateUI(with: referenceData)
        layoutBottomContainer()
        layoutTopContainer()
    }

    private func layoutTopContainer() {
        guard !topContainer.isHidden else { return }
        guard let referenceData = referenceData else { return }

        let topContainerSize = referenceData.topContainerSize
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

    private func layoutBottomContainer() {
        guard let referenceData = referenceData else { return }
        if CGSizeEqualToSize(referenceData.bottomContainerSize, .zero) {
            return
        }

        let size = referenceData.bottomContainerSize
        let offset = quoteLineView.isHidden ? 0 : 2

        bottomContainer.snp.remakeConstraints { make in
            if referenceData.direction == .incoming {
                make.leading.equalTo(container).offset(offset)
            } else {
                make.trailing.equalTo(container).offset(-offset)
            }
            make.top.equalTo(quoteView.snp.bottom).offset(6)
            make.size.equalTo(size)
        }

        if !quoteView.isHidden {
            let oldRect = quoteView.frame
            let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y + oldRect.size.height + 5, width: oldRect.size.width, height: oldRect.size.height)
            quoteView.frame = newRect
        }

        if !messageModifyRepliesButton.isHidden {
            let oldRect = messageModifyRepliesButton.frame
            let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y + oldRect.size.height + 5, width: oldRect.size.width, height: oldRect.size.height)
            messageModifyRepliesButton.frame = newRect
        }

        for view in replyAvatarImageViews {
            let oldRect = view.frame
            let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y + oldRect.size.height + 5, width: oldRect.size.width, height: oldRect.size.height)
            view.frame = newRect
        }

        if !quoteLineView.isHidden {
            let oldRect = quoteLineView.frame
            let newRect = CGRect(x: oldRect.origin.x, y: oldRect.origin.y, width: oldRect.size.width, height: oldRect.size.height + bottomContainer.mm_h)
            quoteLineView.frame = newRect
        }
    }

    @objc func quoteViewOnTap() {
        delegate?.onSelectMessage(self)
    }

    // MARK: - TUITextViewDelegate

    public func onLongPressTextViewMessage(_ textView: UITextView) {
        delegate?.onLongPressMessage(self)
    }

    // MARK: - UITextViewDelegate

    public func textViewDidChangeSelection(_ textView: UITextView) {
        if let selectedString = textView.attributedText?.attributedSubstring(from: textView.selectedRange), let selectAllContentCallback = selectAllContentCallback {
            if selectedString.length == textView.attributedText?.length ?? 0 {
                selectAllContentCallback(true)
            } else {
                selectAllContentCallback(false)
            }
        }

        if let selectedString = textView.attributedText?.attributedSubstring(from: textView.selectedRange) {
            let attributedString = NSMutableAttributedString(string: selectedString.string)
            var offsetLocation = 0
            for emojiLocation in referenceData?.emojiLocations ?? [] {
                if let key = emojiLocation.keys.first, let originStr = emojiLocation[key] {
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
        guard let referenceCellData = data as? TUIReferenceMessageCellData else {
            assertionFailure("data must be kind of TUIReferenceMessageCellData")
            return 0
        }

        var cellHeight = super.getHeight(referenceCellData, withWidth: width)
        cellHeight += referenceCellData.quoteSize.height + referenceCellData.bottomContainerSize.height
        if referenceCellData.bottomContainerSize.height > 0 {
            cellHeight += TUISwift.kScale375(6)
        }
        cellHeight += TUISwift.kScale375(6)
        return cellHeight
    }

    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard var referenceCellData = data as? TUIReferenceMessageCellData else {
            assertionFailure("data must be kind of TUIReferenceMessageCellData")
            return .zero
        }

        var quoteHeight: CGFloat = 0
        var quoteWidth: CGFloat = 0
        let quoteMaxWidth = CGFloat(TReplyQuoteView_Max_Width)
        let quotePlaceHolderMarginWidth: CGFloat = 12

        // Calculate the size of label which displays the sender's displayname
        let senderSize = "0".size(withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12.0)])
        let senderRect = NSString(format: "%@:", referenceCellData.sender ?? "").boundingRect(with: CGSize(width: quoteMaxWidth, height: senderSize.height),
                                                                                              options: .usesLineFragmentOrigin.union(.usesFontLeading),
                                                                                              attributes: [.font: UIFont.boldSystemFont(ofSize: 12.0)],
                                                                                              context: nil)

        // Calculate the size of revoke string
        var messageRevokeRect = CGRect.zero
        let showRevokeStr = referenceCellData.originCellData?.innerMessage?.status == .MSG_STATUS_LOCAL_REVOKED && !referenceCellData.showRevokedOriginMessage
        if showRevokeStr {
            let msgRevokeStr = TUISwift.timCommonLocalizableString("TUIKitReferenceOriginMessageRevoke")
            messageRevokeRect = msgRevokeStr.boundingRect(with: CGSize(width: quoteMaxWidth, height: senderSize.height),
                                                          options: .usesLineFragmentOrigin.union(.usesFontLeading),
                                                          attributes: [.font: UIFont.boldSystemFont(ofSize: 12.0)],
                                                          context: nil)
        }

        // Calculate the size of customize quote placeholder view
        let placeholderSize = referenceCellData.quotePlaceholderSizeWithType(type: referenceCellData.originMsgType, data: referenceCellData.quoteData)

        // Calculate the size of label which displays the content of replying the original message
        let textFont = UIFont.systemFont(ofSize: 16.0)
        var locations: [[NSValue: NSAttributedString]]? = nil
        let attributeString = referenceCellData.content.getFormatEmojiString(withFont: textFont, emojiLocations: &locations)

        let replyContentRect = attributeString.boundingRect(with: CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(), height: CGFloat(Int.max)), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        var size = CGSize(width: ceil(replyContentRect.size.width), height: ceil(replyContentRect.size.height))

        let replyContentRect2 = attributeString.boundingRect(with: CGSize(width: CGFloat(Int.max), height: textFont.lineHeight), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let size2 = replyContentRect2.size

        // If there are multiple lines, determine whether the font width of the last line exceeds the position of the message status. If so, the message status will wrap.
        // If there is only one line, directly add the width of the message status
        if Int(size2.width) / Int(TUISwift.tTextMessageCell_Text_Width_Max()) > 0 {
            if size2.width.truncatingRemainder(dividingBy: TUISwift.tTextMessageCell_Text_Width_Max())
                > TUISwift.tTextMessageCell_Text_Width_Max() - referenceCellData.msgStatusSize.width
            {
                size.height += referenceCellData.msgStatusSize.height
            }
        } else {
            size.width += referenceCellData.msgStatusSize.width + TUISwift.kScale390(10)
        }

        referenceCellData.textSize = size
        let y = (referenceCellData.cellLayout?.bubbleInsets.top ?? 0) + TUIBubbleMessageCell_Minimalist.getBubbleTop(data: referenceCellData)
        referenceCellData.textOrigin = CGPoint(x: (referenceCellData.cellLayout?.bubbleInsets.left ?? 0), y: y)

        size.height += (referenceCellData.cellLayout?.bubbleInsets.top ?? 0) + (referenceCellData.cellLayout?.bubbleInsets.bottom ?? 0)
        size.width += (referenceCellData.cellLayout?.bubbleInsets.left ?? 0) + (referenceCellData.cellLayout?.bubbleInsets.right ?? 0)

        if referenceCellData.direction == .incoming {
            size.height = max(size.height, (TUIBubbleMessageCell_Minimalist.incommingBubble?.size.height ?? 0))
        } else {
            size.height = max(size.height, (TUIBubbleMessageCell_Minimalist.outgoingBubble?.size.height ?? 0))
        }

        quoteWidth = senderRect.size.width
        quoteWidth += placeholderSize.width
        quoteWidth += (quotePlaceHolderMarginWidth * 2)

        quoteHeight = max(senderRect.size.height, placeholderSize.height)
        quoteHeight += (8 + 8)

        if showRevokeStr {
            quoteWidth = messageRevokeRect.size.width
            quoteHeight = max(senderRect.size.height, placeholderSize.height)
            quoteHeight += (8 + 8)
        }

        referenceCellData.senderSize = CGSize(width: ceil(senderRect.size.width) + 3, height: senderRect.size.height)
        referenceCellData.quotePlaceholderSize = CGSize(width: ceil(placeholderSize.width), height: ceil(placeholderSize.height))
        referenceCellData.quoteSize = CGSize(width: ceil(quoteWidth), height: ceil(quoteHeight))

        return size
    }
}
