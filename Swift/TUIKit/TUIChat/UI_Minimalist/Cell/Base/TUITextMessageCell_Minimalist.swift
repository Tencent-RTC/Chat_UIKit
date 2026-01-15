import SnapKit
import TIMCommon
import TUICore
import UIKit

public class TUITextMessageCell_Minimalist: TUIBubbleMessageCell_Minimalist, UITextViewDelegate, TUITextViewDelegate {
    var textView: TUITextView!
    var selectContent: String?
    var selectAllContentCallback: TUIChatSelectAllContentCallback?
    var textData: TUITextMessageCellData?
    var voiceReadPoint: UIImageView!
    
    private static var _outgoingTextColor: UIColor?
    static var outgoingTextColor: UIColor? {
        get {
            setupNotification()
            if _outgoingTextColor == nil {
                _outgoingTextColor = TUISwift.tuiChatDynamicColor("chat_text_message_send_text_color", defaultColor: "#000000")
            }
            return _outgoingTextColor
        }
        set {
            _outgoingTextColor = newValue
        }
    }
    
    private static var _outgoingTextFont: UIFont?
    static var outgoingTextFont: UIFont? {
        get {
            setupNotification()
            if _outgoingTextFont == nil {
                _outgoingTextFont = UIFont.systemFont(ofSize: 16)
            }
            return _outgoingTextFont
        }
        set {
            _outgoingTextFont = newValue
        }
    }
    
    private static var _incommingTextColor: UIColor?
    static var incommingTextColor: UIColor? {
        get {
            setupNotification()
            if _incommingTextColor == nil {
                _incommingTextColor = TUISwift.tuiChatDynamicColor("chat_text_message_receive_text_color", defaultColor: "#000000")
            }
            return _incommingTextColor
        }
        set {
            _incommingTextColor = newValue
        }
    }
    
    private static var _incommingTextFont: UIFont?
    static var incommingTextFont: UIFont? {
        get {
            setupNotification()
            if _incommingTextFont == nil {
                _incommingTextFont = UIFont.systemFont(ofSize: 16)
            }
            return _incommingTextFont
        }
        set {
            _incommingTextFont = newValue
        }
    }
    
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        TUITextMessageCell_Minimalist.setupNotification()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Allow content to extend beyond cell bounds (for topContainer)
        clipsToBounds = false
        contentView.clipsToBounds = false
        
        textView = TUITextView()
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.delegate = self
        textView.tuiTextViewDelegate = self
        bubbleView.addSubview(textView)
        container.bringSubviewToFront(msgStatusView)
        
        bottomContainer = UIView()
        contentView.addSubview(bottomContainer)
        
        topContainer = UIView()
        topContainer.isUserInteractionEnabled = true
        contentView.addSubview(topContainer)
        
        voiceReadPoint = UIImageView()
        voiceReadPoint.backgroundColor = .red
        voiceReadPoint.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
        voiceReadPoint.isHidden = true
        voiceReadPoint.layer.cornerRadius = voiceReadPoint.frame.size.width / 2
        voiceReadPoint.layer.masksToBounds = true
        bubbleView.addSubview(voiceReadPoint)
    }
    
    override public func prepareForReuse() {
        super.prepareForReuse()
        for view in bottomContainer.subviews {
            view.removeFromSuperview()
        }
        for view in topContainer.subviews {
            view.removeFromSuperview()
        }
        textView.alpha = 1
        textView.isHidden = false
        bottomContainer.alpha = 1
        topContainer.isHidden = true
        msgTimeLabel.isHidden = false
    }
    
    override public func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_BottomContainer_CellData": textData as Any]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID", parentView: bottomContainer, param: param)
    }
    
    override public func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_TopContainer_CellData": textData as Any]
        let hasExtension = TUICore.raiseExtension("TUICore_TUIChatExtension_TopContainer_MinimalistExtensionID", parentView: topContainer, param: param)
        topContainer.isHidden = !hasExtension
        
        // If extension was added, layout topContainer
        if hasExtension {
            layoutTopContainer()
        }
    }
    
    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        if let data = data as? TUITextMessageCellData {
            textData = data
            selectContent = data.content
            voiceReadPoint.isHidden = !data.showUnreadPoint
            bottomContainer.isHidden = CGSizeEqualToSize(data.bottomContainerSize, .zero)
            
            let textColor: UIColor = data.direction == .incoming ? TUITextMessageCell_Minimalist.incommingTextColor! : TUITextMessageCell_Minimalist.outgoingTextColor!
            let textFont: UIFont = data.direction == .incoming ? TUITextMessageCell_Minimalist.incommingTextFont! : TUITextMessageCell_Minimalist.outgoingTextFont!

            textView.attributedText = data.getContentAttributedString(textFont: textFont)
            textView.textColor = textColor
            textView.font = textFont
            textView.textAlignment = TUISwift.isRTL() ? .right : .left
            
            let shouldHide = TUITextMessageCell_Minimalist.getShouldHideOriginalText(for: data)
            textView.isHidden = shouldHide
            textView.alpha = shouldHide ? 0 : 1
            msgTimeLabel.isHidden = shouldHide
            
            setNeedsUpdateConstraints()
            updateConstraintsIfNeeded()
            layoutIfNeeded()
        }
    }
    
    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    override public func updateConstraints() {
        super.updateConstraints()
        
        // If topContainerInsetTop > 0, adjust container's top offset to move it down
        // This prevents nameLabel from overlapping with topContainer
        if let textData = textData, textData.topContainerInsetTop > 0 {
            let cellLayout = textData.cellLayout
            let baseOffset = cellLayout?.messageInsets.top ?? 0
            let extraOffset = textData.topContainerInsetTop
            
            container.snp.updateConstraints { make in
                make.top.equalTo(nameLabel.snp.bottom).offset(baseOffset + extraOffset)
            }
        }
        
        textView.snp.remakeConstraints { make in
            make.leading.equalTo(bubbleView).offset(ceil(textData?.textOrigin.x ?? 0))
            make.top.equalTo(bubbleView).offset(ceil(textData?.textOrigin.y ?? 0))
            make.width.equalTo(ceil(textData?.textSize.width ?? 0))
            make.height.equalTo(ceil(textData?.textSize.height ?? 0))
        }
        if !voiceReadPoint.isHidden {
            voiceReadPoint.snp.remakeConstraints { make in
                make.top.equalTo(bubbleView)
                make.leading.equalTo(bubbleView).offset(1)
                make.size.equalTo(CGSize(width: 5, height: 5))
            }
        }

        layoutBottomContainer()
        layoutTopContainer()
    }
    
    override public func layoutSubviews() {
        super.layoutSubviews()
    }
    
    func layoutBottomContainer() {
        guard !CGSizeEqualToSize(textData?.bottomContainerSize ?? .zero, .zero) else { return }
        
        let size = textData?.bottomContainerSize ?? .zero
        let offset: CGFloat = replyLineView.isHidden ? 0 : 1
        bottomContainer.snp.remakeConstraints { make in
            if textData?.direction == .incoming {
                make.leading.equalTo(container).offset(offset)
            } else {
                make.trailing.equalTo(container).offset(-offset)
            }
            make.top.equalTo(bubbleView.snp.bottom).offset((messageData?.messageContainerAppendSize.height ?? 0) + 6)
            make.size.equalTo(size)
        }
        
        if !messageModifyRepliesButton.isHidden {
            var newRect = messageModifyRepliesButton.frame
            newRect.origin.y = bottomContainer.frame.maxY + 5
            messageModifyRepliesButton.frame = newRect
        }
        
        for view in replyAvatarImageViews {
            var newRect = view.frame
            newRect.origin.y = bottomContainer.frame.maxY + 5
            view.frame = newRect
        }
        
        if !replyLineView.isHidden {
            var newRect = retryView.frame
            newRect.size.height += bottomContainer.mm_h
            retryView.frame = newRect
        }
    }
    
    func layoutTopContainer() {
        guard !topContainer.isHidden else { return }
        guard let textData = textData else { return }
        
        let topContainerSize = textData.topContainerSize
        guard topContainerSize.width > 0 && topContainerSize.height > 0 else {
            topContainer.isHidden = true
            return
        }
        
        // Check if original text is hidden (translation mode)
        let shouldHide = TUITextMessageCell_Minimalist.getShouldHideOriginalText(for: textData)
        
        // Position topContainer at top-right corner of bubbleView or bottomContainer
        // The container's centerY aligns with bubble's/bottomContainer's top edge
        topContainer.snp.remakeConstraints { make in
            if shouldHide && !bottomContainer.isHidden {
                // When original text is hidden, align with bottomContainer
                make.trailing.equalTo(bottomContainer.snp.trailing)
                make.centerY.equalTo(bottomContainer.snp.top)
            } else {
                // Normal mode: align with bubbleView
                make.trailing.equalTo(bubbleView.snp.trailing)
                make.centerY.equalTo(bubbleView.snp.top)
            }
            make.size.equalTo(topContainerSize)
        }
    }
    
    func animateOriginalTextVisibilityIfNeeded(animated: Bool) {
        guard let textCellData = textData else { return }
        
        let shouldShowBottomContainer = !CGSizeEqualToSize(textCellData.bottomContainerSize, .zero)
        
        if !animated {
            bottomContainer.isHidden = !shouldShowBottomContainer
            bottomContainer.alpha = shouldShowBottomContainer ? 1 : 0
            return
        }
        
        bottomContainer.layer.removeAllAnimations()
        
        if shouldShowBottomContainer {
            bottomContainer.isHidden = false
            bottomContainer.alpha = 0
            
            UIView.animate(withDuration: 0.25) {
                self.bottomContainer.alpha = 1
            }
        } else {
            bottomContainer.isHidden = false
            bottomContainer.alpha = 1
            
            UIView.animate(withDuration: 0.25, animations: {
                self.bottomContainer.alpha = 0
            }, completion: { _ in
                self.bottomContainer.isHidden = true
            })
        }
    }
    
    public func textViewDidChangeSelection(_ textView: UITextView) {
        let selectedString = textView.attributedText.attributedSubstring(from: textView.selectedRange)
        if let selectAllContentCallback = selectAllContentCallback, selectedString.length > 0 {
            if selectedString.length == textView.attributedText.length {
                selectAllContentCallback(true)
            } else {
                selectAllContentCallback(false)
            }
        }
        if selectedString.length > 0 {
            let attributedString = NSMutableAttributedString(attributedString: selectedString)
            var offsetLocation = 0
            for emojiLocation in textData?.emojiLocations ?? [] {
                guard let key = emojiLocation.keys.first,
                      let originStr = emojiLocation[key],
                      var currentRange = (key as AnyObject).rangeValue else { continue }
                currentRange.location += offsetLocation
                if currentRange.location >= textView.selectedRange.location {
                    currentRange.location -= textView.selectedRange.location
                    if currentRange.location + currentRange.length <= attributedString.length {
                        attributedString.replaceCharacters(in: currentRange, with: originStr)
                        offsetLocation += originStr.string.count - currentRange.length
                    }
                }
            }
            selectContent = attributedString.string
        } else {
            selectContent = nil
        }
    }
    
    private static var hasSetupNotification = false
    private static func setupNotification() {
        guard !hasSetupNotification else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: Notification.Name("TUIDidApplyingThemeChangedNotfication"), object: nil)
        hasSetupNotification = true
    }
    
    @objc public class func onThemeChanged() {
        TUITextMessageCell_Minimalist.outgoingTextColor = nil
        TUITextMessageCell_Minimalist.incommingTextColor = nil
    }
    
    // MARK: - TUITextViewDelegate

    public func onLongPressTextViewMessage(_ textView: UITextView) {
        delegate?.onLongPressMessage(self)
    }
    
    // MARK: - getShouldHideOriginalText Helper
    
    private class func getShouldHideOriginalText(for cellData: TUITextMessageCellData) -> Bool {
        guard let message = cellData.innerMessage else { return false }
        
        // Call TUICore service to get visibility state
        let param: [String: Any] = ["message": message]
        let result = TUICore.callService(
            "TUICore_TUITranslationService",
            method: "TUICore_TUITranslationService_GetShouldHideOriginalTextMethod",
            param: param
        )
        
        // Result is NSNumber wrapping Bool
        if let shouldHide = result as? NSNumber {
            return shouldHide.boolValue
        }
        
        return false
    }
    
    // MARK: - TUIMessageCelllProtocol

    override public class func getEstimatedHeight(_ data: TUIMessageCellData) -> CGFloat {
        return 44.0
    }
    
    private class func getTopContainerInsetTop(for cellData: TUITextMessageCellData) -> CGFloat {
        let param: [String: Any] = ["cellData": cellData]
        let result = TUICore.callService(
            "TUICore_TUITextToVoiceService",
            method: "TUICore_TUITextToVoiceService_CalculateTopContainerInsetTopMethod",
            param: param
        )
        if let insetTop = result as? NSNumber {
            return CGFloat(insetTop.doubleValue)
        }
        return 0
    }
        
    override public class func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat {
        guard let textCellData = data as? TUITextMessageCellData else {
            assertionFailure("data must be kind of TUITextMessageCellData")
            return CGFloat.zero
        }
        
        // Calculate topContainerInsetTop via plugin service
        let topContainerInsetTop = getTopContainerInsetTop(for: textCellData)
        textCellData.topContainerInsetTop = topContainerInsetTop
        
        // Read shouldHideOriginalText from translation plugin
        let shouldHide = getShouldHideOriginalText(for: textCellData)
        
        if !shouldHide {
            var height = super.getHeight(textCellData, withWidth: width)
            if textCellData.bottomContainerSize.height > 0 {
                height += textCellData.bottomContainerSize.height + 6
            }
            // Add extra height when container needs to be moved down due to long nameLabel
            if textCellData.topContainerInsetTop > 0 {
                height += textCellData.topContainerInsetTop
            }
            return height
        }
        
        // When original text is hidden, calculate minimal height
        var height: CGFloat = 0
        
        if textCellData.showName {
            height += TUISwift.kScale390(20)
        }
        if textCellData.showMessageModifyReplies {
            height += TUISwift.kScale390(22)
        }
        
        if textCellData.messageContainerAppendSize.height > 0 {
            height += textCellData.messageContainerAppendSize.height
        }
        
        height += textCellData.cellLayout?.messageInsets.top ?? 0
        height += textCellData.cellLayout?.messageInsets.bottom ?? 0
        
        if textCellData.bottomContainerSize.height > 0 {
            height += textCellData.bottomContainerSize.height + 6
        }
        
        // Add extra height when container needs to be moved down due to long nameLabel
        if textCellData.topContainerInsetTop > 0 {
            height += textCellData.topContainerInsetTop
        }
        
        return height
    }
        
    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let textCellData = data as? TUITextMessageCellData else {
            assertionFailure("data must be kind of TUITextMessageData")
            return CGSize.zero
        }
        
        let shouldHide = getShouldHideOriginalText(for: textCellData)
        
        if shouldHide {
            textCellData.textSize = .zero
            textCellData.textOrigin = .zero
            return .zero
        }
            
        let textFont = textCellData.direction == .incoming ? incommingTextFont! : outgoingTextFont!
        let attributeString = textCellData.getContentAttributedString(textFont: textFont)
            
        let rect = attributeString.boundingRect(with: CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(),
                                                             height: CGFloat.greatestFiniteMagnitude),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                context: nil)
        var size = rect.size
            
        let rect2 = attributeString.boundingRect(with: CGSize(width: CGFloat.greatestFiniteMagnitude,
                                                              height: textFont.lineHeight),
                                                 options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                 context: nil)
        let size2 = rect2.size
            
        // If there are multiple lines, determine whether the font width of the last line exceeds the position of the message status. If so, the message status will wrap.
        // If there is only one line, directly add the width of the message status
        let maxWidth = (size.height > textFont.lineHeight) ? size.width : TUISwift.tTextMessageCell_Text_Width_Max()
        if Int(size2.width) / Int(maxWidth) > 1 {
            if Int(size2.width) % Int(maxWidth) == 0 || CGFloat(Int(size2.width)).truncatingRemainder(dividingBy: maxWidth) + textCellData.msgStatusSize.width >= maxWidth {
                size.height += textCellData.msgStatusSize.height
            }
        } else {
            size.width += textCellData.msgStatusSize.width + TUISwift.kScale390(10)
        }
            
        textCellData.textSize = size
        let y = (textCellData.cellLayout?.bubbleInsets.top ?? 0) + TUIBubbleMessageCell_Minimalist.getBubbleTop(data: textCellData)
        textCellData.textOrigin = CGPoint(x: (textCellData.cellLayout?.bubbleInsets.left ?? 0), y: y)
            
        size.height += (textCellData.cellLayout?.bubbleInsets.top ?? 0) + (textCellData.cellLayout?.bubbleInsets.bottom ?? 0)
        size.width += (textCellData.cellLayout?.bubbleInsets.left ?? 0) + (textCellData.cellLayout?.bubbleInsets.right ?? 0)
            
        if textCellData.direction == .incoming {
            size.height = max(size.height, TUIBubbleMessageCell_Minimalist.incommingBubble?.size.height ?? 0)
        } else {
            size.height = max(size.height, TUIBubbleMessageCell_Minimalist.outgoingBubble?.size.height ?? 0)
        }
            
        return size
    }
}

class IUChatView_Minimalist: UIView {
    var view: UIView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.view = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        addSubview(view)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.view = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        addSubview(view)
    }
}
