import ImSDK_Plus
import TIMCommon
import UIKit

enum BlurEffectStyle: UInt {
    case light
    case extraLight
    case darkEffect
}

public class TUIChatPopContextController: UIViewController, V2TIMAdvancedMsgListener {
    let defaultEmojiSize = CGSize(width: 23, height: 23)

    var alertCellClass: TUIMessageCell.Type?
    public var alertViewCellData: TUIMessageCellData?
    var originFrame: CGRect = .zero
    var viewWillShowHandler: ((TUIMessageCell) -> Void)?
    var viewDidShowHandler: ((TUIMessageCell) -> Void)?
    var dismissComplete: (() -> Void)?
    var reactClickCallback: ((String) -> Void)?
    var items: [TUIChatPopContextExtensionItem]? = []
    public  var isConfigRecentView :Bool = true

    private var recentView: UIView!
    private var alertContainerView: UIView?
    private var alertView: TUIMessageCell?
    private var extensionView: TUIChatPopContextExtensionView!
    private var backgroundColor: UIColor = .clear
    private var singleTap: UITapGestureRecognizer!

    private var _backgroundView: UIView?
    var backgroundView: UIView? {
        get {
            return _backgroundView
        }
        set {
            if _backgroundView == nil {
                _backgroundView = newValue
            } else if _backgroundView != newValue {
                guard let newBackgroundView = newValue else { return }
                newBackgroundView.translatesAutoresizingMaskIntoConstraints = false
                view.insertSubview(newBackgroundView, aboveSubview: _backgroundView!)
                addConstraintToView(newBackgroundView, edgeInset: .zero)
                newBackgroundView.alpha = 0
                UIView.animate(withDuration: 0.3, animations: {
                    newBackgroundView.alpha = 1
                }, completion: { [weak self] _ in
                    guard let self else { return }
                    self._backgroundView?.removeFromSuperview()
                    self._backgroundView = newBackgroundView
                    self.addSingleTapGesture()
                })
            }
        }
    }

    var backgoundTapDismissEnable: Bool = false {
        didSet {
            singleTap?.isEnabled = backgoundTapDismissEnable
        }
    }

    // MARK: - Init

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        configureController()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureController() {
        providesPresentationContextTransitionStyle = true
        definesPresentationContext = true
        modalPresentationStyle = .custom

        backgroundColor = .clear
        backgoundTapDismissEnable = true
        isConfigRecentView = true
        V2TIMManager.sharedInstance().addAdvancedMsgListener(listener: self)
    }

    // MARK: - Life cycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        addBackgroundView()
        addSingleTapGesture()
        configureAlertView()
        configRecentView()
        configExtensionView()

        view.layoutIfNeeded()
        showHapticFeedback()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewWillShowHandler?(alertView ?? TUIMessageCell())
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewDidShowHandler?(alertView ?? TUIMessageCell())
        adjustViewPositions()
    }

    // MARK: - V2TIMAdvancedMsgListener

    public func onRecvMessageRevoked(msgID: String, operateUser: V2TIMUserFullInfo, reason: String?) {
        if msgID == alertViewCellData?.msgID {
            var controller: UIViewController = self
            while let presentingViewController = controller.presentingViewController {
                controller = presentingViewController
            }
            controller.dismiss(animated: true) {
                self.blurDismissViewController(animated: false, completion: nil)
            }
        }
    }

    // MARK: - Setup views

    func addBackgroundView() {
        if _backgroundView == nil {
            let newBackgroundView = UIView()
            newBackgroundView.backgroundColor = backgroundColor
            _backgroundView = newBackgroundView
        }
        _backgroundView!.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(_backgroundView!, at: 0)
        addConstraintToView(_backgroundView!, edgeInset: .zero)
    }

    private func addSingleTapGesture() {
        view.isUserInteractionEnabled = true
        backgroundView?.isUserInteractionEnabled = true

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTap(_:)))
        singleTap.isEnabled = backgoundTapDismissEnable

        backgroundView?.addGestureRecognizer(singleTap)
        self.singleTap = singleTap
    }

    @objc private func singleTap(_ sender: UITapGestureRecognizer) {
        dismiss(animated: false)
    }

    private func configureAlertView() {
        guard let alertCellClass = alertCellClass else { return }

        alertContainerView = UIView()
        view.addSubview(alertContainerView!)

        alertView = alertCellClass.init()
        alertContainerView!.addSubview(alertView!)
        alertView!.isUserInteractionEnabled = true

        if let cls = NSClassFromString("TUIChat.TUIMergeMessageCell_Minimalist"), alertView!.isKind(of: cls) {
            alertView!.isUserInteractionEnabled = false
        }

        if let cellData = alertViewCellData {
            alertView!.fill(with: cellData)
        }

        alertView!.layoutIfNeeded()

        alertContainerView!.frame = CGRect(x: 0, y: originFrame.origin.y, width: view.frame.size.width, height: originFrame.size.height)
        alertView!.frame = CGRect(x: 0, y: 0, width: alertContainerView!.frame.size.width, height: alertContainerView!.frame.size.height)

        for subview in alertView!.contentView.subviews {
            if subview != alertView!.container {
                subview.isHidden = true
            }
        }

        alertView!.container.snp.remakeConstraints { make in
            make.leading.equalTo(originFrame.origin.x)
            make.top.equalTo(0)
            make.size.equalTo(originFrame.size)
        }
    }

    private func configRecentView() {
        recentView = UIView()
        recentView.backgroundColor = .clear
        view.addSubview(recentView)

        recentView.frame = CGRect(
            x: originFrame.origin.x,
            y: originFrame.origin.y - TUISwift.kScale390(8 + 40),
            width: max(defaultEmojiSize.width * 8, TUISwift.kScale390(208)),
            height: TUISwift.kScale390(40)
        )

        if (!isConfigRecentView) {
            recentView.alpha = 0
        }
        let param: [String: Any] = ["TUICore_TUIChatExtension_ChatPopMenuReactRecentView_Delegate": self]
        TUICore.raiseExtension(
            "TUICore_TUIChatExtension_ChatPopMenuReactRecentView_MinimalistExtensionID",
            parentView: recentView,
            param: param
        )
    }

    private func configExtensionView() {
        extensionView = TUIChatPopContextExtensionView()
        extensionView.backgroundColor = UIColor.tui_color(withHex: "f9f9f9")
        extensionView.layer.cornerRadius = TUISwift.kScale390(16)
        view.addSubview(extensionView)

        let height = configAndCalculateExtensionHeight()
        extensionView.frame = CGRect(
            x: originFrame.origin.x,
            y: originFrame.origin.y + originFrame.size.height + TUISwift.kScale390(8),
            width: TUISwift.kScale390(180),
            height: height
        )
    }

    func updateExtensionView() {
        let height = configAndCalculateExtensionHeight()
        extensionView.frame = CGRect(
            x: extensionView.frame.origin.x,
            y: extensionView.frame.origin.y,
            width: extensionView.frame.size.width,
            height: height
        )
    }

    private func configAndCalculateExtensionHeight() -> CGFloat {
        guard let items = items else { return 0 }
        var height: CGFloat = 0

        for _ in items {
            height += TUISwift.kScale390(40)
        }

        let topMargin = TUISwift.kScale390(6)
        let bottomMargin = TUISwift.kScale390(6)
        height += topMargin + bottomMargin

        extensionView.configUI(with: items, topBottomMargin: topMargin)
        return height
    }

    private func showHapticFeedback() {
        if #available(iOS 10.0, *) {
            DispatchQueue.main.async {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                generator.impactOccurred()
            }
        }
    }

    // MARK: - Add constraints

    private func addConstraintToView(_ view: UIView, edgeInset: UIEdgeInsets) {
        addConstraintWithView(view, topView: self.view, leftView: self.view, bottomView: self.view, rightView: self.view, edgeInset: edgeInset)
    }

    private func addConstraintWithView(_ view: UIView, topView: UIView?, leftView: UIView?, bottomView: UIView?, rightView: UIView?, edgeInset: UIEdgeInsets) {
        view.translatesAutoresizingMaskIntoConstraints = false

        if let topView = topView {
            self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: topView, attribute: .top, multiplier: 1, constant: edgeInset.top))
        }

        if let leftView = leftView {
            self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .left, relatedBy: .equal, toItem: leftView, attribute: .left, multiplier: 1, constant: edgeInset.left))
        }

        if let rightView = rightView {
            self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .right, relatedBy: .equal, toItem: rightView, attribute: .right, multiplier: 1, constant: -edgeInset.right))
        }

        if let bottomView = bottomView {
            self.view.addConstraint(NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: bottomView, attribute: .bottom, multiplier: 1, constant: -edgeInset.bottom))
        }
    }

    // MARK: - Adjust view

    private func adjustViewPositions() {
        var moveY: CGFloat = 0
        if recentView.frame.origin.y < TUISwift.navBar_Height() {
            let deal = TUISwift.navBar_Height() - recentView.frame.origin.y
            moveY = deal + TUISwift.navBar_Height() + 50
        }

        var moveX: CGFloat = 0
        if recentView.frame.origin.x + recentView.frame.size.width > view.frame.size.width {
            let deal = recentView.frame.origin.x + recentView.frame.size.width - view.frame.size.width
            moveX = deal + 5
        }

        if extensionView.frame.origin.y + extensionView.frame.size.height > view.frame.size.height {
            let deal = extensionView.frame.origin.y + extensionView.frame.size.height - view.frame.size.height
            moveY = -deal - 50
        }

        let oneScreenCanFillCheck = recentView.frame.size.height + originFrame.size.height + extensionView.frame.size.height + TUISwift.kScale390(100) > view.bounds.size.height

        if oneScreenCanFillCheck {
            adjustForSingleScreen(moveX: moveX)
        } else {
            adjustForMultipleScreens(moveX: moveX, moveY: moveY)
        }
    }

    private func adjustForSingleScreen(moveX: CGFloat) {
        let recentViewMoveY = TUISwift.navBar_Height() + 50

        recentView.frame = CGRect(x: recentView.frame.origin.x - moveX, y: recentViewMoveY, width: recentView.frame.size.width, height: recentView.frame.size.height)

        UIView.animate(withDuration: 0.3) {
            if let alertContainerView = self.alertContainerView {
                alertContainerView.frame = CGRect(x: 0, y: self.recentView.frame.origin.y + TUISwift.kScale390(8) + self.recentView.frame.size.height, width: self.view.frame.size.width, height: self.originFrame.size.height)
            }
        }

        let deal = extensionView.frame.origin.y + extensionView.frame.size.height - view.frame.size.height
        let extensionViewMoveY = -deal - 50

        extensionView.frame = CGRect(x: extensionView.frame.origin.x - moveX, y: extensionView.frame.origin.y + extensionViewMoveY, width: extensionView.frame.size.width, height: extensionView.frame.size.height)
        extensionView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.5) {
            self.extensionView.transform = .identity
        }
    }

    private func adjustForMultipleScreens(moveX: CGFloat, moveY: CGFloat) {
        if moveY != 0 {
            UIView.animate(withDuration: 0.3) {
                if let alertContainerView = self.alertContainerView {
                    alertContainerView.frame = CGRect(x: 0, y: self.originFrame.origin.y + moveY, width: self.view.frame.size.width, height: self.originFrame.size.height)
                }
            }
        }

        recentView.frame = CGRect(x: recentView.frame.origin.x - moveX, y: recentView.frame.origin.y, width: recentView.frame.size.width, height: recentView.frame.size.height)
        UIView.animate(withDuration: 0.2) {
            self.recentView.frame = CGRect(x: self.recentView.frame.origin.x, y: self.recentView.frame.origin.y + moveY, width: self.recentView.frame.size.width, height: self.recentView.frame.size.height)
        }

        extensionView.frame = CGRect(x: extensionView.frame.origin.x - moveX, y: extensionView.frame.origin.y + moveY, width: extensionView.frame.size.width, height: extensionView.frame.size.height)
        extensionView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        UIView.animate(withDuration: 0.5) {
            self.extensionView.transform = .identity
        }
    }

    func dismiss(animated: Bool) {
        UIView.animate(withDuration: 0.3) {
            self.recentView.frame = CGRect(x: self.recentView.frame.origin.x, y: self.originFrame.origin.y - self.recentView.frame.size.height, width: self.recentView.frame.size.width, height: self.recentView.frame.size.height)
        }

        UIView.animate(withDuration: 0.3) {
            if let alertContainerView = self.alertContainerView {
                alertContainerView.frame = CGRect(x: 0, y: self.originFrame.origin.y, width: self.view.frame.size.width, height: self.originFrame.size.height)
            }
        } completion: { finished in
            if finished {
                self.dismiss(animated: animated, completion: self.dismissComplete)
            }
        }

        extensionView.transform = .identity
        UIView.animate(withDuration: 0.2) {
            self.extensionView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        } completion: { finished in
            if finished {
                self.extensionView.transform = .identity
            }
        }
    }

    // MARK: Public

    func setBlurEffect(with view: UIView) {
        setBlurEffect(with: view, style: .darkEffect)
    }

    private func setBlurEffect(with view: UIView, style: BlurEffectStyle) {
        let snapshotImage = UIImage.snapshotImage(with: view)
        let blurImage = blurImage(with: snapshotImage, style: style)
        DispatchQueue.main.async {
            let blurImageView = UIImageView(image: blurImage)
            self.backgroundView = blurImageView
        }
    }

    private func setBlurEffect(with view: UIView, effectTintColor: UIColor) {
        let snapshotImage = UIImage.snapshotImage(with: view)
        let blurImage = snapshotImage.applyTintEffect(withColor: effectTintColor)
        let blurImageView = UIImageView(image: blurImage)
        backgroundView = blurImageView
    }

    private func blurImage(with snapshotImage: UIImage, style: BlurEffectStyle) -> UIImage? {
        switch style {
        case .light:
            return snapshotImage.applyLightEffect()
        case .darkEffect:
            return snapshotImage.applyDarkEffect()
        case .extraLight:
            return snapshotImage.applyExtraLightEffect()
        }
    }

    public func blurDismissViewController(animated: Bool, completion: ((Bool) -> Void)?) {
        dismiss(animated: animated, completion: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion?(true)
        }
    }
}
