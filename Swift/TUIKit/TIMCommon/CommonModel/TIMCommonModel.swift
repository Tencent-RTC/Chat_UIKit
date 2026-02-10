import ImSDK_Plus
import SDWebImage
import TUICore
import UIKit

// MARK: - TUIPopView

public protocol TUIPopViewDelegate: AnyObject {
    func popView(_ popView: TUIPopView, didSelectRowAt index: Int)
}

public class TUIPopView: UIView, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    public var tableView: UITableView = .init()
    public var arrowPoint: CGPoint = .zero
    public weak var delegate: TUIPopViewDelegate?
    private var data: [TUIPopCellData] = []

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setData(_ data: [TUIPopCellData]) {
        self.data = data
        tableView.reloadData()
    }

    public func showInWindow(_ window: UIWindow) {
        window.addSubview(self)
        alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.alpha = 1
        }, completion: nil)
    }

    private func setupViews() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onTap(_:)))
        addGestureRecognizer(pan)

        backgroundColor = .clear
        let arrowSize = TUISwift.tuiPopView_Arrow_Size()
        tableView = UITableView(frame: CGRect(x: frame.origin.x, y: frame.origin.y + arrowSize.height, width: frame.size.width, height: frame.size.height - arrowSize.height))
        frame = UIScreen.main.bounds
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = TUISwift.tuiDemoDynamicColor("pop_bg_color", defaultColor: "#FFFFFF")
        tableView.tableFooterView = UIView()
        tableView.isScrollEnabled = false
        tableView.layer.cornerRadius = 5.0
        addSubview(tableView)
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return TUIPopCell.getHeight()
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TUIPopCell") as? TUIPopCell ?? TUIPopCell(style: .default, reuseIdentifier: "TUIPopCell")
        cell.setData(data[indexPath.row])
        if indexPath.row == data.count - 1 {
            cell.separatorInset = UIEdgeInsets(top: 0, left: bounds.size.width, bottom: 0, right: 0)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        delegate?.popView(self, didSelectRowAt: indexPath.row)
        hide()
    }

    override public func draw(_ rect: CGRect) {
        UIColor.white.set()
        let arrowSize = TUISwift.tuiPopView_Arrow_Size()
        let arrowPath = UIBezierPath()
        arrowPath.move(to: arrowPoint)
        arrowPath.addLine(to: CGPoint(x: arrowPoint.x + arrowSize.width * 0.5, y: arrowPoint.y + arrowSize.height))
        arrowPath.addLine(to: CGPoint(x: arrowPoint.x - arrowSize.width * 0.5, y: arrowPoint.y + arrowSize.height))
        arrowPath.close()
        arrowPath.fill()
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if let touchView = touch.view, NSStringFromClass(type(of: touchView)) == "UITableViewCellContentView" {
            return false
        }
        return true
    }

    @objc private func onTap(_ recognizer: UIGestureRecognizer) {
        hide()
    }

    private func hide() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}

public class TUIPopCellData: NSObject {
    public var image: UIImage?
    public var title: String?

    override public init() {
        super.init()
    }
}

public class TUIPopCell: UITableViewCell {
    static let reuseId = "TUIPopCell"
    var image: UIImageView = .init()
    var title: UILabel = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        image.contentMode = .scaleAspectFit
        addSubview(image)
        title.font = UIFont.systemFont(ofSize: 15)
        title.textColor = TUISwift.tuiDemoDynamicColor("pop_text_color", defaultColor: "#444444")
        title.numberOfLines = 0
        addSubview(title)
        separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0) // Example padding
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let headHeight = TUIPopCell_Height - 2 * TUIPopCell_Padding
        image.frame = CGRect(x: CGFloat(TUIPopCell_Padding), y: CGFloat(TUIPopCell_Padding), width: CGFloat(headHeight), height: CGFloat(headHeight))
        image.center = CGPoint(x: image.center.x, y: contentView.center.y)

        let widthMargin = 2 * CGFloat(TUIPopCell_Padding) + CGFloat(TUIPopCell_Margin) + CGFloat(image.frame.size.width)
        let titleWidth = frame.size.width - widthMargin
        title.frame = CGRect(x: image.frame.origin.x + image.frame.size.width + CGFloat(TUIPopCell_Margin), y: CGFloat(TUIPopCell_Padding), width: titleWidth, height: contentView.bounds.size.height)
        title.center = CGPoint(x: title.center.x, y: contentView.center.y)

        if TUISwift.isRTL() {
            image.resetFrameToFitRTL()
            title.resetFrameToFitRTL()
        }
    }

    func setData(_ data: TUIPopCellData) {
        image.image = data.image
        title.text = data.title
    }

    public static func getHeight() -> CGFloat {
        return CGFloat(TUIPopCell_Height)
    }
}

// MARK: TUIModifyView

public protocol TUIModifyViewDelegate: AnyObject {
    func modifyView(_ modifyView: TUIModifyView, didModiyContent content: String)
}

public class TUIModifyViewData: NSObject {
    public var title: String?
    public var content: String?
    public var desc: String?
    public var enableNull: Bool = false

    override public init() {
        super.init()
    }
}

public class TUIModifyView: UIView, UITextFieldDelegate, UIGestureRecognizerDelegate {
    let kContainerWidth = TUISwift.screen_Width()

    public var container: UIView = .init()
    public var title: UILabel = .init()
    public var content: UITextField = .init()
    public var descLabel: UILabel = .init()
    public var confirm: UIButton = .init()
    public var hLine: UIView = .init()
    public weak var delegate: TUIModifyViewDelegate?
    private var keyboardShowing: Bool = false
    private var data: TUIModifyViewData = .init()
    private var closeBtn: UIButton = .init()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide(_:)), name: UIResponder.keyboardDidHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)

        frame = UIScreen.main.bounds
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        tap.delegate = self
        addGestureRecognizer(tap)

        backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let kContainerHeight = kContainerWidth * 3 / 4
        container = UIView(frame: CGRect(x: 0, y: TUISwift.screen_Height(), width: kContainerWidth, height: kContainerHeight))
        container.backgroundColor = TUISwift.tuiContactDynamicColor("group_modify_container_view_bg_color", defaultColor: "#FFFFFF")
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
        addSubview(container)

        let buttonHeight: CGFloat = 46
        let titleHeight: CGFloat = 63

        title = UILabel(frame: CGRect(x: 0, y: 0, width: container.frame.size.width, height: titleHeight))
        title.font = UIFont(name: "PingFangSC-Medium", size: 17)
        title.textColor = TUISwift.tuiContactDynamicColor("group_modify_title_color", defaultColor: "#000000")
        title.textAlignment = .center
        container.addSubview(title)

        hLine = UIView(frame: CGRect(x: 0, y: title.frame.maxY, width: kContainerWidth, height: TUISwift.tLine_Height()))
        hLine.backgroundColor = TUISwift.timCommonDynamicColor("separator_color", defaultColor: "#E4E5E9")
        container.addSubview(hLine)

        let contentMargin: CGFloat = 20
        let contentWidth = container.frame.size.width - 2 * contentMargin
        let contentY = hLine.frame.maxY + 17
        let contentHeight: CGFloat = 40
        content = UITextField(frame: CGRect(x: contentMargin, y: contentY, width: contentWidth, height: contentHeight))
        content.textAlignment = TUISwift.isRTL() ? .right : .left
        content.delegate = self
        content.backgroundColor = TUISwift.tuiContactDynamicColor("group_modify_input_bg_color", defaultColor: "#F5F5F5")
        content.textColor = TUISwift.tuiContactDynamicColor("group_modify_input_text_color", defaultColor: "#000000")
        content.font = UIFont.systemFont(ofSize: 16)
        content.layer.masksToBounds = true
        content.layer.cornerRadius = 4.0
        content.returnKeyType = .done
        content.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        let leftViewFrame = CGRect(x: content.frame.origin.x, y: content.frame.origin.y, width: 16, height: content.frame.height)
        let leftView = UIView(frame: leftViewFrame)
        content.leftView = leftView
        content.leftViewMode = .always

        let rightViewFrame = CGRect(x: content.frame.width - 16, y: content.frame.origin.y, width: 16, height: content.frame.height)
        let rightView = UIView(frame: rightViewFrame)
        content.rightView = rightView
        content.rightViewMode = .always

        container.addSubview(content)

        descLabel = UILabel(frame: CGRect(x: content.frame.origin.x, y: content.frame.maxY + 17, width: contentWidth, height: 20))
        descLabel.textColor = TUISwift.tuiContactDynamicColor("group_modify_desc_color", defaultColor: "#888888")
        descLabel.font = UIFont.systemFont(ofSize: 13.0)
        descLabel.numberOfLines = 0
        descLabel.text = "desc"
        container.addSubview(descLabel)

        confirm = UIButton(frame: CGRect(x: content.frame.origin.x, y: descLabel.frame.maxY + 30, width: contentWidth, height: buttonHeight))
        confirm.setTitle(TUISwift.timCommonLocalizableString("Confirm"), for: .normal)
        confirm.setTitleColor(.white, for: .normal)
        confirm.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        confirm.layer.cornerRadius = 8
        confirm.layer.masksToBounds = true
        confirm.imageView?.contentMode = .scaleToFill
        enableConfirmButton(data.enableNull)
        confirm.addTarget(self, action: #selector(didConfirm(_:)), for: .touchUpInside)
        container.addSubview(confirm)

        closeBtn = UIButton(frame: CGRect(x: container.frame.size.width - 24 - 20, y: 0, width: 24, height: 24))
        closeBtn.center.y = title.center.y
        closeBtn.setImage(UIImage.safeImage(TUISwift.tuiContactImagePath("ic_close_poppings")), for: .normal)
        closeBtn.addTarget(self, action: #selector(didCancel(_:)), for: .touchUpInside)
        container.addSubview(closeBtn)
    }

    public func setData(_ data: TUIModifyViewData) {
        title.text = data.title
        content.text = data.content
        descLabel.text = data.desc
        self.data = data

        let rect = data.desc?.boundingRect(with: CGSize(width: content.bounds.size.width, height: CGFloat(Int.max)),
                                           options: [.usesLineFragmentOrigin, .usesFontLeading],
                                           attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 13.0)],
                                           context: nil)
        var frame = descLabel.frame
        frame.size.height = rect?.size.height ?? 0
        descLabel.frame = frame

        textChanged()
    }

    public func showInWindow(_ window: UIWindow) {
        window.addSubview(self)
        layoutIfNeeded()
        let height = confirm.frame.maxY + 50

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.container.frame = CGRect(x: 0, y: TUISwift.screen_Height() - height, width: self.kContainerWidth, height: height)
        }, completion: nil)
    }

    @objc func onTap(_ recognizer: UIGestureRecognizer) {
        content.resignFirstResponder()

        if !keyboardShowing {
            hide()
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == self
    }

    public func hide() {
        alpha = 1
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: {
            self.alpha = 0
        }, completion: { _ in
            NotificationCenter.default.removeObserver(self)
            if self.superview != nil {
                self.removeFromSuperview()
            }
        })
    }

    @objc func didCancel(_ sender: UIButton) {
        hide()
    }

    @objc func didConfirm(_ sender: UIButton) {
        if let text = content.text {
            delegate?.modifyView(self, didModiyContent: text)
        }
        hide()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        return true
    }

    @objc func textChanged() {
        enableConfirmButton((content.text?.count ?? 0) > 0 || data.enableNull)
    }

    @objc func keyboardWillChangeFrame(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            keyboardShowing = keyboardFrame.height > 0
            animateContainer(keyboardFrame.height)
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        animateContainer(0)
    }

    @objc func keyboardDidHide(_ notification: Notification) {
        keyboardShowing = false
    }

    func animateContainer(_ keyboardHeight: CGFloat) {
        let height = confirm.frame.maxY + 50
        var frame = container.frame
        frame.origin.y = TUISwift.screen_Height() - height - keyboardHeight
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.container.frame = frame
        }, completion: nil)
    }

    func enableConfirmButton(_ enable: Bool) {
        if enable {
            confirm.backgroundColor = TUISwift.tuiContactDynamicColor("group_modify_confirm_enable_bg_color", defaultColor: "147AFF")
            confirm.isEnabled = true
        } else {
            confirm.backgroundColor = TUISwift.tuiContactDynamicColor("group_modify_confirm_enable_bg_color", defaultColor: "147AFF").withAlphaComponent(0.3)
            confirm.isEnabled = false
        }
    }
}

// MARK: - TUINaviBarIndicatorView

public class TUINaviBarIndicatorView: UIView {
    var indicator: UIActivityIndicatorView = .init()
    public var label: UILabel = .init()
    public var maxLabelLength: CGFloat = 150

    override init(frame: CGRect) {
        indicator.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        indicator.center = CGPoint(x: 0, y: CGFloat(TUISwift.navBar_Height()) * 0.5)
        indicator.style = UIActivityIndicatorView.Style.medium
        addSubview(indicator)

        label.backgroundColor = .clear
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        addSubview(label)
    }

    public func setTitle(_ title: String) {
        label.textColor = TUISwift.timCommonDynamicColor("nav_title_text_color", defaultColor: "#000000")
        label.text = title
        updateLayout()
    }

    private func updateLayout() {
        label.sizeToFit()
        let labelSize = label.bounds.size
        let labelWidth = min(labelSize.width, maxLabelLength)
        let labelY: CGFloat = 0
        let labelX: CGFloat = indicator.isHidden ? 0 : (indicator.frame.origin.x + indicator.frame.size.width + CGFloat(TUINaviBarIndicatorView_Margin))
        label.frame = CGRect(x: labelX, y: labelY, width: labelWidth, height: CGFloat(TUISwift.navBar_Height()))
        frame = CGRect(x: 0, y: 0, width: labelX + labelWidth + CGFloat(TUINaviBarIndicatorView_Margin), height: CGFloat(TUISwift.navBar_Height()))
    }

    public func startAnimating() {
        indicator.startAnimating()
    }

    public func stopAnimating() {
        indicator.stopAnimating()
    }
}

// MARK: -  TUICommonCell & data

open class TUICommonCellData: NSObject {
    public var reuseId: String = "default_reuseId"
    public var cselector: Selector?
    public var ext: [String: Any]?

    open func height(ofWidth width: CGFloat) -> CGFloat {
        return 60
    }

    open func estimatedHeight() -> CGFloat {
        return 60
    }
}

open class TUICommonTableViewCell: UITableViewCell {
    public var data: TUICommonCellData?
    public var colorWhenTouched: UIColor?
    public var changeColorWhenTouched: Bool = false
    public var tapRecognizer: UITapGestureRecognizer?

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapGesture(_:)))
        tapRecognizer?.delegate = self
        tapRecognizer?.cancelsTouchesInView = false

        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        contentView.backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
    }

    @objc private func tapGesture(_ gesture: UIGestureRecognizer) {
        guard let selector = data?.cselector,
              let vc = mm_viewController, vc.responds(to: selector) else { return }
        isSelected = true
        vc.perform(selector, with: self)
    }

    open func fill(with data: TUICommonCellData) {
        self.data = data
        guard let tapRecognizer = tapRecognizer else { return }
        if data.cselector != nil {
            addGestureRecognizer(tapRecognizer)
        } else {
            removeGestureRecognizer(tapRecognizer)
        }
    }
}

// MARK: - TUICommonTextCell & data

open class TUICommonTextCellData: TUICommonCellData {
    @objc public dynamic var key: String?
    @objc public dynamic var value: String?
    public var showAccessory: Bool = false
    public var keyColor: UIColor?
    public var valueColor: UIColor?
    public var enableMultiLineValue: Bool = false
    public var keyEdgeInsets: UIEdgeInsets = .init(top: 0, left: 20, bottom: 0, right: 0)

    override open func height(ofWidth width: CGFloat) -> CGFloat {
        var height = super.height(ofWidth: width)
        if enableMultiLineValue {
            let str = value
            let attribute = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 16)]
            let size = str?.boundingRect(with: CGSize(width: 280, height: 999),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading],
                                         attributes: attribute,
                                         context: nil).size
            height = (size?.height ?? 0) + 30
        }
        return height
    }
}

open class TUICommonTextCell: TUICommonTableViewCell {
    public var keyLabel: UILabel = .init()
    public var valueLabel: UILabel = .init()
    public private(set) var textData: TUICommonTextCellData?
    private var keyObservation: NSKeyValueObservation?
    private var valueObservation: NSKeyValueObservation?

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        contentView.backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")

        keyLabel.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#444444")
        keyLabel.font = UIFont.systemFont(ofSize: 16.0)
        contentView.addSubview(keyLabel)
        keyLabel.rtlAlignment = .trailing

        valueLabel.textColor = TUISwift.timCommonDynamicColor("form_value_text_color", defaultColor: "#000000")
        valueLabel.font = UIFont.systemFont(ofSize: 16.0)
        contentView.addSubview(valueLabel)
        valueLabel.rtlAlignment = .trailing

        selectionStyle = .none
    }

    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let textData = data as? TUICommonTextCellData else { return }
        self.textData = textData

        setupObservers()

        accessoryType = textData.showAccessory ? .disclosureIndicator : .none

        keyLabel.textColor = textData.keyColor
        valueLabel.textColor = textData.valueColor

        valueLabel.numberOfLines = textData.enableMultiLineValue ? 0 : 1

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    private func setupObservers() {
        keyObservation = textData?.observe(\.key, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let text = change.newValue else { return }
            self.keyLabel.text = text
        }

        valueObservation = textData?.observe(\.value, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let text = change.newValue else { return }
            self.valueLabel.text = text
        }
    }

    override public func prepareForReuse() {
        super.prepareForReuse()
        keyObservation?.invalidate()
        keyObservation = nil

        valueObservation?.invalidate()
        valueObservation = nil
    }

    override open class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override open func updateConstraints() {
        super.updateConstraints()

        keyLabel.sizeToFit()
        keyLabel.snp.remakeConstraints { make in
            make.size.equalTo(keyLabel.frame.size)
            make.leading.equalTo(contentView).offset(textData?.keyEdgeInsets.left ?? 20)
            make.centerY.equalTo(contentView)
        }

        valueLabel.sizeToFit()
        valueLabel.snp.remakeConstraints { make in
            make.leading.equalTo(keyLabel.snp.trailing).offset(10)
            if textData?.showAccessory == true {
                make.trailing.equalTo(contentView.snp.trailing).offset(-10)
            } else {
                make.trailing.equalTo(contentView.snp.trailing).offset(-20)
            }
            make.centerY.equalTo(contentView)
        }
    }
}

// MARK: - TUICommonSwitchCell & data

open class TUICommonSwitchCellData: TUICommonCellData {
    public var title: String?
    public var desc: String?
    public var isOn: Bool = false
    public var margin: CGFloat = 20.0
    public var cswitchSelector: Selector?
    public var displaySeparatorLine: Bool = false
    public var disableChecked: Bool = false

    override open func height(ofWidth width: CGFloat) -> CGFloat {
        var height = super.height(ofWidth: width)
        if let desc = desc, !desc.isEmpty {
            let attribute = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]
            let size = desc.boundingRect(with: CGSize(width: 264, height: 999),
                                         options: [.usesLineFragmentOrigin, .usesFontLeading],
                                         attributes: attribute,
                                         context: nil).size
            height += size.height + 10
        }
        return height
    }
}

open class TUICommonSwitchCell: TUICommonTableViewCell {
    var titleLabel: UILabel = .init()
    var descLabel: UILabel = .init()
    public var switcher: UISwitch = .init()
    public var switchData: TUICommonSwitchCellData?
    private var leftSeparatorLine: UIView = .init()

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        titleLabel.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#444444")
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titleLabel.rtlAlignment = .leading
        contentView.addSubview(titleLabel)

        descLabel.textColor = TUISwift.timCommonDynamicColor("group_modify_desc_color", defaultColor: "#888888")
        descLabel.font = UIFont.systemFont(ofSize: 12)
        descLabel.numberOfLines = 0
        descLabel.rtlAlignment = .leading
        descLabel.isHidden = true
        contentView.addSubview(descLabel)

        switcher.onTintColor = TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
        accessoryView = switcher
        contentView.addSubview(switcher)
        switcher.addTarget(self, action: #selector(switchClick), for: .valueChanged)

        leftSeparatorLine.backgroundColor = UIColor.gray.withAlphaComponent(0.3)
        contentView.addSubview(leftSeparatorLine)

        selectionStyle = .none
    }

    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let switchData = data as? TUICommonSwitchCellData else { return }

        self.switchData = switchData
        titleLabel.text = switchData.title
        switcher.isOn = switchData.isOn
        descLabel.text = switchData.desc

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    override open class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override open func updateConstraints() {
        super.updateConstraints()

        if switchData?.disableChecked == true {
            titleLabel.textColor = UIColor.gray
            titleLabel.alpha = 0.4
            switcher.alpha = 0.4
            isUserInteractionEnabled = false
        } else {
            titleLabel.alpha = 1
            switcher.alpha = 1
            titleLabel.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#444444")
            switcher.onTintColor = TUISwift.timCommonDynamicColor("common_switch_on_color", defaultColor: "#147AFF")
            isUserInteractionEnabled = true
        }

        var leftMargin: CGFloat = 0
        let padding: CGFloat = 5
        if switchData?.displaySeparatorLine == true {
            leftSeparatorLine.frame = CGRect(x: switchData!.margin, y: contentView.frame.height / 2 - 1, width: 10, height: 2)
            leftMargin = switchData!.margin + leftSeparatorLine.frame.width + padding
        } else {
            leftSeparatorLine.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
            leftMargin = switchData!.margin
        }

        if let desc = switchData?.desc, !desc.isEmpty {
            descLabel.text = desc
            descLabel.isHidden = false
            let str = desc
            let attribute = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]
            let size = str.boundingRect(with: CGSize(width: 264, height: 999),
                                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                                        attributes: attribute,
                                        context: nil).size

            titleLabel.snp.remakeConstraints { make in
                make.width.equalTo(size.width)
                make.height.equalTo(24)
                make.leading.equalTo(leftMargin)
                make.top.equalTo(12)
            }
            descLabel.snp.remakeConstraints { make in
                make.width.equalTo(size.width)
                make.height.equalTo(size.height)
                make.leading.equalTo(titleLabel.snp.leading)
                make.top.equalTo(titleLabel.snp.bottom).offset(2)
            }
        } else {
            descLabel.text = ""
            titleLabel.sizeToFit()
            titleLabel.snp.remakeConstraints { make in
                make.size.equalTo(titleLabel.frame.size)
                make.leading.equalTo(switchData!.margin)
                make.centerY.equalTo(contentView)
            }
        }
    }

    @objc private func switchClick() {
        if let selector = switchData?.cswitchSelector,
           let vc = mm_viewController, vc.responds(to: selector)
        {
            vc.perform(selector, with: self)
        }
    }
}

// MARK: - TUIGroupPendencyCell & data

public let TUIGroupPendencyCellData_onPendencyChanged = "TUIGroupPendencyCellData_onPendencyChanged"
public class TUIGroupPendencyCellData: TUICommonCellData {
    public var groupId: String?
    public var fromUser: String?
    public var toUser: String?
    public var pendencyItem: V2TIMGroupApplication
    public var avatarUrl: URL?
    public var title: String?
    public var requestMsg: String?
    @objc public dynamic var isAccepted: Bool = false
    @objc public dynamic var isRejected: Bool = false
    public var cbuttonSelector: Selector?

    public init(pendency: V2TIMGroupApplication) {
        self.pendencyItem = pendency
        self.groupId = pendency.groupID
        self.fromUser = pendency.fromUser
        self.toUser = pendency.toUser
        self.title = (pendency.fromUserNickName?.isEmpty ?? true) ? pendency.fromUser : pendency.fromUserNickName
        if let faceUrl = pendency.fromUserFaceUrl {
            self.avatarUrl = URL(string: faceUrl)
        }
        self.requestMsg = pendency.requestMsg

        let inviteJoin = String(format: TUISwift.timCommonLocalizableString("TUIKitInviteJoinGroupFormat"), pendency.fromUser ?? "")
        let applyJoin = String(format: TUISwift.timCommonLocalizableString("TUIKitWhoRequestForJoinGroupFormat"), title ?? "")
        if requestMsg?.isEmpty ?? true {
            self.requestMsg = pendency.applicationType == .GROUP_JOIN_APPLICATION_NEED_APPROVED_BY_ADMIN ? inviteJoin : applyJoin
        }
    }

    public func accept() {
        agree(success: nil, failure: nil)
    }

    public func reject() {
        reject(success: nil, failure: nil)
    }

    public func agree(success: (() -> Void)?, failure: ((Int, String) -> Void)?) {
        V2TIMManager.sharedInstance().acceptGroupApplication(application: pendencyItem, reason: TUISwift.timCommonLocalizableString("TUIKitAgreedByAdministor"), succ: {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("Have_been_sent"))
            NotificationCenter.default.post(name: Notification.Name(TUIGroupPendencyCellData_onPendencyChanged), object: nil)
            success?()
        }, fail: { code, msg in
            TUITool.makeToastError(Int(code), msg: msg)
            failure?(Int(code), msg ?? "")
        })
        isAccepted = true
    }

    public func reject(success: (() -> Void)?, failure: ((Int, String) -> Void)?) {
        V2TIMManager.sharedInstance().refuseGroupApplication(application: pendencyItem, reason: TUISwift.timCommonLocalizableString("TUIkitDiscliedByAdministor"), succ: {
            TUITool.makeToast(TUISwift.timCommonLocalizableString("Have_been_sent"))
            NotificationCenter.default.post(name: Notification.Name(TUIGroupPendencyCellData_onPendencyChanged), object: nil)
            success?()
        }, fail: { code, msg in
            TUITool.makeToastError(Int(code), msg: msg)
            failure?(Int(code), msg ?? "")
        })
        isRejected = true
    }
}

public class TUIGroupPendencyCell: TUICommonTableViewCell {
    public var avatarView: UIImageView!
    public var titleLabel: UILabel!
    public var addWordingLabel: UILabel!
    public var agreeButton: UIButton!
    public var pendencyData: TUIGroupPendencyCellData?
    var isAcceptedObservation: NSKeyValueObservation?
    var isRejectedObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.avatarView = UIImageView(image: TUISwift.defaultAvatarImage())
        contentView.addSubview(avatarView)
        avatarView.frame = CGRect(x: 12, y: 0, width: 54, height: 54)
        avatarView.center.y = 38

        self.titleLabel = UILabel(frame: .zero)
        contentView.addSubview(titleLabel)
        titleLabel.textColor = .darkText
        titleLabel.frame = CGRect(x: avatarView.frame.maxX + 12, y: 14, width: 120, height: 20)

        self.addWordingLabel = UILabel(frame: .zero)
        contentView.addSubview(addWordingLabel)
        addWordingLabel.textColor = .lightGray
        addWordingLabel.font = UIFont.systemFont(ofSize: 15)
        addWordingLabel.frame = CGRect(x: titleLabel.frame.origin.x, y: titleLabel.frame.maxY + 6, width: contentView.frame.width - titleLabel.frame.origin.x - 80, height: 15)

        self.agreeButton = UIButton(type: .system)
        accessoryView = agreeButton
        agreeButton.addTarget(self, action: #selector(agreeClick), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIGroupPendencyCellData else { return }

        pendencyData = data
        titleLabel.text = data.title
        addWordingLabel.text = data.requestMsg
        avatarView.image = TUISwift.defaultAvatarImage()
        if let url = data.avatarUrl {
            avatarView.sd_setImage(with: url, placeholderImage: UIImage.safeImage(TUISwift.timCommonImagePath("default_c2c_head")))
        }

        isAcceptedObservation = pendencyData?.observe(\.isAccepted, options: [.new, .initial], changeHandler: { [weak self] _,
                change in
            guard let self = self, let value = change.newValue, value == true else { return }
            self.agreeButton.setTitle(TUISwift.timCommonLocalizableString("Agreed"), for: .normal)
            self.agreeButton.isEnabled = false
            self.agreeButton.setTitleColor(.lightGray, for: .normal)
            self.agreeButton.layer.borderColor = UIColor.clear.cgColor
        })

        isRejectedObservation = pendencyData?.observe(\.isRejected, options: [.new, .initial], changeHandler: { [weak self] _,
                change in
            guard let self = self, let value = change.newValue, value == true else { return }
            self.agreeButton.setTitle(TUISwift.timCommonLocalizableString("Disclined"), for: .normal)
            self.agreeButton.isEnabled = false
            self.agreeButton.setTitleColor(.lightGray, for: .normal)
            self.agreeButton.layer.borderColor = UIColor.clear.cgColor
        })

        if !(data.isAccepted || data.isRejected) {
            agreeButton.setTitle(TUISwift.timCommonLocalizableString("Agree"), for: .normal)
            agreeButton.isEnabled = true
            agreeButton.setTitleColor(.darkText, for: .normal)
            agreeButton.layer.borderColor = UIColor.gray.cgColor
            agreeButton.layer.borderWidth = 1
        }
        agreeButton.sizeToFit()
        agreeButton.frame.size.width += 20
    }

    @objc func agreeClick() {
        if let selector = pendencyData?.cbuttonSelector, let vc = mm_viewController {
            if vc.responds(to: selector) {
                vc.perform(selector, with: self)
            }
        }
    }

    override public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view != agreeButton
    }
}

// MARK: - TUIButtonCell & data

public enum TUIButtonStyle: Int {
    case green
    case white
    case redText
    case blue
}

public class TUIButtonCellData: TUICommonCellData {
    public var title: String = ""
    public var cbuttonSelector: Selector?
    public var style: TUIButtonStyle = .green
    public var textColor: UIColor?
    public var hideSeparatorLine: Bool = false

    override public func height(ofWidth width: CGFloat) -> CGFloat {
        return CGFloat(TButtonCell_Height)
    }
}

open class TUIButtonCell: TUICommonTableViewCell {
    public var button: UIButton = .init(type: .custom)
    public var buttonData: TUIButtonCellData?
    private var line: UIView = .init()

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        self.changeColorWhenTouched = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")
        contentView.backgroundColor = TUISwift.timCommonDynamicColor("form_bg_color", defaultColor: "#FFFFFF")

        button.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        button.addTarget(self, action: #selector(onClick(_:)), for: .touchUpInside)
        contentView.addSubview(button)

        separatorInset = UIEdgeInsets(top: 0, left: TUISwift.screen_Width(), bottom: 0, right: 0)
        selectionStyle = .none

        line.backgroundColor = TUISwift.timCommonDynamicColor("separator_color", defaultColor: "#DBDBDB")
        contentView.addSubview(line)
    }

    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIButtonCellData else { return }

        buttonData = data
        button.setTitle(data.title, for: .normal)
        switch data.style {
        case .green:
            button.setTitleColor(TUISwift.timCommonDynamicColor("form_green_button_text_color", defaultColor: "#FFFFFF"), for: .normal)
            button.backgroundColor = TUISwift.timCommonDynamicColor("form_green_button_bg_color", defaultColor: "#232323")
            button.setBackgroundImage(imageWithColor(TUISwift.timCommonDynamicColor("form_green_button_highlight_bg_color", defaultColor: "#179A1A")), for: .highlighted)
        case .white:
            button.setTitleColor(TUISwift.timCommonDynamicColor("form_white_button_text_color", defaultColor: "#000000"), for: .normal)
            button.backgroundColor = TUISwift.timCommonDynamicColor("form_white_button_bg_color", defaultColor: "#FFFFFF")
        case .redText:
            button.setTitleColor(TUISwift.timCommonDynamicColor("form_redtext_button_text_color", defaultColor: "#FF0000"), for: .normal)
            button.backgroundColor = TUISwift.timCommonDynamicColor("form_redtext_button_bg_color", defaultColor: "#FFFFFF")
        case .blue:
            button.setTitleColor(TUISwift.timCommonDynamicColor("form_blue_button_text_color", defaultColor: "#FFFFFF"), for: .normal)
            button.backgroundColor = TUISwift.timCommonDynamicColor("form_blue_button_bg_color", defaultColor: "#1E90FF")
            button.setBackgroundImage(imageWithColor(TUISwift.timCommonDynamicColor("form_blue_button_highlight_bg_color", defaultColor: "#1978D5")), for: .highlighted)
        }

        if let textColor = data.textColor {
            button.setTitleColor(textColor, for: .normal)
        }

        line.isHidden = data.hideSeparatorLine
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
        button.frame = CGRect(x: CGFloat(TButtonCell_Margin), y: 0, width: TUISwift.screen_Width() - 2 * CGFloat(TButtonCell_Margin), height: frame.height - CGFloat(TButtonCell_Margin))
        line.frame = CGRect(x: 20, y: frame.height - 0.2, width: TUISwift.screen_Width(), height: 0.2)
    }

    @objc private func onClick(_ sender: UIButton) {
        if let selector = buttonData?.cbuttonSelector, let vc = mm_viewController, vc.responds(to: selector) {
            vc.perform(selector, with: self)
        }
    }

    override public func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        if subview != contentView {
            subview.removeFromSuperview()
        }
    }

    private func imageWithColor(_ color: UIColor) -> UIImage {
        let rect = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        UIGraphicsBeginImageContext(rect.size)
        let context = UIGraphicsGetCurrentContext()

        context?.setFillColor(color.cgColor)
        context?.fill(rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image ?? UIImage()
    }
}

// MARK: - TUIFaceCell & data

public class TUIFaceCellData: NSObject {
    public var name: String?
    public var localizableName: String?
    public var path: String?
}

public class TUIFaceCell: UICollectionViewCell {
    public var face: UIImageView = .init()
    public var staticImage: UIImage?
    public var gifImage: UIImage?
    public var longPressCallback: ((UILongPressGestureRecognizer) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        defaultLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        face.contentMode = .scaleAspectFill
        addSubview(face)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress(_:)))
        addGestureRecognizer(longPress)
        isUserInteractionEnabled = true
    }

    private func defaultLayout() {
        let size = frame.size
        face.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    }

    public func setData(_ data: TUIFaceCellData) {
        if let path = data.path {
            let image: UIImage? = TUIImageCache.sharedInstance().getFaceFromCache(path)
            let imageFormat = image?.sd_imageFormat
            if imageFormat == .GIF {
                gifImage = image
                if let images = image?.images, images.count > 1 {
                    staticImage = images[0]
                }
            } else {
                staticImage = image
            }
            face.image = staticImage
        } else {
            face.image = nil
            staticImage = nil
            gifImage = nil
        }

        defaultLayout()
    }

    @objc private func onLongPress(_ longPress: UILongPressGestureRecognizer) {
        longPressCallback?(longPress)
    }
}

// MARK: - TUIFaceGroup

public class TUIFaceGroup: NSObject {
    public var groupIndex: Int = 0
    public var groupPath: String?
    public var rowCount: Int = 0
    public var itemCountPerRow: Int = 0
    public var faces: [TUIFaceCellData]?
    public var needBackDelete: Bool = false
    public var menuPath: String?
    public var recentGroup: TUIFaceGroup?
    public var isNeedAddInInputBar: Bool = false
    public var groupName: String?

    private var _facesMap: [String: String]?
    public var facesMap: [String: String] {
        if _facesMap == nil || (_facesMap?.count ?? 0) != (faces?.count ?? 0) {
            var faceDic: [String: String] = [:]
            if let faces = faces {
                for data in faces {
                    if let name = data.name {
                        faceDic[name] = data.path
                    }
                }
            }
            _facesMap = faceDic
        }
        return _facesMap ?? [:]
    }
}

public class TUIEmojiTextAttachment: NSTextAttachment {
    public var faceCellData: TUIFaceCellData?
    public var emojiTag: String?
    public var emojiSize: CGSize = .zero

    override public func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
        let kTIMDefaultEmojiSize = CGSize(width: 20, height: 20)
        return CGRect(x: 0, y: -0.4 * lineFrag.size.height, width: kTIMDefaultEmojiSize.width, height: kTIMDefaultEmojiSize.height)
    }
}

// MARK: - TUIUnReadView

public class TUIUnReadView: UIView {
    public var unReadLabel: UILabel = .init()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        defaultLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setNum(_ num: Int) {
        let unReadStr: String
        if num > 99 {
            unReadStr = "99+"
        } else {
            unReadStr = "\(num)"
        }
        unReadLabel.text = unReadStr
        isHidden = (num == 0)
        defaultLayout()
    }

    private func setupViews() {
        unReadLabel.text = "11"
        unReadLabel.font = UIFont.systemFont(ofSize: 12)
        unReadLabel.textColor = .white
        unReadLabel.textAlignment = .center
        unReadLabel.sizeToFit()
        addSubview(unReadLabel)

        layer.cornerRadius = (unReadLabel.frame.size.height + CGFloat(TUnReadView_Margin_TB * 2)) / 2.0
        layer.masksToBounds = true
        backgroundColor = .red
        isHidden = true
    }

    private func defaultLayout() {
        unReadLabel.sizeToFit()

        var width = unReadLabel.frame.size.width + 2 * CGFloat(TUnReadView_Margin_LR)
        let height = unReadLabel.frame.size.height + 2 * CGFloat(TUnReadView_Margin_TB)
        if width < height {
            width = height
        }
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
        unReadLabel.frame = bounds
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 11.0, *) {
            // Workaround for iOS 11 UINavigationBarItem init with custom view, position issue
            var view: UIView? = self
            while let currentView = view, !(currentView is UINavigationBar), let superview = currentView.superview {
                view = superview
                if currentView is UIStackView, let superview = currentView.superview {
                    let margin: CGFloat = 40.0
                    superview.addConstraint(NSLayoutConstraint(item: currentView,
                                                               attribute: .leading,
                                                               relatedBy: .equal,
                                                               toItem: superview,
                                                               attribute: .leading,
                                                               multiplier: 1.0,
                                                               constant: margin))
                    break
                }
            }
        }
    }
}

// MARK: - TUIConversationPin

let kTopConversationListChangedNotification = Notification.Name("kTopConversationListChangedNotification")
// let TOP_CONV_KEY = "TUIKIT_TOP_CONV_KEY"
public class TUIConversationPin {
    public static let sharedInstance = TUIConversationPin()

    private init() {}

    public func topConversationList() -> [String] {
        return []
//        if let list = UserDefaults.standard.array(forKey: TOP_CONV_KEY) as? [String] {
//            return list
//        }
//        return []
    }

    public func addTopConversation(_ conv: String, callback: ((Bool, String?) -> Void)?) {
        V2TIMManager.sharedInstance().pinConversation(conversationID: conv, isPinned: true, succ: {
            callback?(true, nil)
        }, fail: { _, desc in
            callback?(false, desc)
        })
//        DispatchQueue.main.async {
//            var list = self.topConversationList()
//            if let index = list.firstIndex(of: conv) {
//                list.remove(at: index)
//            }
//            list.insert(conv, at: 0)
//            UserDefaults.standard.setValue(list, forKey: TOP_CONV_KEY)
//            NotificationCenter.default.post(name: kTopConversationListChangedNotification, object: nil)
//            callback?(true, nil)
//        }
    }

    public func removeTopConversation(_ conv: String, callback: ((Bool, String?) -> Void)?) {
        V2TIMManager.sharedInstance().pinConversation(conversationID: conv, isPinned: false, succ: {
            callback?(true, nil)
        }, fail: { _, desc in
            callback?(false, desc)
        })
//        DispatchQueue.main.async {
//            var list = self.topConversationList()
//            if let index = list.firstIndex(of: conv) {
//                list.remove(at: index)
//                UserDefaults.standard.setValue(list, forKey: TOP_CONV_KEY)
//                NotificationCenter.default.post(name: kTopConversationListChangedNotification, object: nil)
//            }
//            callback?(true, nil)
//        }
    }
}

// MARK: - TUICommonContactSelectCellData

open class TUICommonContactSelectCellData: TUICommonCellData {
    public var identifier: String = ""
    public var title: String = ""
    public var avatarUrl: URL?
    public var avatarImage: UIImage?
    public var isSelected: Bool = false
    public var isEnabled: Bool = true

    override public init() {
        super.init()
        self.isEnabled = true
    }

    public func compare(_ data: TUICommonContactSelectCellData) -> ComparisonResult {
        return title.localizedCompare(data.title)
    }
}

// MARK: - TUICommonContactListPickerCell

public class TUICommonContactListPickerCell: UICollectionViewCell {
    var avatar: UIImageView = .init()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupAvatar()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupAvatar() {
        let avatarWidth: CGFloat = 35.0
        avatar.frame = CGRect(x: 0, y: 0, width: avatarWidth, height: avatarWidth)
        contentView.addSubview(avatar)
        avatar.center = CGPoint(x: avatarWidth / 2.0, y: avatarWidth / 2.0)
        avatar.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        if TUIConfig.default().avatarType == .TAvatarTypeRounded {
            avatar.layer.masksToBounds = true
            avatar.layer.cornerRadius = avatar.frame.size.height / 2
        } else if TUIConfig.default().avatarType == .TAvatarTypeRadiusCorner {
            avatar.layer.masksToBounds = true
            avatar.layer.cornerRadius = TUIConfig.default().avatarCornerRadius
        }
    }
}

// MARK: - TUIContactListPicker

public typealias TUIContactListPickerOnCancel = (TUICommonContactSelectCellData) -> Void

public class TUIContactListPicker: UIControl, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    public var accessoryBtn: UIButton = .init(type: .custom)
    public var selectArray: [TUICommonContactSelectCellData] = [] {
        didSet {
            collectionView.reloadData()
            accessoryBtn.isEnabled = !selectArray.isEmpty
        }
    }

    public var onCancel: TUIContactListPickerOnCancel?

    private var collectionView: UICollectionView!

    override public init(frame: CGRect) {
        super.init(frame: frame)
        initControl()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func initControl() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.decelerationRate = .normal

        collectionView.register(TUICommonContactListPickerCell.self, forCellWithReuseIdentifier: "PickerIdentifier")
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self

        addSubview(collectionView)

        accessoryBtn.setBackgroundImage(TUISwift.timCommonBundleImage("icon_cell_blue_normal"), for: .normal)
        accessoryBtn.setBackgroundImage(TUISwift.timCommonBundleImage("icon_cell_blue_normal"), for: .highlighted)
        accessoryBtn.setTitle(" \(TUISwift.timCommonLocalizableString("Confirm")) ", for: .normal)
        accessoryBtn.isEnabled = false
        addSubview(accessoryBtn)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        accessoryBtn.mm__sizeToFit().mm_height(30).mm_right(15).mm_top(13)
        collectionView.mm_left(15).mm_height(40).mm_width(accessoryBtn.mm_x - 30).mm__centerY(accessoryBtn.mm_centerY)

        if TUISwift.isRTL() {
            accessoryBtn.resetFrameToFitRTL()
            collectionView.resetFrameToFitRTL()
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 35, height: collectionView.bounds.size.height)
    }

    // MARK: - UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return selectArray.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PickerIdentifier", for: indexPath) as! TUICommonContactListPickerCell

        let data = selectArray[indexPath.row]
        if let avatarUrl = data.avatarUrl {
            cell.avatar.sd_setImage(with: avatarUrl, placeholderImage: TUISwift.defaultAvatarImage())
        } else if let avatarImage = data.avatarImage {
            cell.avatar.image = avatarImage
        } else {
            cell.avatar.image = TUISwift.defaultAvatarImage()
        }
        return cell
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        if indexPath.item < selectArray.count {
            let data = selectArray[indexPath.item]
            onCancel?(data)
        }
    }
}

// MARK: - TUIProfileCardCell & data

public protocol TUIProfileCardDelegate: AnyObject {
    func didTapOnAvatar(_ cell: TUIProfileCardCell)
}

public extension TUIProfileCardDelegate {
    func didTapOnAvatar(_ cell: TUIProfileCardCell) {}
}

open class TUIProfileCardCellData: TUICommonCellData {
    public var avatarImage: UIImage? = TUISwift.defaultAvatarImage()
    @objc public dynamic var avatarUrl: URL?
    @objc public dynamic var name: String?
    @objc public dynamic var identifier: String?
    @objc public dynamic var signature: String?
    @objc public dynamic var genderString: String?
    public var genderIconImage: UIImage?
    public var showAccessory: Bool = false
    public var showSignature: Bool = false

    override public init() {
        super.init()
        updateGenderIcon()
    }

    private func updateGenderIcon() {
        if genderString == TUISwift.timCommonLocalizableString("Male") {
            genderIconImage = TUISwift.tuiContactCommonBundleImage("male")
        } else if genderString == TUISwift.timCommonLocalizableString("Female") {
            genderIconImage = TUISwift.tuiContactCommonBundleImage("female")
        } else {
            genderIconImage = nil
        }
    }

    override open func height(ofWidth width: CGFloat) -> CGFloat {
        let size = CGSize(width: 48, height: 48)
        return size.height + 2 * CGFloat(TPersonalCommonCell_Margin) + (showSignature ? 24 : 0)
    }
}

open class TUIProfileCardCell: TUICommonTableViewCell {
    public var avatar: UIImageView = .init()
    public var name: UILabel = .init()
    public var identifier: UILabel = .init()
    public var signature: UILabel = .init()
    public var genderIcon: UIImageView = .init()
    public var cardData: TUIProfileCardCellData?
    public weak var delegate: TUIProfileCardDelegate?
    var signatureObservation: NSKeyValueObservation?
    var identifierObservation: NSKeyValueObservation?
    var nameObservation: NSKeyValueObservation?
    var avatarUrlObservation: NSKeyValueObservation?
    var genderStringObservation: NSKeyValueObservation?

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        let headSize = CGSize(width: 48, height: 48)
        avatar.frame = CGRect(x: CGFloat(TPersonalCommonCell_Margin), y: CGFloat(TPersonalCommonCell_Margin), width: headSize.width, height: headSize.height)
        avatar.contentMode = .scaleAspectFit
        avatar.layer.cornerRadius = 4
        avatar.layer.masksToBounds = true
        let tapAvatar = UITapGestureRecognizer(target: self, action: #selector(onTapAvatar))
        avatar.addGestureRecognizer(tapAvatar)
        avatar.isUserInteractionEnabled = true

        if TUIConfig.default().avatarType == .TAvatarTypeRounded {
            avatar.layer.cornerRadius = headSize.height / 2
        } else if TUIConfig.default().avatarType == .TAvatarTypeRadiusCorner {
            avatar.layer.cornerRadius = TUIConfig.default().avatarCornerRadius
        }
        contentView.addSubview(avatar)

        genderIcon.contentMode = .scaleAspectFit
        contentView.addSubview(genderIcon)

        name.font = UIFont.boldSystemFont(ofSize: 18)
        name.textColor = TUISwift.timCommonDynamicColor("form_title_color", defaultColor: "#000000")
        contentView.addSubview(name)

        identifier.font = UIFont.systemFont(ofSize: 13)
        identifier.textColor = TUISwift.timCommonDynamicColor("form_subtitle_color", defaultColor: "#888888")
        contentView.addSubview(identifier)

        signature.font = UIFont.systemFont(ofSize: 14)
        signature.textColor = TUISwift.timCommonDynamicColor("form_subtitle_color", defaultColor: "#888888")
        contentView.addSubview(signature)

        selectionStyle = .none
    }

    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIProfileCardCellData else { return }

        cardData = data
        signature.isHidden = !data.showSignature

        signatureObservation = data.observe(\.signature, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newSignature = change.newValue else { return }
            self.signature.text = newSignature
        }

        identifierObservation = data.observe(\.identifier, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newIdentifier = change.newValue, newIdentifier != change.oldValue else { return }
            self.identifier.text = "\(TUISwift.timCommonLocalizableString("TUIKitIdentity")):\(newIdentifier ?? "")"
        }

        nameObservation = data.observe(\.name, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newName = change.newValue, newName != change.oldValue else { return }
            self.name.text = newName
            self.name.sizeToFit()
        }

        avatarUrlObservation = data.observe(\.avatarUrl, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newAvatarUrl = change.newValue else { return }
            self.avatar.sd_setImage(with: newAvatarUrl, placeholderImage: self.cardData?.avatarImage ?? UIImage())
        }

        genderStringObservation = data.observe(\.genderString, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newGenderString = change.newValue else { return }
            if newGenderString == TUISwift.timCommonLocalizableString("Male") {
                self.genderIcon.image = TUISwift.tuiContactCommonBundleImage("male")
            } else if newGenderString == TUISwift.timCommonLocalizableString("Female") {
                self.genderIcon.image = TUISwift.tuiContactCommonBundleImage("female")
            } else {
                self.genderIcon.image = nil
            }
        }

        accessoryType = data.showAccessory ? .disclosureIndicator : .none

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
    }

    override open class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        signatureObservation?.invalidate()
        signatureObservation = nil

        identifierObservation?.invalidate()
        identifierObservation = nil

        nameObservation?.invalidate()
        nameObservation = nil

        avatarUrlObservation?.invalidate()
        avatarUrlObservation = nil

        genderStringObservation?.invalidate()
        genderStringObservation = nil
    }

    override open func updateConstraints() {
        super.updateConstraints()
        let headSize = CGSize(width: TUISwift.kScale390(66), height: TUISwift.kScale390(66))

        avatar.snp.remakeConstraints { make in
            make.size.equalTo(headSize)
            make.top.equalTo(TUISwift.kScale390(10))
            make.leading.equalTo(TUISwift.kScale390(16))
        }

        if TUIConfig.default().avatarType == .TAvatarTypeRounded {
            avatar.layer.cornerRadius = headSize.height / 2
        } else if TUIConfig.default().avatarType == .TAvatarTypeRadiusCorner {
            avatar.layer.cornerRadius = TUIConfig.default().avatarCornerRadius
        }

        name.sizeToFit()
        name.snp.remakeConstraints { make in
            make.top.equalTo(CGFloat(TPersonalCommonCell_Margin))
            make.leading.equalTo(avatar.snp.trailing).offset(15)
            make.width.lessThanOrEqualTo(name.frame.size.width)
            make.height.greaterThanOrEqualTo(name.frame.size.height)
            make.trailing.lessThanOrEqualTo(genderIcon.snp.leading).offset(-1)
        }

        genderIcon.snp.remakeConstraints { make in
            make.width.height.equalTo(name.font.pointSize * 0.9)
            make.centerY.equalTo(name)
            make.leading.equalTo(name.snp.trailing).offset(1)
            make.trailing.lessThanOrEqualTo(contentView.snp.trailing).offset(-10)
        }

        identifier.sizeToFit()
        identifier.snp.remakeConstraints { make in
            make.leading.equalTo(name)
            make.top.equalTo(name.snp.bottom).offset(5)
            make.width.greaterThanOrEqualTo(max(identifier.frame.size.width, 80))
            make.height.greaterThanOrEqualTo(identifier.frame.size.height)
            make.trailing.lessThanOrEqualTo(contentView.snp.trailing).offset(-1)
        }

        if cardData?.showSignature == true {
            signature.sizeToFit()
            signature.snp.remakeConstraints { make in
                make.leading.equalTo(name)
                make.top.equalTo(identifier.snp.bottom).offset(5)
                make.width.greaterThanOrEqualTo(max(signature.frame.size.width, 80))
                make.height.greaterThanOrEqualTo(signature.frame.size.height)
                make.trailing.lessThanOrEqualTo(contentView.snp.trailing).offset(-1)
            }
        } else {
            signature.frame = .zero
        }
    }

    @objc private func onTapAvatar() {
        delegate?.didTapOnAvatar(self)
    }
}

// MARK: - TUIAvatarViewController

public class TUIAvatarViewController: UIViewController, UIScrollViewDelegate {
    public var avatarData: TUIProfileCardCellData!
    var avatarView: UIImageView!
    var avatarScrollView: TUIScrollView!
    var saveBackgroundImage: UIImage?
    var saveShadowImage: UIImage?
    var avatarUrlObservation: NSKeyValueObservation?

    override public func viewDidLoad() {
        super.viewDidLoad()

        saveBackgroundImage = navigationController?.navigationBar.backgroundImage(for: .default)
        saveShadowImage = navigationController?.navigationBar.shadowImage
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()

        let rect = view.bounds
        avatarScrollView = TUIScrollView(frame: .zero)
        view.addSubview(avatarScrollView)
        avatarScrollView.backgroundColor = .black
        avatarScrollView.frame = rect

        avatarView = UIImageView(image: avatarData.avatarImage)
        avatarScrollView.imageView = avatarView
        avatarScrollView.maximumZoomScale = 4.0
        avatarScrollView.delegate = self

        avatarView.image = avatarData.avatarImage

        avatarUrlObservation = avatarData.observe(\.avatarUrl, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let url = change.newValue as? URL else { return }
            self.avatarView.sd_setImage(with: url, placeholderImage: self.avatarData.avatarImage)
            self.avatarScrollView.setNeedsLayout()
        }
    }

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return avatarView
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isStatusBarHidden = true

        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.backgroundColor = .clear
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UIApplication.shared.isStatusBarHidden = false
    }

    override public func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            navigationController?.navigationBar.setBackgroundImage(saveBackgroundImage, for: .default)
            navigationController?.navigationBar.shadowImage = saveShadowImage
        }
    }
}

// MARK: - TUISelectAvatar

enum AvatarURLs {
    static func userAvatarURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/avatar/avatar_\(index).png"
    }

    static let userAvatarCount = 26

    static func groupAvatarURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/group-avatar/group_avatar_\(index).png"
    }

    static let groupAvatarCount = 24

    static func communityCoverURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/community-cover/community_cover_\(index).png"
    }

    static let communityCoverCount = 12

    static func backgroundCoverURL(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/conversation-backgroundImage/backgroundImage_\(index).png"
    }

    static func backgroundCoverURLFull(_ index: Int) -> String {
        return "https://im.sdk.qcloud.com/download/tuikit-resource/conversation-backgroundImage/backgroundImage_\(index)_full.png"
    }

    static let backgroundCoverCount = 7
}

public enum TUISelectAvatarType: Int {
    case userAvatar
    case groupAvatar
    case cover
    case conversationBackgroundCover
}

public class TUISelectAvatarCardItem: NSObject {
    public var posterUrlStr: String?
    public var isSelect: Bool = false
    public var fullUrlStr: String?
    public var isDefaultBackgroundItem: Bool = false
    public var isGroupGridAvatar: Bool = false
    public var createGroupType: String?
    public var cacheGroupGridAvatarImage: UIImage?

    override public init() {
        super.init()
    }
}

class TUISelectAvatarCollectionCell: UICollectionViewCell {
    var imageView: UIImageView!
    var selectedView: UIImageView!
    var customMaskView: UIView!
    var descLabel: UILabel!
    var cardItem: TUISelectAvatarCardItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        imageView = UIImageView(frame: bounds)
        imageView.isUserInteractionEnabled = true
        imageView.layer.cornerRadius = TUIConfig.default().avatarCornerRadius
        imageView.layer.borderWidth = 2
        imageView.layer.masksToBounds = true
        contentView.addSubview(imageView)

        selectedView = UIImageView()
        selectedView.image = UIImage.safeImage(TUISwift.timCommonImagePath("icon_avatar_selected"))
        imageView.addSubview(selectedView)

        setupMaskView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateCellView()
        selectedView.frame = CGRect(x: imageView.frame.width - 20, y: 4, width: 16, height: 16)
    }

    private func updateCellView() {
        updateSelectedUI()
        updateImageView()
        updateMaskView()
    }

    func updateSelectedUI() {
        guard let cardItem = cardItem else { return }
        if cardItem.isSelect {
            imageView.layer.borderColor = TUISwift.timCommonDynamicColor("", defaultColor: "#006EFF").cgColor
            selectedView.isHidden = false
        } else {
            imageView.layer.borderColor = cardItem.isDefaultBackgroundItem ? UIColor.gray.withAlphaComponent(0.1).cgColor : UIColor.clear.cgColor
            selectedView.isHidden = true
        }
    }

    private func updateImageView() {
        guard let cardItem = cardItem else { return }
        if cardItem.isGroupGridAvatar {
            updateNormalGroupGridAvatar()
        } else {
            imageView.sd_setImage(with: URL(string: cardItem.posterUrlStr ?? ""), placeholderImage: TUISwift.timCommonBundleThemeImage("default_c2c_head_img", defaultImage: "default_c2c_head_img"))
        }
    }

    private func updateMaskView() {
        guard let cardItem = cardItem else { return }
        customMaskView.isHidden = !cardItem.isDefaultBackgroundItem
        if cardItem.isDefaultBackgroundItem {
            customMaskView.frame = CGRect(x: 0, y: imageView.frame.height - 28, width: imageView.frame.width, height: 28)
            descLabel.sizeToFit()
            descLabel.center = customMaskView.center
        }
    }

    private func updateNormalGroupGridAvatar() {
        guard let cardItem = cardItem else { return }
        if TUIConfig.default().enableGroupGridAvatar, let cacheImage = cardItem.cacheGroupGridAvatarImage {
            imageView.sd_setImage(with: nil, placeholderImage: cacheImage)
        }
    }

    private func setupMaskView() {
        customMaskView = UIView()
        customMaskView.backgroundColor = UIColor.tui_color(withHex: "cccccc")
        imageView.addSubview(customMaskView)

        descLabel = UILabel()
        descLabel.text = TUISwift.timCommonLocalizableString("TUIKitDefaultBackground")
        descLabel.textColor = .white
        descLabel.font = UIFont.systemFont(ofSize: 13)
        customMaskView.addSubview(descLabel)
        descLabel.sizeToFit()
        descLabel.center = customMaskView.center
    }
}

public class TUISelectAvatarController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    public var selectCallBack: ((String) -> Void)?
    public var selectAvatarType: TUISelectAvatarType = .userAvatar
    public var profilFaceURL: String?
    public var cacheGroupGridAvatarImage: UIImage?
    public var createGroupType: String?

    private var titleView: TUINaviBarIndicatorView!
    private var collectionView: UICollectionView!
    private var dataArr: [TUISelectAvatarCardItem] = .init()
    private var currentSelectCardItem: TUISelectAvatarCardItem? {
        didSet {
            if currentSelectCardItem != nil {
                rightButton.setTitleColor(TUISwift.timCommonDynamicColor("", defaultColor: "#006EFF"), for: .normal)
            } else {
                rightButton.setTitleColor(UIColor.gray, for: .normal)
            }
        }
    }

    private var rightButton: UIButton!

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupCollectionView()
        setupNavigator()
        loadData()
    }

    private func setupCollectionView() {
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = TUISwift.timCommonDynamicColor("controller_bg_color", defaultColor: "#F2F3F5")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(TUISelectAvatarCollectionCell.self, forCellWithReuseIdentifier: "TUISelectAvatarCollectionCell")
        view.addSubview(collectionView)
    }

    private func loadData() {
        switch selectAvatarType {
        case .userAvatar:
            for i in 0..<AvatarURLs.userAvatarCount {
                let cardItem = createCardItem(byURL: AvatarURLs.userAvatarURL(i + 1))
                dataArr.append(cardItem)
            }
        case .groupAvatar:
            if TUIConfig.default().enableGroupGridAvatar, let _ = cacheGroupGridAvatarImage {
                let cardItem = createGroupGridAvatarCardItem()
                dataArr.append(cardItem)
            }
            for i in 0..<AvatarURLs.groupAvatarCount {
                let cardItem = createCardItem(byURL: AvatarURLs.groupAvatarURL(i + 1))
                dataArr.append(cardItem)
            }
        case .conversationBackgroundCover:
            let cardItem = createCleanCardItem()
            dataArr.append(cardItem)
            for i in 0..<AvatarURLs.backgroundCoverCount {
                let cardItem = createCardItem(byURL: AvatarURLs.backgroundCoverURL(i + 1), fullUrl: AvatarURLs.backgroundCoverURLFull(i + 1))
                dataArr.append(cardItem)
            }
        case .cover:
            for i in 0..<AvatarURLs.communityCoverCount {
                let cardItem = createCardItem(byURL: AvatarURLs.communityCoverURL(i + 1))
                dataArr.append(cardItem)
            }
        }
        collectionView.reloadData()
    }

    private func createCardItem(byURL urlStr: String, fullUrl: String? = nil) -> TUISelectAvatarCardItem {
        let cardItem = TUISelectAvatarCardItem()
        cardItem.posterUrlStr = urlStr
        cardItem.fullUrlStr = fullUrl
        if let profilFaceURL = profilFaceURL {
            cardItem.isSelect = (cardItem.posterUrlStr == profilFaceURL || cardItem.fullUrlStr == profilFaceURL)
        }
        if cardItem.isSelect {
            currentSelectCardItem = cardItem
        }
        return cardItem
    }

    private func createGroupGridAvatarCardItem() -> TUISelectAvatarCardItem {
        let cardItem = TUISelectAvatarCardItem()
        cardItem.isGroupGridAvatar = true
        cardItem.createGroupType = createGroupType
        cardItem.cacheGroupGridAvatarImage = cacheGroupGridAvatarImage
        if profilFaceURL?.count == 0 {
            cardItem.isSelect = true
            currentSelectCardItem = cardItem
        }
        return cardItem
    }

    private func createCleanCardItem() -> TUISelectAvatarCardItem {
        let cardItem = TUISelectAvatarCardItem()
        cardItem.isDefaultBackgroundItem = true
        if profilFaceURL?.count == 0 {
            cardItem.isSelect = true
            currentSelectCardItem = cardItem
        }
        return cardItem
    }

    private func setupNavigator() {
        titleView = TUINaviBarIndicatorView()
        navigationItem.titleView = titleView
        navigationItem.title = ""

        switch selectAvatarType {
        case .cover:
            titleView.setTitle(TUISwift.timCommonLocalizableString("TUIKitChooseCover"))
        case .conversationBackgroundCover:
            titleView.setTitle(TUISwift.timCommonLocalizableString("TUIKitChooseBackground"))
        default:
            titleView.setTitle(TUISwift.timCommonLocalizableString("TUIKitChooseAvatar"))
        }

        rightButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        rightButton.setTitle(TUISwift.timCommonLocalizableString("Save"), for: .normal)
        rightButton.addTarget(self, action: #selector(rightBarButtonClick), for: .touchUpInside)
        rightButton.titleLabel?.font = UIFont(name: "PingFangSC-Regular", size: 14)
        rightButton.setTitleColor(.gray, for: .normal)

        let rightItem = UIBarButtonItem(customView: rightButton)
        navigationItem.rightBarButtonItems = [rightItem]
    }

    @objc private func rightBarButtonClick() {
        guard let currentSelectCardItem = currentSelectCardItem else { return }

        if let selectCallBack = selectCallBack {
            if selectAvatarType == .conversationBackgroundCover {
                if let fullUrlStr = currentSelectCardItem.fullUrlStr, !fullUrlStr.isEmpty {
                    DispatchQueue.main.async {
                        TUITool.makeToastActivity()
                    }
                    SDWebImagePrefetcher.shared.prefetchURLs([URL(string: fullUrlStr)!], progress: nil, completed: { [weak self] _, _ in
                        guard let self = self else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            DispatchQueue.main.async {
                                TUITool.hideToastActivity()
                                TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitChooseBackgroundSuccess"))
                                selectCallBack(fullUrlStr)
                                self.navigationController?.popViewController(animated: true)
                            }
                        }
                    })
                } else {
                    TUITool.makeToast(TUISwift.timCommonLocalizableString("TUIKitChooseBackgroundSuccess"))
                    selectCallBack(currentSelectCardItem.fullUrlStr ?? "")
                    navigationController?.popViewController(animated: true)
                }
            } else {
                selectCallBack(currentSelectCardItem.posterUrlStr ?? "")
                navigationController?.popViewController(animated: true)
            }
        }
    }

    // MARK: - UICollectionViewDelegateFlowLayout

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let margin: CGFloat = 15
        let padding: CGFloat = 13
        let rowCount: CGFloat = (selectAvatarType == .cover || selectAvatarType == .conversationBackgroundCover) ? 2 : 4
        let width = (view.frame.width - 2 * margin - (rowCount - 1) * padding) / rowCount
        let height: CGFloat = (selectAvatarType == .conversationBackgroundCover) ? 125 : 77
        return CGSize(width: width, height: height)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 24, left: 15, bottom: 0, right: 15)
    }

    // MARK: - UICollectionViewDataSource

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataArr.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "TUISelectAvatarCollectionCell", for: indexPath) as! TUISelectAvatarCollectionCell
        if indexPath.row < dataArr.count {
            cell.cardItem = dataArr[indexPath.row]
        }
        return cell
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        recoverSelectedStatus()

        var cell = collectionView.cellForItem(at: indexPath) as? TUISelectAvatarCollectionCell

        if cell == nil {
            collectionView.layoutIfNeeded()
            cell = collectionView.cellForItem(at: indexPath) as? TUISelectAvatarCollectionCell
        }

        if let cell = cell {
            if currentSelectCardItem === cell.cardItem {
                currentSelectCardItem = nil
            } else {
                cell.cardItem?.isSelect = true
                cell.updateSelectedUI()
                currentSelectCardItem = cell.cardItem
            }
        }
    }

    private func recoverSelectedStatus() {
        var index = 0
        for card in dataArr {
            if currentSelectCardItem === card {
                card.isSelect = false
                break
            }
            index += 1
        }

        let indexPath = IndexPath(row: index, section: 0)
        var cell = collectionView.cellForItem(at: indexPath) as? TUISelectAvatarCollectionCell

        if cell == nil {
            collectionView.layoutIfNeeded()
            cell = collectionView.cellForItem(at: indexPath) as? TUISelectAvatarCollectionCell
        }

        cell?.updateSelectedUI()
    }
}

// MARK: TUICommonAvatarCell & Data

public class TUICommonAvatarCellData: TUICommonCellData {
    @objc public dynamic var key: String = ""
    @objc public dynamic var value: String = ""
    public var showAccessory: Bool = false
    public var avatarImage: UIImage? = TUISwift.defaultAvatarImage()
    @objc public dynamic var avatarUrl: URL?

    override public init() {
        super.init()
        self.avatarImage = TUISwift.defaultAvatarImage()
    }

    override public func height(ofWidth width: CGFloat) -> CGFloat {
        let size = CGSize(width: 48, height: 48)
        return size.height + 2 * CGFloat(TPersonalCommonCell_Margin)
    }
}

public class TUICommonAvatarCell: TUICommonTableViewCell {
    var keyLabel: UILabel!
    var valueLabel: UILabel!
    var avatar: UIImageView!
    private(set) var avatarData: TUICommonAvatarCellData?
    private var keyObservation: NSKeyValueObservation?
    private var valueObservation: NSKeyValueObservation?
    private var avatarUrlObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: .value1, reuseIdentifier: reuseIdentifier)
        setupViews()
        self.selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func fill(with avatarData: TUICommonCellData) {
        super.fill(with: avatarData)
        guard let avatarData = avatarData as? TUICommonAvatarCellData else { return }
        self.avatarData = avatarData

        keyObservation = avatarData.observe(\.key, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newKey = change.newValue else { return }
            self.keyLabel.text = newKey
        }

        valueObservation = avatarData.observe(\.value, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newValue = change.newValue else { return }
            self.valueLabel.text = newValue
        }

        avatarUrlObservation = avatarData.observe(\.avatarUrl, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newUrl = change.newValue else { return }
            self.avatar.sd_setImage(with: newUrl, placeholderImage: self.avatarData?.avatarImage)
        }

        accessoryType = avatarData.showAccessory ? .disclosureIndicator : .none

        // Update constraints
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    private func setupViews() {
        avatar = UIImageView(frame: .zero)
        avatar.contentMode = .scaleAspectFit
        addSubview(avatar)

        keyLabel = textLabel
        valueLabel = detailTextLabel

        addSubview(keyLabel)
        addSubview(valueLabel)

        keyLabel.textColor = TUISwift.timCommonDynamicColor("form_key_text_color", defaultColor: "#444444")
        valueLabel.textColor = TUISwift.timCommonDynamicColor("form_value_text_color", defaultColor: "#000000")

        selectionStyle = .none
    }

    override public class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override public func prepareForReuse() {
        super.prepareForReuse()

        keyObservation?.invalidate()
        keyObservation = nil
        valueObservation?.invalidate()
        valueObservation = nil
        avatarUrlObservation?.invalidate()
        avatarUrlObservation = nil
    }

    override public func updateConstraints() {
        super.updateConstraints()
        let headSize = CGSize(width: 48, height: 48)
        avatar.snp.remakeConstraints { make in
            make.size.equalTo(headSize)
            if avatarData?.showAccessory == true {
                make.trailing.equalTo(contentView.snp.trailing).offset(-10)
            } else {
                make.trailing.equalTo(contentView.snp.trailing).offset(-20)
            }
            make.centerY.equalTo(self)
        }

        if TUIConfig.default().avatarType == .TAvatarTypeRounded {
            avatar.layer.masksToBounds = true
            avatar.layer.cornerRadius = headSize.height / 2
        } else if TUIConfig.default().avatarType == .TAvatarTypeRadiusCorner {
            avatar.layer.masksToBounds = true
            avatar.layer.cornerRadius = TUIConfig.default().avatarCornerRadius
        }
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
    }
}

// MARK: - TUIConversationGroupItem

public let kConversationMarkStarType: V2TIMConversationMarkType = .CONVERSATION_MARK_TYPE_STAR

public class TUIConversationGroupItem {
    public var groupName: String?
    public var unreadCount: Int = 0
    public var groupIndex: Int = 0
    public var isShow: Bool = true
    public var groupBtn: UIButton = .init()

    public init() {
        self.unreadCount = 0
        self.groupIndex = 0
        self.isShow = true
    }
}

public class TUISendMessageAppendParams {
    public var isSendPushInfo: Bool = false
    public var isOnlineUserOnly: Bool = false
    public var priority: V2TIMMessagePriority = .PRIORITY_DEFAULT

    public init() {}
    static var shared = TUISendMessageAppendParams()
}

// MARK: - Get block

public typealias SuccBlock = @convention(block) (UIViewController) -> Void
public typealias FailBlock = @convention(block) (Int32, String?) -> Void
public func getBlock<T>(from param: [AnyHashable: Any]?, key: String) -> T? {
    if let block = param?[key] as? AnyObject {
        return unsafeBitCast(block, to: T.self)
    }
    return nil
}
