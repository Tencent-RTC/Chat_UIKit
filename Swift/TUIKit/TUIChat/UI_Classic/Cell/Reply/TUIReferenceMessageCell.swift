import TIMCommon
import UIKit

public class TUIReferenceMessageCell: TUIBubbleMessageCell, UITextViewDelegate, TUITextViewDelegate {
    var quoteBorderLayer: CALayer = .init()
    var referenceData: TUIReferenceMessageCellData?
    public var selectContent: String?
    var selectAllContentCallback: TUIReferenceSelectAllContentCallback?
    var currentOriginView: TUIReplyQuoteView?

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

    public lazy var textView: TUITextView = {
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
        contentView.addSubview(quoteView)
        bottomContainer = UIView()
        contentView.addSubview(bottomContainer)

        // Setup topContainer 
        topContainer = TUIPassthroughView()
        topContainer.isUserInteractionEnabled = true
        topContainer.clipsToBounds = false
        contentView.addSubview(topContainer)
    }

    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIReferenceMessageCellData else { return }

        referenceData = data
        senderLabel.text = "\(data.sender ?? ""):"
        selectContent = data.content
        var locations: [[NSValue: NSAttributedString]]? = data.emojiLocations
        textView.attributedText = data.content.getFormatEmojiString(withFont: textView.font!, emojiLocations: &locations)
        if let locations = locations {
            data.emojiLocations = locations
        }

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
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID", parentView: bottomContainer ?? UIView(), param: param)
    }

    override public func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        guard let referenceData = referenceData else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_TopContainer_CellData": referenceData]
        let hasExtension = TUICore.raiseExtension("TUICore_TUIChatExtension_TopContainer_ClassicExtensionID", parentView: topContainer, param: param)
        topContainer.isHidden = !hasExtension

        if hasExtension {
            layoutTopContainer()
        }
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

        textView.snp.remakeConstraints { make in
            make.leading.equalTo(bubbleView).offset(referenceData.textOrigin.x)
            make.top.equalTo(bubbleView).offset(referenceData.textOrigin.y)
            make.size.equalTo(referenceData.textSize)
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

        let hasRiskContent = messageData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            securityStrikeView.snp.remakeConstraints { make in
                make.top.equalTo(textView.snp.bottom)
                make.width.equalTo(bubbleView)
                make.bottom.equalTo(container)
            }
        }

        senderLabel.snp.remakeConstraints { make in
            make.leading.equalTo(quoteView).offset(6)
            make.top.equalTo(quoteView).offset(8)
            make.size.equalTo(referenceData.senderSize)
        }

        var hideSenderLabel = false
        if let status = referenceData.originCellData?.innerMessage?.status {
            hideSenderLabel = (status == .MSG_STATUS_LOCAL_REVOKED) && !referenceData.showRevokedOriginMessage
            senderLabel.isHidden = hideSenderLabel
        }

        quoteView.snp.remakeConstraints { make in
            if referenceData.direction == .incoming {
                make.leading.equalTo(bubbleView)
            } else {
                make.trailing.equalTo(bubbleView)
            }
            make.top.equalTo(container.snp.bottom).offset(6)
            make.size.equalTo(referenceData.quoteSize)
        }

        if referenceData.showMessageModifyReplies {
            messageModifyRepliesButton.snp.remakeConstraints { make in
                if referenceData.direction == .incoming {
                    make.leading.equalTo(quoteView.snp.leading)
                } else {
                    make.trailing.equalTo(quoteView.snp.trailing)
                }
                make.top.equalTo(quoteView.snp.bottom).offset(3)
                make.size.equalTo(messageModifyRepliesButton.frame.size)
            }
        }

        currentOriginView?.snp.remakeConstraints { make in
            if hideSenderLabel {
                make.leading.equalTo(quoteView).offset(6)
                make.top.equalTo(quoteView).offset(8)
                make.trailing.equalTo(quoteView)
                make.height.equalTo(referenceData.quotePlaceholderSize.height)
            } else {
                make.leading.equalTo(senderLabel.snp.trailing).offset(3)
                make.top.equalTo(senderLabel).offset(1)
                make.trailing.equalTo(quoteView)
                make.height.equalTo(referenceData.quotePlaceholderSize.height)
            }
        }
    }

    private func getCustomOriginView(_ originCellData: TUIMessageCellData?) -> TUIReplyQuoteView? {
        var reuseId = originCellData != nil ? String(describing: type(of: originCellData!)) : String(describing: TUITextMessageCellData.self)
        var view: TUIReplyQuoteView? = nil
        var reuse = false

        let hasRiskContent = originCellData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            reuseId = "hasRiskContent"
        }

        if let cachedView = customOriginViewsCache[reuseId] as? TUIReplyQuoteView {
            view = cachedView
            reuse = true
        }

        if hasRiskContent && view == nil {
            let quoteView = TUITextReplyQuoteView()
            view = quoteView
        }

        if view == nil {
            var classType: AnyClass? = originCellData?.getReplyQuoteViewClass()
            if let classType = classType as? TUIReplyQuoteView.Type {
                view = classType.init()
            }
        }

        if view == nil {
            view = TUITextReplyQuoteView()
        }

        if let quoteView = view as? TUITextReplyQuoteView {
            if referenceData?.direction == .incoming {
                quoteView.textLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_recv_text_color", defaultColor: "#888888")
            } else {
                quoteView.textLabel.textColor = TUISwift.tuiChatDynamicColor("chat_reference_message_quoteView_text_color", defaultColor: "#888888")
            }
        } else if let quoteView = view as? TUIMergeReplyQuoteView {
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
            if let view = view as? TUIReplyQuoteView {
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

        bottomContainer.snp.remakeConstraints { make in
            if !messageModifyRepliesButton.isHidden {
                make.top.equalTo(messageModifyRepliesButton.snp.bottom).offset(8)
            } else {
                make.top.equalTo(quoteView.snp.bottom).offset(8)
            }
            make.size.equalTo(size)
            if referenceData.direction == .outgoing {
                make.trailing.equalTo(container)
            } else {
                make.leading.equalTo(container)
            }
        }

        if !quoteView.isHidden {
            var oldRect = quoteView.frame
            let newRect = CGRect(x: oldRect.origin.x, y: bottomContainer.frame.maxY + 5, width: oldRect.size.width, height: oldRect.size.height)
            quoteView.frame = newRect
        }
        if !messageModifyRepliesButton.isHidden {
            var oldRect = messageModifyRepliesButton.frame
            let newRect = CGRect(x: oldRect.origin.x, y: quoteView.frame.maxY, width: oldRect.size.width, height: oldRect.size.height)
            messageModifyRepliesButton.frame = newRect
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
        if let selectedString = textView.attributedText?.attributedSubstring(from: textView.selectedRange),
           let selectAllContentCallback = selectAllContentCallback
        {
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
        cellHeight += TUISwift.kScale375(6)
        return cellHeight
    }

    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let referenceCellData = data as? TUIReferenceMessageCellData else {
            assertionFailure("data must be kind of TUIReferenceMessageCellData")
            return .zero
        }

        var quoteHeight: CGFloat = 0
        var quoteWidth: CGFloat = 0
        let quoteMaxWidth = CGFloat(TReplyQuoteView_Max_Width)
        let quotePlaceHolderMarginWidth: CGFloat = 12

        // Calculate the size of label which displays the sender's displayname
        let senderSize = "0".size(withAttributes: [.font: UIFont.boldSystemFont(ofSize: 12.0)])
        let senderRect = NSString(format: "%@:", referenceCellData.sender ?? "").boundingRect(with: CGSize(width: quoteMaxWidth, height: senderSize.height), options: .usesLineFragmentOrigin.union(.usesFontLeading), attributes: [.font: UIFont.boldSystemFont(ofSize: 12.0)], context: nil)

        // Calculate the size of customize quote placeholder view
        let placeholderSize = referenceCellData.quotePlaceholderSizeWithType(type: referenceCellData.originMsgType, data: referenceCellData.quoteData)

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

        // Calculate the size of label which displays the content of replying the original message
        var location: [[NSValue: NSAttributedString]]? = nil
        let attributeString = referenceCellData.content.getFormatEmojiString(withFont: UIFont.systemFont(ofSize: 16.0), emojiLocations: &location)

        let replyContentRect = attributeString.boundingRect(with: CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(), height: .greatestFiniteMagnitude),
                                                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                            context: nil)
        var size = CGSize(width: ceil(replyContentRect.width), height: ceil(replyContentRect.height))
        referenceCellData.textSize = size
        referenceCellData.textOrigin = CGPoint(x: (referenceCellData.cellLayout?.bubbleInsets.left ?? 0),
                                               y: (referenceCellData.cellLayout?.bubbleInsets.top ?? 0) + TUIBubbleMessageCell.getBubbleTop(referenceCellData))

        size.height += (referenceCellData.cellLayout?.bubbleInsets.top ?? 0) + (referenceCellData.cellLayout?.bubbleInsets.bottom ?? 0)
        size.width += (referenceCellData.cellLayout?.bubbleInsets.left ?? 0) + (referenceCellData.cellLayout?.bubbleInsets.right ?? 0)

        if referenceCellData.direction == .incoming {
            size.height = max(size.height, TUIBubbleMessageCell.incommingBubble?.size.height ?? 0)
        } else {
            size.height = max(size.height, TUIBubbleMessageCell.outgoingBubble?.size.height ?? 0)
        }

        let hasRiskContent = referenceCellData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            size.width = max(size.width, 200)
            size.height += kTUISecurityStrikeViewTopLineMargin
            size.height += CGFloat(kTUISecurityStrikeViewTopLineToBottom)
        }

        quoteWidth = senderRect.size.width
        quoteWidth += placeholderSize.width
        quoteWidth += (quotePlaceHolderMarginWidth * 2)

        if showRevokeStr {
            quoteWidth = messageRevokeRect.size.width
        }
        quoteHeight = max(senderRect.size.height, placeholderSize.height)
        quoteHeight += (8 + 8)

        referenceCellData.senderSize = senderRect.size
        referenceCellData.quotePlaceholderSize = placeholderSize
        referenceCellData.quoteSize = CGSize(width: quoteWidth, height: quoteHeight)

        return size
    }
}
