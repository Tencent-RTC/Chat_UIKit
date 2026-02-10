import UIKit

open class TUIBubbleMessageCell: TUIMessageCell {
    public var bubbleView: UIImageView!
    public var bubbleData: TUIBubbleMessageCellData!
    
    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        _ = Self.setup
        bubbleView = UIImageView(frame: container.bounds)
        bubbleView.isUserInteractionEnabled = true
        container.addSubview(bubbleView)
        bubbleView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        securityStrikeView = TUISecurityStrikeView()
        bubbleView.addSubview(securityStrikeView)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIBubbleMessageCellData else { return }
        bubbleData = data
        bubbleView.image = getBubble()
        bubbleView.highlightedImage = getHighlightBubble()
        securityStrikeView.isHidden = true
        if let hasRiskContent = messageData?.innerMessage?.hasRiskContent, hasRiskContent {
            bubbleView.image = getErrorBubble()
            securityStrikeView.isHidden = false
        }

        prepareReactTagUI(container)
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    func prepareReactTagUI(_ containerView: UIView) {
        let param: [String: Any] = ["TUICore_TUIChatExtension_ChatMessageReactPreview_Delegate": self]
        _ = TUICore.raiseExtension("TUICore_TUIChatExtension_ChatMessageReactPreview_ClassicExtensionID", parentView: containerView, param: param)
    }

    override open class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override open func updateConstraints() {
        super.updateConstraints()
        bubbleView.snp.remakeConstraints { make in
            make.leading.equalTo(0)
            make.size.equalTo(container)
            make.top.equalTo(container)
        }

        var center = retryView.center
        center.y = bubbleView.center.y
        retryView.center = center
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
    }

    override open func highlightWhenMatchKeyword(_ keyword: String?) {
        if let _ = keyword, !highlightAnimating {
            animate(times: 3)
        }
    }

    private func animate(times: Int) {
        var times = times
        times -= 1
        if times < 0 {
            bubbleView.image = getBubble()
            highlightAnimating = false
            return
        }
        highlightAnimating = true
        bubbleView.image = getAnimateHighlightBubbleAlpha50()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.bubbleView.image = self.getAnimateHighlightBubbleAlpha20()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if self.bubbleData.highlightKeyword == nil {
                    self.animate(times: 0)
                    return
                }
                self.animate(times: times)
            }
        }
    }

    func getBubbleTop() -> CGFloat {
        return TUIBubbleMessageCell.getBubbleTop(bubbleData)
    }
    
    public static func getBubbleTop(_ data: TUIBubbleMessageCellData) -> CGFloat {
        return data.direction == .incoming ? incommingBubbleTop : outgoingBubbleTop
    }

    func getBubble() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell.incommingBubble : TUIBubbleMessageCell.outgoingBubble
    }

    func getHighlightBubble() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell.incommingHighlightedBubble : TUIBubbleMessageCell.outgoingHighlightedBubble
    }

    func getErrorBubble() -> UIImage? {
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell.incommingErrorBubble : TUIBubbleMessageCell.outgoingErrorBubble
    }

    func getAnimateHighlightBubbleAlpha50() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell.incommingAnimatedHighlightedAlpha50 : TUIBubbleMessageCell.outgoingAnimatedHighlightedAlpha50
    }

    func getAnimateHighlightBubbleAlpha20() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell.incommingAnimatedHighlightedAlpha20 : TUIBubbleMessageCell.outgoingAnimatedHighlightedAlpha20
    }
}

extension TUIBubbleMessageCell {
    private static var _outgoingBubble: UIImage?
    private static var _outgoingHighlightedBubble: UIImage?
    private static var _outgoingAnimatedHighlightedAlpha50: UIImage?
    private static var _outgoingAnimatedHighlightedAlpha20: UIImage?
    private static var _outgoingErrorBubble: UIImage?
        
    private static var _incommingBubble: UIImage?
    private static var _incommingHighlightedBubble: UIImage?
    private static var _incommingAnimatedHighlightedAlpha50: UIImage?
    private static var _incommingAnimatedHighlightedAlpha20: UIImage?
    private static var _incommingErrorBubble: UIImage?
    
    fileprivate static let setup: Void = {

    }()
    
    public static var outgoingBubble: UIImage? {
        get {
            if _outgoingBubble == nil {
                if let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("SenderTextNodeBkg")) {
                    setOutgoingBubble(TUISwift.tuiChatDynamicImage("chat_bubble_send_img", defaultImage: defaultImage))
                }
            }
            return _outgoingBubble
        }
        set {
            _outgoingBubble = stretchImage(newValue)
        }
    }
        
    static func setOutgoingBubble(_ outgoingBubble: UIImage?) {
        _outgoingBubble = stretchImage(outgoingBubble)
    }
        
    public static var outgoingHighlightedBubble: UIImage? {
        get {
            if _outgoingHighlightedBubble == nil {
                if let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("SenderTextNodeBkgHL")) {
                    setOutgoingHighlightedBubble(TUISwift.tuiChatDynamicImage("chat_bubble_send_img", defaultImage: defaultImage))
                }
            }
            return _outgoingHighlightedBubble
        }
        set {
            _outgoingHighlightedBubble = stretchImage(newValue)
        }
    }
        
    static func setOutgoingHighlightedBubble(_ outgoingHighlightedBubble: UIImage?) {
        _outgoingHighlightedBubble = stretchImage(outgoingHighlightedBubble)
    }
        
    public static var outgoingAnimatedHighlightedAlpha50: UIImage? {
        get {
            if _outgoingAnimatedHighlightedAlpha50 == nil {
                if let alpha50 = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("SenderTextNodeBkg_alpha50")) {
                    setOutgoingAnimatedHighlightedAlpha50(TUISwift.tuiChatDynamicImage("chat_bubble_send_alpha50_img", defaultImage: alpha50))
                }
            }
            return _outgoingAnimatedHighlightedAlpha50
        }
        set {
            _outgoingAnimatedHighlightedAlpha50 = stretchImage(newValue)
        }
    }
        
    static func setOutgoingAnimatedHighlightedAlpha50(_ outgoingAnimatedHighlightedAlpha50: UIImage?) {
        _outgoingAnimatedHighlightedAlpha50 = stretchImage(outgoingAnimatedHighlightedAlpha50)
    }
        
    public static var outgoingAnimatedHighlightedAlpha20: UIImage? {
        get {
            if _outgoingAnimatedHighlightedAlpha20 == nil {
                if let alpha20 = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("SenderTextNodeBkg_alpha20")) {
                    setOutgoingAnimatedHighlightedAlpha20(TUISwift.tuiChatDynamicImage("chat_bubble_send_alpha20_img", defaultImage: alpha20))
                }
            }
            return _outgoingAnimatedHighlightedAlpha20
        }
        set {
            _outgoingAnimatedHighlightedAlpha20 = stretchImage(newValue)
        }
    }
        
    static func setOutgoingAnimatedHighlightedAlpha20(_ outgoingAnimatedHighlightedAlpha20: UIImage?) {
        _outgoingAnimatedHighlightedAlpha20 = stretchImage(outgoingAnimatedHighlightedAlpha20)
    }
        
    public static var outgoingErrorBubble: UIImage? {
        get {
            if _outgoingErrorBubble == nil {
                if let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("SenderTextNodeBkg")) {
                    let image = TUISwift.tuiChatDynamicImage("chat_bubble_send_img", defaultImage: defaultImage)
                    let color = UIColor.tui_color(withHex: "#FA5151", alpha: 0.16)
                    let formatImage = TUISecurityStrikeView.changeImageColor(with: color, image: image, alpha: 1)
                    _outgoingErrorBubble = stretchImage(formatImage)
                }
            }
            return _outgoingErrorBubble
        }
        set {
            _outgoingErrorBubble = stretchImage(newValue)
        }
    }
        
    public static var incommingBubble: UIImage? {
        get {
            if _incommingBubble == nil {
                if let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("ReceiverTextNodeBkg")) {
                    setIncommingBubble(TUISwift.tuiChatDynamicImage("chat_bubble_receive_img", defaultImage: defaultImage))
                }
            }
            return _incommingBubble
        }
        set {
            _incommingBubble = stretchImage(newValue)
        }
    }
        
    static func setIncommingBubble(_ incommingBubble: UIImage?) {
        _incommingBubble = stretchImage(incommingBubble)
    }
        
    public static var incommingHighlightedBubble: UIImage? {
        get {
            if _incommingHighlightedBubble == nil {
                if let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("ReceiverTextNodeBkgHL")) {
                    setIncommingHighlightedBubble(TUISwift.tuiChatDynamicImage("chat_bubble_receive_img", defaultImage: defaultImage))
                }
            }
            return _incommingHighlightedBubble
        }
        set {
            _incommingHighlightedBubble = stretchImage(newValue)
        }
    }
        
    static func setIncommingHighlightedBubble(_ incommingHighlightedBubble: UIImage?) {
        _incommingHighlightedBubble = stretchImage(incommingHighlightedBubble)
    }
        
    public static var incommingAnimatedHighlightedAlpha50: UIImage? {
        get {
            if _incommingAnimatedHighlightedAlpha50 == nil {
                if let alpha50 = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("ReceiverTextNodeBkg_alpha50")) {
                    setIncommingAnimatedHighlightedAlpha50(TUISwift.tuiChatDynamicImage("chat_bubble_receive_alpha50_img", defaultImage: alpha50))
                }
            }
            return _incommingAnimatedHighlightedAlpha50
        }
        set {
            _incommingAnimatedHighlightedAlpha50 = stretchImage(newValue)
        }
    }
        
    static func setIncommingAnimatedHighlightedAlpha50(_ incommingAnimatedHighlightedAlpha50: UIImage?) {
        _incommingAnimatedHighlightedAlpha50 = stretchImage(incommingAnimatedHighlightedAlpha50)
    }
        
    public static var incommingAnimatedHighlightedAlpha20: UIImage? {
        get {
            if _incommingAnimatedHighlightedAlpha20 == nil {
                if let alpha20 = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("ReceiverTextNodeBkg_alpha20")) {
                    setIncommingAnimatedHighlightedAlpha20(TUISwift.tuiChatDynamicImage("chat_bubble_receive_alpha20_img", defaultImage: alpha20))
                }
            }
            return _incommingAnimatedHighlightedAlpha20
        }
        set {
            _incommingAnimatedHighlightedAlpha20 = stretchImage(newValue)
        }
    }
        
    static func setIncommingAnimatedHighlightedAlpha20(_ incommingAnimatedHighlightedAlpha20: UIImage?) {
        _incommingAnimatedHighlightedAlpha20 = stretchImage(incommingAnimatedHighlightedAlpha20)
    }
        
    public static var incommingErrorBubble: UIImage? {
        get {
            if _incommingErrorBubble == nil {
                if let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("ReceiverTextNodeBkg")) {
                    let image = TUISwift.tuiChatDynamicImage("chat_bubble_receive_img", defaultImage: defaultImage)
                    let color = UIColor.tui_color(withHex: "#FA5151", alpha: 0.16)
                    let formatImage = TUISecurityStrikeView.changeImageColor(with: color, image: image, alpha: 1)
                    _incommingErrorBubble = stretchImage(formatImage)
                }
            }
            return _incommingErrorBubble
        }
        set {
            _incommingErrorBubble = stretchImage(newValue)
        }
    }
        
    static func stretchImage(_ oldImage: UIImage?) -> UIImage? {
        guard let image = oldImage?.rtlImageFlippedForRightToLeftLayoutDirection() else { return nil }
        let insets = rtlEdgeInsetsWithInsets(UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12))
        return image.resizableImage(withCapInsets: insets, resizingMode: .stretch)
    }
        
    static var outgoingBubbleTop: CGFloat = 0
    static var incommingBubbleTop: CGFloat = 0
        
    @objc static func onThemeChanged(_ notification: Notification) {
        _outgoingBubble = nil
        _outgoingHighlightedBubble = nil
        _outgoingAnimatedHighlightedAlpha50 = nil
        _outgoingAnimatedHighlightedAlpha20 = nil
            
        _incommingBubble = nil
        _incommingHighlightedBubble = nil
        _incommingAnimatedHighlightedAlpha50 = nil
        _incommingAnimatedHighlightedAlpha20 = nil
    }
}
