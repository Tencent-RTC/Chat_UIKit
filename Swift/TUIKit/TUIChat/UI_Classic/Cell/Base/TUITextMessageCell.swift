import SnapKit
import TIMCommon
import TUICore
import UIKit

// Custom view that allows touch events to pass through to subviews even when they're outside bounds
class TUIPassthroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // First try the default hit test
        if let hitView = super.hitTest(point, with: event), hitView != self {
            return hitView
        }
        
        // If point is outside bounds, check all subviews manually
        for subview in subviews.reversed() {
            let convertedPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(convertedPoint, with: event) {
                return hitView
            }
        }
        
        return nil
    }
}

public class TUITextMessageCell: TUIBubbleMessageCell, UITextViewDelegate, TUITextViewDelegate {
    public var textView: TUITextView!
    public var selectContent: String?
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
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        TUITextMessageCell.setupNotification()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        textView = TUITextView()
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.delegate = self
        textView.tuiTextViewDelegate = self
        bubbleView.addSubview(textView)
        
        // Use custom view that allows touch events outside bounds
        bottomContainer = TUIPassthroughView()
        bottomContainer.isUserInteractionEnabled = true  // Enable user interaction for button clicks
        contentView.addSubview(bottomContainer)
        
        topContainer = TUIPassthroughView()
        topContainer.isUserInteractionEnabled = true
        topContainer.clipsToBounds = false
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
    }
    
    override public func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_BottomContainer_CellData": textData as Any]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID", parentView: bottomContainer, param: param)
    }
    
    override public func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_TopContainer_CellData": textData as Any]
        let hasExtension = TUICore.raiseExtension("TUICore_TUIChatExtension_TopContainer_ClassicExtensionID", parentView: topContainer, param: param)
        topContainer.isHidden = !hasExtension
        
        // If extension was added, layout topContainer
        if hasExtension {
            layoutTopContainer()
        }
    }
    
    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        if let data = data as? TUITextMessageCellData {
            textData = data
            selectContent = data.content
            voiceReadPoint.isHidden = !data.showUnreadPoint
            bottomContainer.isHidden = CGSizeEqualToSize(data.bottomContainerSize, .zero)
            
            let textColor: UIColor = data.direction == .incoming ? TUITextMessageCell.incommingTextColor! : TUITextMessageCell.outgoingTextColor!
            let textFont: UIFont = data.direction == .incoming ? TUITextMessageCell.incommingTextFont! : TUITextMessageCell.outgoingTextFont!

            textView.attributedText = data.getContentAttributedString(textFont: textFont)
            textView.textAlignment = TUISwift.isRTL() ? .right : .left
            textView.textColor = textColor
            textView.font = textFont
            
            // Control text visibility based on translation plugin's state
            // Read from localCustomData via TUICore service to avoid direct dependency
            let shouldHide = TUITextMessageCell.getShouldHideOriginalText(for: data)
            textView.isHidden = shouldHide
            textView.alpha = shouldHide ? 0 : 1
            
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
            make.leading.equalTo(bubbleView).offset(textData?.textOrigin.x ?? 0)
            make.top.equalTo(bubbleView).offset(textData?.textOrigin.y ?? 0)
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
        let hasRiskContent = messageData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            securityStrikeView.snp.remakeConstraints { make in
                make.top.equalTo(textView.snp.bottom)
                make.width.equalTo(bubbleView)
                make.bottom.equalTo(container).offset(-(messageData?.messageContainerAppendSize.height ?? 0))
            }
        }

        layoutBottomContainer()
        layoutTopContainer()
    }
    
    func layoutBottomContainer() {
        let isBottomContainerSizeZero = CGSizeEqualToSize(textData?.bottomContainerSize ?? CGSize.zero, CGSize.zero)
        if !isBottomContainerSizeZero {
            if let size = textData?.bottomContainerSize {
                bottomContainer.snp.remakeConstraints { make in
                    if textData?.direction == .incoming {
                        make.leading.equalTo(container)
                    } else {
                        make.trailing.equalTo(container)
                    }
                    make.top.equalTo(container.snp.bottom).offset(6)
                    make.size.equalTo(size)
                }
            }
        }
        let topView = !isBottomContainerSizeZero ? bottomContainer : container
        if !messageModifyRepliesButton.isHidden {
            messageModifyRepliesButton.snp.remakeConstraints { make in
                if textData?.direction == .incoming {
                    make.leading.equalTo(container)
                } else {
                    make.trailing.equalTo(container)
                }
                make.top.equalTo(topView.snp.bottom).priority(100)
                make.size.equalTo(CGSize(width: messageModifyRepliesButton.frame.size.width + 10, height: 30))
            }
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
        let shouldHide = TUITextMessageCell.getShouldHideOriginalText(for: textData)
        
        // Position topContainer at top-right corner of bubbleView or bottomContainer
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
            NotificationCenter.default.post(name: NSNotification.Name("kTUIChatPopMenuWillHideNotification"), object: nil)
        }
    }
    
    private static var hasSetupNotification = false
    private static func setupNotification() {
        guard !hasSetupNotification else { return }
        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: Notification.Name("TUIDidApplyingThemeChangedNotfication"), object: nil)
        hasSetupNotification = true
    }
    
    @objc public class func onThemeChanged() {
        TUITextMessageCell.outgoingTextColor = nil
        TUITextMessageCell.incommingTextColor = nil
    }
    
    // MARK: - TUITextViewDelegate

    public func onLongPressTextViewMessage(_ textView: UITextView) {
        delegate?.onLongPressMessage(self)
    }
    
    // MARK: - TUIMessageCelllProtocol

    override public class func getEstimatedHeight(_ data: TUIMessageCellData) -> CGFloat {
        return 60.0
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
         
        let shouldHide = getShouldHideOriginalText(for: textCellData)
        
        if !shouldHide {
            var height = super.getHeight(textCellData, withWidth: width)
            if textCellData.bottomContainerSize.height > 0 {
                height += textCellData.bottomContainerSize.height + TUISwift.kScale375(6)
            }
            // Add extra height when container needs to be moved down due to long nameLabel
            if textCellData.topContainerInsetTop > 0 {
                height += textCellData.topContainerInsetTop
            }
            return height
        }
        
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
            height += textCellData.bottomContainerSize.height + TUISwift.kScale375(6)
        }
        
        // Add extra height when container needs to be moved down due to long nameLabel
        if textCellData.topContainerInsetTop > 0 {
            height += textCellData.topContainerInsetTop
        }
        
        return height
    }
        
    static var gMaxTextSize: CGSize = .zero
    class func setMaxTextSize(_ maxTextSize: CGSize) {
        gMaxTextSize = maxTextSize
    }

    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let textCellData = data as? TUITextMessageCellData else {
            assertionFailure("data must be kind of TUITextMessageCellData")
            return .zero
        }

        let shouldHide = getShouldHideOriginalText(for: textCellData)
        
        // When bilingual mode is OFF and translation is shown, hide original text bubble
        if shouldHide {
            textCellData.textSize = .zero
            textCellData.textOrigin = .zero
            return .zero
        }

        let font = (textCellData.direction == .incoming ? incommingTextFont : outgoingTextFont) ?? UIFont()
        let attributeString = textCellData.getContentAttributedString(textFont: font)

        if gMaxTextSize == .zero {
            gMaxTextSize = CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(), height: CGFloat(Int.max))
        }
        let contentSize = textCellData.getContentAttributedStringSize(attributeString: attributeString, maxTextSize: gMaxTextSize)
        textCellData.textSize = contentSize

        let textOrigin = CGPoint(x: textCellData.cellLayout?.bubbleInsets.left ?? 0,
                                 y: textCellData.cellLayout?.bubbleInsets.top ?? 0)
        textCellData.textOrigin = textOrigin

        var height = contentSize.height
        var width = contentSize.width

        height += textCellData.cellLayout?.bubbleInsets.top ?? 0
        height += textCellData.cellLayout?.bubbleInsets.bottom ?? 0

        width += textCellData.cellLayout?.bubbleInsets.left ?? 0
        width += textCellData.cellLayout?.bubbleInsets.right ?? 0

        if textCellData.direction == .incoming {
            height = max(height, TUIBubbleMessageCell.incommingBubble?.size.height ?? 0)
        } else {
            height = max(height, TUIBubbleMessageCell.outgoingBubble?.size.height ?? 0)
        }

        let hasRiskContent = textCellData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            width = max(width, 200) // width must be more than TIMCommonLocalizableString(TUIKitMessageTypeSecurityStrike)
            height += kTUISecurityStrikeViewTopLineMargin
            height += CGFloat(kTUISecurityStrikeViewTopLineToBottom)
        }

        return CGSize(width: width, height: height)
    }
    
    // MARK: - getShouldHideOriginalText
    
    private class func getShouldHideOriginalText(for cellData: TUITextMessageCellData) -> Bool {
        guard let message = cellData.innerMessage else { return false }
        
        // Call TUICore extension to get visibility state
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
}
