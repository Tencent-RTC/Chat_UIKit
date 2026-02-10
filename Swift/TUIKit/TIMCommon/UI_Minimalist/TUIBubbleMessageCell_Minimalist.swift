import UIKit

open class TUIBubbleMessageCell_Minimalist: TUIMessageCell_Minimalist {
    public var bubbleView: UIImageView!
    public var bubbleData: TUIBubbleMessageCellData!

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        _ = Self.setup
        bubbleView = UIImageView(frame: container.bounds)
        bubbleView.isUserInteractionEnabled = true
        container.addSubview(bubbleView)
        bubbleView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIBubbleMessageCellData else { return }
        bubbleData = data

        if bubbleData.sameToNextMsgSender {
            bubbleView.image = getSameMessageBubble()
            bubbleView.highlightedImage = getHighlightSameMessageBubble()
        } else {
            bubbleView.image = getBubble()
            bubbleView.highlightedImage = getHighlightBubble()
        }

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
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
        if let keyword = keyword, !highlightAnimating {
            animate(times: 3)
        }
    }

    func animate(times: Int) {
        var times = times
        times -= 1
        if times < 0 {
            bubbleView.image = bubbleData.sameToNextMsgSender ? getSameMessageBubble() : getBubble()
            bubbleView.layer.cornerRadius = 0
            bubbleView.layer.masksToBounds = true
            highlightAnimating = false
            return
        }

        bubbleView.image = getAnimateHighlightBubbleAlpha50()
        bubbleView.layer.cornerRadius = 12
        bubbleView.layer.masksToBounds = true
        highlightAnimating = true
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

    func getBubble() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell_Minimalist.incommingBubble : TUIBubbleMessageCell_Minimalist.outgoingBubble
    }

    func getHighlightBubble() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell_Minimalist.incommingHighlightedBubble : TUIBubbleMessageCell_Minimalist.outgoingHighlightedBubble
    }

    func getSameMessageBubble() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell_Minimalist.incommingSameBubble : TUIBubbleMessageCell_Minimalist.outgoingSameBubble
    }

    func getHighlightSameMessageBubble() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return getSameMessageBubble()
    }

    func getAnimateHighlightBubbleAlpha50() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell_Minimalist.incommingAnimatedHighlightedAlpha50 : TUIBubbleMessageCell_Minimalist.outgoingAnimatedHighlightedAlpha50
    }

    func getAnimateHighlightBubbleAlpha20() -> UIImage? {
        guard TIMConfig.shared.enableMessageBubble else { return nil }
        return bubbleData.direction == .incoming ? TUIBubbleMessageCell_Minimalist.incommingAnimatedHighlightedAlpha20 : TUIBubbleMessageCell_Minimalist.outgoingAnimatedHighlightedAlpha20
    }

    public static func getBubbleTop(data: TUIBubbleMessageCellData) -> CGFloat {
        return data.direction == .incoming ? incommingBubbleTop : outgoingBubbleTop
    }
}

extension TUIBubbleMessageCell_Minimalist {
    private static var _outgoingBubble: UIImage?
    private static var _outgoingSameBubble: UIImage?
    private static var _outgoingHighlightedBubble: UIImage?
    private static var _outgoingAnimatedHighlightedAlpha20: UIImage?
    private static var _outgoingAnimatedHighlightedAlpha50: UIImage?
        
    private static var _incommingBubble: UIImage?
    private static var _incommingSameBubble: UIImage?
    private static var _incommingHighlightedBubble: UIImage?
    private static var _incommingAnimatedHighlightedAlpha20: UIImage?
    private static var _incommingAnimatedHighlightedAlpha50: UIImage?
    
    fileprivate static let setup: Void = {
        // Removed TUIDidApplyingThemeChangedNotfication observer, use dynamic images instead
    }()
        
    public static var outgoingBubble: UIImage? {
        get {
            if _outgoingBubble == nil {
                let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("SenderTextNodeBkg"))
                setOutgoingBubble(defaultImage)
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
        
    public static var outgoingSameBubble: UIImage? {
        get {
            if _outgoingSameBubble == nil {
                let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("SenderTextNodeBkg_Same"))
                setOutgoingSameBubble(defaultImage)
            }
            return _outgoingSameBubble
        }
        set {
            _outgoingSameBubble = stretchImage(newValue)
        }
    }
        
    static func setOutgoingSameBubble(_ outgoingSameBubble: UIImage?) {
        _outgoingSameBubble = stretchImage(outgoingSameBubble)
    }
        
    public static var outgoingHighlightedBubble: UIImage? {
        get {
            if _outgoingHighlightedBubble == nil {
                let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("SenderTextNodeBkg"))
                setOutgoingHighlightedBubble(defaultImage)
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
        
    public static var incommingBubble: UIImage? {
        get {
            if _incommingBubble == nil {
                let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("ReceiverTextNodeBkg"))
                setIncommingBubble(defaultImage)
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
        
    public static var incommingSameBubble: UIImage? {
        get {
            if _incommingSameBubble == nil {
                let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("ReceiverTextNodeBkg_Same"))
                setIncommingSameBubble(defaultImage)
            }
            return _incommingSameBubble
        }
        set {
            _incommingSameBubble = stretchImage(newValue)
        }
    }
        
    static func setIncommingSameBubble(_ incommingSameBubble: UIImage?) {
        _incommingSameBubble = stretchImage(incommingSameBubble)
    }
        
    public static var incommingHighlightedBubble: UIImage? {
        get {
            if _incommingHighlightedBubble == nil {
                let defaultImage = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("ReceiverTextNodeBkg"))
                setIncommingHighlightedBubble(defaultImage)
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
