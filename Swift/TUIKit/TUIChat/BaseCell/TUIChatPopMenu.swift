import TIMCommon
import TUICore
import UIKit

public typealias TUIChatPopMenuActionCallback = () -> Void
public typealias TUIChatPopMenuHideCallback = () -> Void
public class TUIChatPopMenuAction {
    public var title: String
    public var image: UIImage
    public var callback: TUIChatPopMenuActionCallback
    public var weight: Int
    
    public init(title: String, image: UIImage, weight: Int, callback: @escaping TUIChatPopMenuActionCallback) {
        self.title = title
        self.image = image
        self.weight = weight
        self.callback = callback
    }
}

public class TUIChatPopMenu: UIView, UIGestureRecognizerDelegate, V2TIMAdvancedMsgListener {
    let maxColumns = 5
    let kContainerInsets = UIEdgeInsets(top: 3, left: 0, bottom: 3, right: 0)
    let kActionWidth: CGFloat = 54
    let kActionHeight: CGFloat = 65
    let kActionMargin: CGFloat = 5
    let kSeparatorHeight: CGFloat = 0.5
    let kSeparatorLRMargin: CGFloat = 10
    let kArrowSize = CGSize(width: 15, height: 10)
    let kEmojiHeight: CGFloat = 44
    
    var hideCallback: TUIChatPopMenuHideCallback?
    var reactClickCallback: ((String) -> Void)?
    public weak var targetCellData: TUIMessageCellData?
    weak var targetCell: TUIMessageCell?
    
    public var emojiContainerView: UIView? = .init()
    public var containerView: UIView? = .init()
    private var actions = [TUIChatPopMenuAction]()
    private var arrawPoint = CGPoint.zero
    private var adjustHeight: CGFloat = 0
    private var actionCallback = [Int: TUIChatPopMenuActionCallback]()
    private var arrowLayer = CAShapeLayer()
    private var emojiHeight: CGFloat = 0
    private var actionsView: TUIChatPopActionsView?
    private var hasEmojiView = false
    
    // MARK: - Init

    convenience init(hasEmojiView: Bool, frame: CGRect) {
        self.init(frame: frame)
        self.hasEmojiView = hasEmojiView
        if isAddEmojiView() {
            emojiHeight = kEmojiHeight
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onTap(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        tap.delegate = self
        pan.delegate = self
        addGestureRecognizer(tap)
        addGestureRecognizer(pan)
        
        NotificationCenter.default.addObserver(self, selector: #selector(hideWithAnimation), name:
            Notification.Name("kTUIChatPopMenuWillHideNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(hideWithAnimation), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        // Use system traitCollectionDidChange instead of TUIDidApplyingThemeChangedNotfication
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: self)
    }
    
    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let touchView = touch.view, let emojiContainerView = emojiContainerView {
            if touchView.isDescendant(of: emojiContainerView) {
                return false
            }
        }
        if let touchView = touch.view, let containerView = containerView {
            if touchView.isDescendant(of: containerView) {
                return false
            }
        }

        if #available(iOS 17.0, *) {
            if let nextResponder = touch.view?.next as? UIView {
                let touchPoint = touch.location(in: nextResponder)
                if let frame = self.targetCell?.frame, frame.contains(touchPoint) {
                    return false
                }
            }
        }
        return true
    }
    
    // MARK: - V2TIMAdvancedMsgListener

    public func onRecvMessageRevoked(msgID: String, operateUser: V2TIMUserFullInfo, reason: String?) {
        if msgID == targetCellData?.msgID {
            hideWithAnimation()
        }
    }
    
    // MARK: - ThemeChanged

    private func applyBorderTheme() {
        arrowLayer.fillColor = TUISwift.tuiChatDynamicColor("chat_pop_menu_bg_color", defaultColor: "#FFFFFF").cgColor
    }
    
    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 13.0, *) {
            if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
                applyBorderTheme()
            }
        }
    }
    
    // MARK: - Public

    public func addAction(_ action: TUIChatPopMenuAction) {
        actions.append(action)
    }
    
    func removeAllAction() {
        actions.removeAll()
    }
    
    public func setArrawPosition(_ point: CGPoint, adjustHeight: CGFloat) {
        arrawPoint = CGPoint(x: point.x, y: point.y - TUISwift.navBar_Height())
        self.adjustHeight = adjustHeight
    }
    
    public func showInView(_ window: UIView?) {
        guard let window = window ?? TUITool.applicationKeywindow() else { return }
        frame = window.bounds
        window.addSubview(self)
        layoutSubview()
    }
    
    @objc public func hideWithAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { finished in
            if finished {
                self.hideCallback?()
                self.removeFromSuperview()
            }
        }
    }

    func layoutSubview() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowRadius = 5
        layer.shadowOpacity = 0.5
        
        updateActionByRank()
        
        if isAddEmojiView() {
            prepareEmojiView()
        }
        
        prepareContainerView()
        
        if isAddEmojiView() {
            setupEmojiSubView()
        }
        
        setupContainerPosition()
        updateLayout()
        
        if TUISwift.isRTL() {
            fitRTLViews()
        }
    }
    
    // MARK: - Private
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if #available(iOS 17.0, *) {
            guard let superview = self.superview else {
                return super.hitTest(point, with: event)
            }
            
            let touchPoint = superview.convert(point, from: self)
            
            guard let targetCell = targetCell else {
                return super.hitTest(point, with: event)
            }
            
            let frame = targetCell.frame
            let containerFrame = superview.convert(targetCell.container.frame, from: targetCell)
            
            guard let containerView = containerView else {
                return super.hitTest(point, with: event)
            }
            
            let popFrame2 = superview.convert(containerView.frame, from: self)
            if popFrame2.contains(touchPoint) {
                return super.hitTest(point, with: event)
            }
            
            if frame.contains(touchPoint) {
                if let targetCell = self.targetCell, targetCell.responds(to: NSSelectorFromString("textView")) {
                    if let textView = targetCell.value(forKey: "textView") as? UITextView {
                        if containerFrame.contains(touchPoint) {
                            if !textView.isSelectable {
                                textView.selectAll(self)
                            }
                            return textView
                        } else {
                            textView.selectAll(nil)
                            hideWithAnimation()
                        }
                    }
                } else {
                    hideWithAnimation()
                }
                return super.hitTest(point, with: event)
            }
            return super.hitTest(point, with: event)
        } else {
            return super.hitTest(point, with: event)
        }
    }

    private func isAddEmojiView() -> Bool {
        return hasEmojiView && TUIChatConfig.shared.enablePopMenuEmojiReactAction
    }
    
    @objc private func onTap(_ gesture: UIGestureRecognizer) {
        hideWithAnimation()
    }

    private func fitRTLViews() {
        guard actionsView != nil else { return }
        for subview in actionsView!.subviews {
            if subview.responds(to: #selector(resetFrameToFitRTL)) {
                subview.perform(#selector(resetFrameToFitRTL))
            }
        }
    }
    
    private func updateActionByRank() {
        actions.sort { $0.weight > $1.weight }
    }
    
    private func setupContainerPosition() {
        guard let containerView = containerView else { return }
        // Calculate the coordinates and correct them, the default arrow points down
        let minTopBottomMargin: CGFloat = TUISwift.is_IPhoneX() ? 100 : 0.0
        let minLeftRightMargin: CGFloat = 50
        let containerW = containerView.bounds.size.width
        let containerH = containerView.bounds.size.height
        let upContainerY = arrawPoint.y + adjustHeight + kArrowSize.height // The containerY value when arrow points up

        // The default arrow points down
        var containerX = arrawPoint.x - 0.5 * containerW
        var containerY = arrawPoint.y - kArrowSize.height - containerH - TUISwift.statusBar_Height() - emojiHeight
        var top = false // The direction of arrow, here is down
        var arrawX = 0.5 * containerW
        var arrawY = kArrowSize.height + containerH - 1.5

        // Corrected vertical coordinates
        if containerY < minTopBottomMargin {
            // The container is too high, and it is planned to adjust the direction of the arrow to upward.
            if let superview = superview, upContainerY + containerH + minTopBottomMargin > superview.bounds.size.height {
                /**
                 * After adjusting the upward arrow direction, it will cause the entire container to exceed the screen. At this time, the adjustment strategy is
                 * changed to: keep the arrow direction downward and move self.arrawPoint
                 */
                top = false
                arrawPoint = CGPoint(x: arrawPoint.x, y: arrawPoint.y - containerY)
                containerY = arrawPoint.y - kArrowSize.height - containerH

            } else {
                // Adjust the direction of the arrow to meet the requirements
                top = true
                arrawPoint = CGPoint(x: arrawPoint.x, y: arrawPoint.y + adjustHeight - TUISwift.statusBar_Height() - 5)
                arrawY = -kArrowSize.height
                containerY = arrawPoint.y + kArrowSize.height
            }
        }

        // Corrected horizontal coordinates
        if containerX < minLeftRightMargin {
            // The container is too close to the left side of the screen and needs to move to the right
            let offset = minLeftRightMargin - containerX
            arrawX -= offset
            containerX += offset
            if arrawX < 20 {
                arrawX = 20
            }

        } else if containerX + containerW + minLeftRightMargin > bounds.size.width {
            /**
             * At this time, the container is too close to the right side of the screen and needs to be moved to the left
             */
            let offset = containerX + containerW + minLeftRightMargin - bounds.size.width
            arrawX += offset
            containerX -= offset
            if arrawX > containerW - 20 {
                arrawX = containerW - 20
            }
        }

        if let emojiContainerView = emojiContainerView {
            emojiContainerView.frame = CGRect(x: containerX, y: containerY, width: containerW, height: max(emojiHeight + containerH, 200))
        }
        containerView.frame = CGRect(x: containerX, y: containerY + emojiHeight, width: containerW, height: containerH)

        /**
         * Drawing arrow
         */
        arrowLayer = CAShapeLayer()
        arrowLayer.path = arrawPath(CGPoint(x: arrawX, y: arrawY), directionTop: top).cgPath
        arrowLayer.fillColor = TUISwift.tuiChatDynamicColor("chat_pop_menu_bg_color", defaultColor: "#FFFFFF").cgColor
        if top {
            if emojiContainerView != nil {
                emojiContainerView!.layer.addSublayer(arrowLayer)
            } else {
                containerView.layer.addSublayer(arrowLayer)
            }
        } else {
            containerView.layer.addSublayer(arrowLayer)
        }
    }
    
    private func prepareEmojiView() {
        emojiContainerView?.removeFromSuperview()
        emojiContainerView = nil
        emojiContainerView = UIView()
        addSubview(emojiContainerView!)
    }
    
    private func prepareContainerView() {
        if containerView != nil {
            containerView?.removeFromSuperview()
            containerView = nil
        }
        containerView = UIView()
        addSubview(containerView!)

        actionsView = TUIChatPopActionsView()
        actionsView!.backgroundColor = TUISwift.tuiChatDynamicColor("chat_pop_menu_bg_color", defaultColor: "#FFFFFF")
        containerView!.addSubview(actionsView!)

        var i = 0
        for j in 0 ..< actions.count {
            let action = actions[j]
            let actionButton = buttonWithAction(action, tag: j)
            actionsView!.addSubview(actionButton)
            i += 1
            if i == maxColumns && i < actions.count {
                let separatorView = UIView()
                separatorView.backgroundColor = TUISwift.timCommonDynamicColor("separator_color", defaultColor: "#39393B")
                separatorView.isHidden = true
                actionsView!.addSubview(separatorView)
                i = 0
            }
        }
        /**
         * Calculating the size of container
         */
        let rows = (actions.count % maxColumns == 0) ? actions.count / maxColumns : (actions.count / maxColumns) + 1
        var columns = actions.count < maxColumns ? actions.count : maxColumns
        if isAddEmojiView() {
            columns = maxColumns
        }
        let width = kActionWidth * CGFloat(columns) + kActionMargin * CGFloat(columns + 1) + kContainerInsets.left + kContainerInsets.right
        let height = kActionHeight * CGFloat(rows) + CGFloat(rows - 1) * 0.5 + kContainerInsets.top + kContainerInsets.bottom

        emojiContainerView?.frame = CGRect(x: 0, y: 0, width: width, height: emojiHeight + height)
        containerView!.frame = CGRect(x: 0, y: emojiHeight, width: width, height: height)
    }
    
    private func setupEmojiSubView() {
        setupEmojiRecentView()
        setupEmojiAdvanceView()
    }
    
    private func setupEmojiRecentView() {
        guard let emojiContainerView = emojiContainerView else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_ChatPopMenuReactRecentView_Delegate": self]
        let success = TUICore.raiseExtension("TUICore_TUIChatExtension_ChatPopMenuReactRecentView_ClassicExtensionID", parentView: emojiContainerView, param: param)
        if !success {
            emojiHeight = 0
        }
    }
    
    private func setupEmojiAdvanceView() {
        guard let emojiContainerView = emojiContainerView else { return }
        let param: [String: Any] = ["TUICore_TUIChatExtension_ChatPopMenuReactRecentView_Delegate": self]
        TUICore.raiseExtension("TUICore_TUIChatExtension_ChatPopMenuReactDetailView_ClassicExtensionID", parentView: emojiContainerView, param: param)
    }

    private func updateLayout() {
        guard let containerView = containerView else { return }
        actionsView?.frame = CGRect(x: 0, y: -0.5, width: containerView.frame.size.width, height: containerView.frame.size.height)

        let columns = actions.count < maxColumns ? actions.count : maxColumns
        let containerWidth = kActionWidth * CGFloat(columns) + kActionMargin * CGFloat(columns + 1) + kContainerInsets.left + kContainerInsets.right

        var i = 0
        var currentRow = 0
        var currentColumn = 0

        for subView in actionsView?.subviews ?? [] {
            if subView is UIButton {
                currentRow = i / maxColumns
                currentColumn = i % maxColumns

                let x = kContainerInsets.left + CGFloat(currentColumn + 1) * kActionMargin + CGFloat(currentColumn) * kActionWidth
                let y = kContainerInsets.top + CGFloat(currentRow) * kActionHeight + CGFloat(currentRow) * kSeparatorHeight
                subView.frame = CGRect(x: x, y: y, width: kActionWidth, height: kActionHeight)

                i += 1
            } else {
                let y = CGFloat(currentRow + 1) * kActionHeight + kContainerInsets.top
                let width = containerWidth - 2 * kSeparatorLRMargin - kContainerInsets.left - kContainerInsets.right
                subView.frame = CGRect(x: kSeparatorLRMargin, y: y, width: width, height: kSeparatorHeight)
            }
        }
    }
    
    private func arrawPath(_ point: CGPoint, directionTop: Bool) -> UIBezierPath {
        let arrowSize = kArrowSize
        let arrowPath = UIBezierPath()
        arrowPath.move(to: point)
        if directionTop {
            arrowPath.addLine(to: CGPoint(x: point.x + arrowSize.width * 0.5, y: point.y + arrowSize.height))
            arrowPath.addLine(to: CGPoint(x: point.x - arrowSize.width * 0.5, y: point.y + arrowSize.height))
        } else {
            arrowPath.addLine(to: CGPoint(x: point.x + arrowSize.width * 0.5, y: point.y - arrowSize.height))
            arrowPath.addLine(to: CGPoint(x: point.x - arrowSize.width * 0.5, y: point.y - arrowSize.height))
        }
        arrowPath.close()
        return arrowPath
    }
    
    private func buttonWithAction(_ action: TUIChatPopMenuAction, tag: Int) -> UIButton {
        let actionButton = UIButton(type: .custom)
        actionButton.setTitleColor(TUISwift.tuiChatDynamicColor("chat_pop_menu_text_color", defaultColor: "#444444"), for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 10.0)
        actionButton.titleLabel?.numberOfLines = 2
        actionButton.titleLabel?.lineBreakMode = .byWordWrapping
        actionButton.setTitle(action.title, for: .normal)
        actionButton.setImage(action.image, for: .normal)
        actionButton.contentMode = .scaleAspectFit
        
        actionButton.addTarget(self, action: #selector(buttonHighlightedEnter(_:)), for: .touchDown)
        actionButton.addTarget(self, action: #selector(buttonHighlightedEnter(_:)), for: .touchDragEnter)
        actionButton.addTarget(self, action: #selector(buttonHighlightedExit(_:)), for: .touchDragExit)
        actionButton.addTarget(self, action: #selector(onClick(_:)), for: .touchUpInside)
        
        actionButton.tag = tag
        
        let imageSize = CGSize(width: 20, height: 20)
        let titleSize = actionButton.titleLabel?.frame.size ?? .zero
        let textSize = actionButton.titleLabel?.text?.size(withAttributes: [.font: actionButton.titleLabel?.font ?? UIFont.systemFont(ofSize: 10.0)]) ?? .zero
        let frameSize = CGSize(width: ceil(textSize.width), height: ceil(textSize.height))
        var adjustedTitleSize = titleSize
        if titleSize.width + 0.5 < frameSize.width {
            adjustedTitleSize.width = frameSize.width
        }
        adjustedTitleSize.width = min(adjustedTitleSize.width, 48)
        let totalHeight = imageSize.height + adjustedTitleSize.height + 8
        actionButton.imageEdgeInsets = UIEdgeInsets(top: -(totalHeight - imageSize.height), left: 0.0, bottom: 0.0, right: -adjustedTitleSize.width)
        actionButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: -imageSize.width, bottom: -(totalHeight - adjustedTitleSize.height), right: 0)
        
        actionCallback[tag] = action.callback
        
        return actionButton
    }
    
    @objc private func buttonHighlightedEnter(_ sender: UIButton) {
        sender.backgroundColor = TUISwift.tuiChatDynamicColor("", defaultColor: "#006EFF19")
    }
    
    @objc private func buttonHighlightedExit(_ sender: UIButton) {
        sender.backgroundColor = .clear
    }
    
    @objc private func onClick(_ button: UIButton) {
        guard let callback = actionCallback[button.tag] else {
            hideWithAnimation()
            return
        }
        
        hideByClickButton(button) {
            callback()
        }
    }
    
    private func hideByClickButton(_ button: UIButton, callback: (() -> Void)?) {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { finished in
            if finished {
                callback?()
                self.hideCallback?()
                self.removeFromSuperview()
            }
        }
    }
}
