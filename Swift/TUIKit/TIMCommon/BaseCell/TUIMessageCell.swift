import SnapKit
import UIKit

public protocol TUIMessageCellProtocol: AnyObject {
    static func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat
    static func getEstimatedHeight(_ data: TUIMessageCellData) -> CGFloat
    static func getContentSize(_ data: TUIMessageCellData) -> CGSize
}

public protocol TUIMessageCellDelegate: AnyObject {
    func onLongPressMessage(_ cell: TUIMessageCell)
    func onRetryMessage(_ cell: TUIMessageCell)
    func onSelectMessage(_ cell: TUIMessageCell)
    func onSelectMessageAvatar(_ cell: TUIMessageCell)
    func onLongSelectMessageAvatar(_ cell: TUIMessageCell)
    func onSelectReadReceipt(_ cellData: TUIMessageCellData)
    func onJumpToRepliesDetailPage(_ data: TUIMessageCellData)
    func onJumpToMessageInfoPage(_ data: TUIMessageCellData, selectCell: TUIMessageCell)
}

public extension TUIMessageCellDelegate {
    func onLongPressMessage(_ cell: TUIMessageCell) {}
    func onRetryMessage(_ cell: TUIMessageCell) {}
    func onSelectMessage(_ cell: TUIMessageCell) {}
    func onSelectMessageAvatar(_ cell: TUIMessageCell) {}
    func onLongSelectMessageAvatar(_ cell: TUIMessageCell) {}
    func onSelectReadReceipt(_ cellData: TUIMessageCellData) {}
    func onJumpToRepliesDetailPage(_ data: TUIMessageCellData) {}
    func onJumpToMessageInfoPage(_ data: TUIMessageCellData, selectCell: TUIMessageCell) {}
}

open class TUIMessageCell: TUICommonTableViewCell, TUIMessageCellProtocol {
    public var selectedIcon = UIImageView()
    public var selectedView = UIButton(type: .custom)
    public var avatarView = UIImageView()
    public var nameLabel = UILabel()
    public var container = UIView()
    public var indicator = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.medium)
    public var retryView = UIImageView()
    public var securityStrikeView = TUISecurityStrikeView()
    public var messageModifyRepliesButton = TUIFitButton(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
    public var readReceiptLabel = UILabel()
    public var timeLabel = UILabel()
    public var bottomContainer = UIView()
    public var topContainer = UIView()

    public private(set) var messageData: TUIMessageCellData?
    public weak var delegate: TUIMessageCellDelegate?
    public var disableDefaultSelectAction = false
    public var highlightAnimating = false

    public var pluginMsgSelectCallback: TUIValueCallbck?
    private var readReceiptLabelTextObservation: NSKeyValueObservation?
    var avatarUrlObservation: NSKeyValueObservation?

    // MARK: - Init

    override public init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupSubViews()
        setupRAC()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubViews() {
        avatarView.contentMode = .scaleAspectFit
        contentView.addSubview(avatarView)
        let tap1 = UITapGestureRecognizer(target: self, action: #selector(onSelectMessageAvatar))
        avatarView.addGestureRecognizer(tap1)
        let tap2 = UILongPressGestureRecognizer(target: self, action: #selector(onLongSelectMessageAvatar))
        avatarView.addGestureRecognizer(tap2)
        avatarView.isUserInteractionEnabled = true

        nameLabel.font = fontWithSize(size: 13)
        nameLabel.textColor = .systemGray
        contentView.addSubview(nameLabel)

        container.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(onSelectMessage))
        tap.cancelsTouchesInView = false
        container.addGestureRecognizer(tap)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPress))
        container.addGestureRecognizer(longPress)
        contentView.addSubview(container)

        indicator.style = UIActivityIndicatorView.Style.medium
        indicator.sizeToFit()
        contentView.addSubview(indicator)

        retryView.isUserInteractionEnabled = true
        let resendTap = UITapGestureRecognizer(target: self, action: #selector(onRetryMessage))
        retryView.addGestureRecognizer(resendTap)
        contentView.addSubview(retryView)

        messageModifyRepliesButton.imageSize = CGSize(width: 12, height: 12)
        messageModifyRepliesButton.addTarget(self, action: #selector(onJumpToRepliesDetailPage(_:)), for: .touchUpInside)
        messageModifyRepliesButton.titleLabel?.font = fontWithSize(size: 12)
        messageModifyRepliesButton.setTitleColor(TUISwift.timCommonDynamicColor("chat_message_read_name_date_text_color", defaultColor: "#999999"), for: .normal)
        messageModifyRepliesButton.setImage(TUISwift.timCommonBundleThemeImage("chat_messageReplyIcon_img", defaultImage: "messageReplyIcon"), for: .normal)
        contentView.addSubview(messageModifyRepliesButton)

        readReceiptLabel.isHidden = true
        readReceiptLabel.font = fontWithSize(size: 12)
        readReceiptLabel.textColor = TUISwift.timCommonDynamicColor("chat_message_read_status_text_gray_color", defaultColor: "#BBBBBB")
        readReceiptLabel.lineBreakMode = .byCharWrapping
        let showReadReceiptTap = UITapGestureRecognizer(target: self, action: #selector(onSelectReadReceipt))
        readReceiptLabel.addGestureRecognizer(showReadReceiptTap)
        readReceiptLabel.isUserInteractionEnabled = true
        contentView.addSubview(readReceiptLabel)

        contentView.addSubview(selectedIcon)

        selectedView.backgroundColor = .clear
        selectedView.addTarget(self, action: #selector(onSelectMessage), for: .touchUpInside)
        contentView.addSubview(selectedView)

        timeLabel.textColor = .darkGray
        timeLabel.font = fontWithSize(size: 11.0)
        contentView.addSubview(timeLabel)

        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        makeConstraints()
    }

    private func makeConstraints() {
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(container.snp.leading).offset(7)
            make.top.equalTo(avatarView.snp.top)
            make.width.equalTo(1)
            make.height.equalTo(20)
        }

        selectedIcon.snp.makeConstraints { make in
            make.leading.equalTo(contentView.snp.leading).offset(3)
            make.top.equalTo(avatarView.snp.centerY).offset(-10)
            make.width.height.equalTo(20)
        }

        timeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(contentView.snp.trailing).offset(-10)
            make.top.equalTo(avatarView)
            make.width.greaterThanOrEqualTo(10)
            make.height.equalTo(10)
        }

        selectedView.snp.makeConstraints { make in
            make.edges.equalTo(contentView)
        }
    }

    override open class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override open func updateConstraints() {
        guard let messageData = messageData else { return }
        let cellLayout = messageData.cellLayout
        let isInComing = messageData.direction == TMsgDirection.incoming

        nameLabel.snp.remakeConstraints { make in
            if isInComing {
                make.leading.equalTo(container.snp.leading).offset(7)
                make.trailing.equalTo(contentView).offset(-7)
            } else {
                make.leading.equalTo(contentView).offset(7)
                make.trailing.equalTo(container.snp.trailing)
            }
            if messageData.showName {
                make.width.greaterThanOrEqualTo(20)
                make.height.greaterThanOrEqualTo(20)
            } else {
                make.height.equalTo(0)
            }
            make.top.equalTo(avatarView.snp.top)
        }

        selectedIcon.snp.remakeConstraints { make in
            make.leading.equalTo(contentView.snp.leading).offset(3)
            make.top.equalTo(avatarView.snp.centerY).offset(-10)
            if messageData.showCheckBox {
                make.width.height.equalTo(20)
            } else {
                make.size.equalTo(CGSize.zero)
            }
        }

        timeLabel.sizeToFit()
        timeLabel.snp.remakeConstraints { make in
            make.trailing.equalTo(contentView.snp.trailing).offset(-10)
            make.top.equalTo(avatarView)
            if messageData.showMessageTime {
                make.width.equalTo(timeLabel.frame.size.width)
                make.height.equalTo(timeLabel.frame.size.height)
            } else {
                make.width.height.equalTo(0)
            }
        }

        let contentSize = calculateContentSize(messageData)
        var contentWidth = contentSize.width
        var contentHeight = contentSize.height

        if messageData.messageContainerAppendSize != CGSize.zero {
            contentWidth = max(messageData.messageContainerAppendSize.width, contentWidth)
            contentWidth = min(contentWidth, TUISwift.screen_Width() * 0.25 * 3)
            contentHeight += messageData.messageContainerAppendSize.height
        }

        if messageData.direction == TMsgDirection.incoming {
            avatarView.isHidden = !messageData.showAvatar
            avatarView.snp.remakeConstraints { make in
                if messageData.showCheckBox {
                    make.leading.equalTo(selectedIcon.snp.trailing).offset(cellLayout?.avatarInsets.left ?? 0)
                } else {
                    make.leading.equalTo(contentView.snp.leading).offset(cellLayout?.avatarInsets.left ?? 0)
                }
                make.top.equalTo(cellLayout?.avatarInsets.top ?? 0)
                make.size.equalTo(cellLayout?.avatarSize ?? CGSize(width: 0, height: 0))
            }

            container.snp.remakeConstraints { make in
                make.leading.equalTo(avatarView.snp.trailing).offset(cellLayout?.messageInsets.left ?? 0)
                make.top.equalTo(nameLabel.snp.bottom).offset(cellLayout?.messageInsets.top ?? 0)
                make.width.equalTo(contentWidth)
                make.height.equalTo(contentHeight)
            }

            let indicatorFrame = indicator.frame
            indicator.snp.remakeConstraints { make in
                make.leading.equalTo(container.snp.trailing).offset(8)
                make.centerY.equalTo(container.snp.centerY)
                make.size.equalTo(indicatorFrame.size)
            }
            retryView.frame = indicator.frame
            readReceiptLabel.isHidden = true
        } else {
            if !messageData.showAvatar {
                cellLayout?.avatarSize = CGSize.zero
            }
            avatarView.snp.remakeConstraints { make in
                make.trailing.equalTo(contentView.snp.trailing).offset(-(cellLayout?.avatarInsets.right ?? 0))
                make.top.equalTo(cellLayout?.avatarInsets.top ?? 0)
                make.size.equalTo(cellLayout?.avatarSize ?? CGSize(width: 0, height: 0))
            }

            container.snp.remakeConstraints { make in
                make.trailing.equalTo(avatarView.snp.leading).offset(-(cellLayout?.messageInsets.right ?? 0))
                make.top.equalTo(nameLabel.snp.bottom).offset(cellLayout?.messageInsets.top ?? 0)
                make.width.equalTo(contentWidth)
                make.height.equalTo(contentHeight)
            }

            let indicatorFrame = indicator.frame
            indicator.snp.remakeConstraints { make in
                make.trailing.equalTo(container.snp.leading).offset(-8)
                make.centerY.equalTo(container.snp.centerY)
                make.size.equalTo(indicatorFrame.size)
            }

            retryView.frame = indicator.frame

            readReceiptLabel.sizeToFit()
            readReceiptLabel.snp.remakeConstraints { make in
                make.bottom.equalTo(container.snp.bottom)
                make.trailing.equalTo(container.snp.leading).offset(-8)
                make.size.equalTo(readReceiptLabel.frame.size)
            }
        }

        if !messageModifyRepliesButton.isHidden {
            messageModifyRepliesButton.sizeToFit()
            let repliesBtnTextWidth = messageModifyRepliesButton.frame.size.width
            messageModifyRepliesButton.snp.remakeConstraints { make in
                if isInComing {
                    make.leading.equalTo(container.snp.leading)
                } else {
                    make.trailing.equalTo(container.snp.trailing)
                }
                make.top.equalTo(container.snp.bottom)
                make.size.equalTo(CGSize(width: repliesBtnTextWidth + 10, height: 30))
            }
        }

        super.updateConstraints()
    }

    override open func layoutSubviews() {
        super.layoutSubviews()
    }

    private func setupRAC() {
        readReceiptLabelTextObservation = readReceiptLabel.observe(\.text, options: [.new, .initial]) { [weak self] _, _ in
            guard let self = self else { return }
            if self.shouldHighlightReadReceiptLabel() {
                self.readReceiptLabel.textColor = TUISwift.timCommonDynamicColor("chat_message_read_status_text_color", defaultColor: "#147AFF")
            } else {
                self.readReceiptLabel.textColor = TUISwift.timCommonDynamicColor("chat_message_read_status_text_gray_color", defaultColor: "#BBBBBB")
            }
        }
    }

    override open func prepareForReuse() {
        super.prepareForReuse()
        readReceiptLabel.text = ""
        readReceiptLabel.isHidden = true

        avatarUrlObservation?.invalidate()
        avatarUrlObservation = nil
        
        // Remove all pending animations to prevent "falling" effect when cell is reused
        // This is critical to fix the UI glitch where avatar/bubble slides from previous position
        layer.removeAllAnimations()
        contentView.layer.removeAllAnimations()
        avatarView.layer.removeAllAnimations()
        container.layer.removeAllAnimations()
        nameLabel.layer.removeAllAnimations()
    }

    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIMessageCellData else { return }
        messageData = data

        loadAvatar(data)

        nameLabel.isHidden = !data.showName

        selectedIcon.isHidden = !data.showCheckBox
        selectedView.isHidden = !data.showCheckBox

        if TUIConfig.default().avatarType == .TAvatarTypeRounded {
            avatarView.layer.masksToBounds = true
            avatarView.layer.cornerRadius = (data.cellLayout?.avatarSize.height ?? 0) / 2
        } else if TUIConfig.default().avatarType == .TAvatarTypeRadiusCorner {
            avatarView.layer.masksToBounds = true
            avatarView.layer.cornerRadius = TUIConfig.default().avatarCornerRadius
        }

        nameLabel.text = data.senderName

        if data.direction == .incoming {
            nameLabel.textColor = Self.incommingNameColor
            nameLabel.font = Self.incommingNameFont
        } else {
            nameLabel.textColor = Self.outgoingNameColor
            nameLabel.font = Self.outgoingNameFont
        }

        retryView.image = UIImage.safeImage(TUISwift.tuiChatImagePath("msg_error"))

        if data.status == .fail {
            indicator.stopAnimating()
            readReceiptLabel.isHidden = true
            retryView.isHidden = false
        } else {
            if data.status == .sending2 {
                indicator.startAnimating()
                readReceiptLabel.isHidden = true
            } else if data.status == .success {
                indicator.stopAnimating()
                if data.showReadReceipt && data.direction == .outgoing && (data.innerMessage?.needReadReceipt ?? false) &&
                    (data.innerMessage?.userID != nil || data.innerMessage?.groupID != nil) &&
                    !(data is TUISystemMessageCellData)
                {
                    updateReadLabelText()
                    readReceiptLabel.isHidden = false
                }
            } else if data.status == .sending {
                indicator.startAnimating()
                readReceiptLabel.isHidden = true
            }
            retryView.isHidden = true
        }

        messageModifyRepliesButton.isHidden = !data.showMessageModifyReplies
        if data.showMessageModifyReplies {
            let title = "\(data.messageModifyReplies?.count ?? 0)\(TUISwift.timCommonLocalizableString("TUIKitRepliesNum"))"
            messageModifyRepliesButton.setTitle(title, for: .normal)
            messageModifyRepliesButton.sizeToFit()
            messageModifyRepliesButton.setNeedsUpdateConstraints()
            messageModifyRepliesButton.updateConstraintsIfNeeded()
            messageModifyRepliesButton.layoutIfNeeded()
        }

        let imageName = (data.showCheckBox && data.selected) ? TUISwift.timCommonImagePath("icon_select_selected") : TUISwift.timCommonImagePath("icon_select_normal")
        selectedIcon.image = UIImage.safeImage(imageName)

        timeLabel.text = TUITool.convertDate(toStr: data.innerMessage?.timestamp)
        timeLabel.sizeToFit()
        timeLabel.isHidden = !data.showMessageTime

        DispatchQueue.main.async {
            if let keyword = data.highlightKeyword {
                self.highlightWhenMatchKeyword(keyword)
            }
        }

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    func loadAvatar(_ data: TUIMessageCellData) {
        avatarView.image = TUISwift.defaultAvatarImage()

        avatarUrlObservation = data.observe(\.avatarUrl, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let newUrl = change.newValue as? URL else { return }
            self.avatarView.sd_setImage(with: newUrl, placeholderImage: TUISwift.defaultAvatarImage())
        }

        if data.isUseMsgReceiverAvatar {
            var userId = ""
            if data.innerMessage?.sender == V2TIMManager.sharedInstance().getLoginUser() {
                userId = data.innerMessage?.userID ?? ""
            } else {
                userId = V2TIMManager.sharedInstance().getLoginUser() ?? ""
            }

            V2TIMManager.sharedInstance().getUsersInfo([userId]) { [weak self] infoList in
                guard let self = self else { return }
                if let info = infoList?.first, data === self.messageData {
                    data.avatarUrl = URL(string: info.faceURL ?? "")
                    self.avatarView.sd_setImage(with: data.avatarUrl, placeholderImage: TUISwift.defaultAvatarImage())
                }
            } fail: { _, _ in
                // Handle failure
            }
        }
    }

    open func highlightWhenMatchKeyword(_ keyword: String?) {
        guard let keyword = keyword, !keyword.isEmpty else {
            highlightAnimateView().layer.removeAnimation(forKey: "highlightAnimation")
            return
        }
        guard !highlightAnimating else { return }
        highlightAnimating = true
        let animation = CAKeyframeAnimation(keyPath: "backgroundColor")
        animation.repeatCount = 3
        animation.values = [
            UIColor.orange.withAlphaComponent(0.2).cgColor,
            UIColor.orange.withAlphaComponent(0.5).cgColor,
            UIColor.orange.withAlphaComponent(0.2).cgColor
        ]
        animation.duration = 0.5
        animation.isRemovedOnCompletion = true
        animation.delegate = self
        highlightAnimateView().layer.add(animation, forKey: "highlightAnimation")
    }

    func highlightAnimateView() -> UIView {
        return container
    }

    public func updateReadLabelText() {
        guard let messageData = messageData else { return }
        if let groupID = messageData.innerMessage?.groupID, !groupID.isEmpty {
            var text = TUISwift.timCommonLocalizableString("Unread")
            if let messageReceipt = messageData.messageReceipt {
                let readCount = messageReceipt.readCount
                let unreadCount = messageReceipt.unreadCount
                if unreadCount == 0 {
                    text = TUISwift.timCommonLocalizableString("TUIKitMessageReadAllRead")
                } else if readCount > 0 {
                    text = "\(readCount) \(TUISwift.timCommonLocalizableString("TUIKitMessageReadPartRead"))"
                }
            }
            readReceiptLabel.text = text
        } else {
            let isPeerRead = messageData.messageReceipt?.isPeerRead ?? false
            let text = isPeerRead ? TUISwift.timCommonLocalizableString("TUIKitMessageReadC2CRead") : TUISwift.timCommonLocalizableString("TUIKitMessageReadC2CUnRead")
            readReceiptLabel.text = text
        }
        readReceiptLabel.sizeToFit()
        readReceiptLabel.snp.remakeConstraints { make in
            make.bottom.equalTo(container.snp.bottom)
            make.trailing.equalTo(container.snp.leading).offset(-8)
            make.size.equalTo(readReceiptLabel.frame.size)
        }
        readReceiptLabel.textColor = shouldHighlightReadReceiptLabel() ? TUISwift.timCommonDynamicColor("chat_message_read_status_text_color", defaultColor: "#147AFF") : TUISwift.timCommonDynamicColor("chat_message_read_status_text_gray_color", defaultColor: "#BBBBBB")
    }

    open func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        // Override by subclass.
    }

    open func notifyTopContainerReady(of cellData: TUIMessageCellData?) {
        // Override by subclass.
    }

    // MARK: TUIMessageCellProtocol

    open class func getEstimatedHeight(_ data: TUIMessageCellData) -> CGFloat {
        return 60.0
    }

    open class func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat {
        var height: CGFloat = 0
        if data.showName { height += TUISwift.kScale390(20) }
        if data.showMessageModifyReplies { height += TUISwift.kScale390(22) }
        if data.messageContainerAppendSize.height > 0 {
            height += data.messageContainerAppendSize.height
        }
        let containerSize = calculateContentSizeForClassMethod(data)
        height += containerSize.height
        height += data.cellLayout?.messageInsets.top ?? 0
        height += data.cellLayout?.messageInsets.bottom ?? 0
        return max(height, 55)
    }

    open class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        return .zero
    }

    private func calculateContentSize(_ messageData: TUIMessageCellData) -> CGSize {
        if let cellType = type(of: self) as? TUIMessageCellProtocol.Type {
            return cellType.getContentSize(messageData)
        }
        return .zero
    }

    private class func calculateContentSizeForClassMethod(_ messageData: TUIMessageCellData) -> CGSize {
        let instance = self.init()
        return instance.calculateContentSize(messageData)
    }

    private func shouldHighlightReadReceiptLabel() -> Bool {
        if let groupID = messageData?.innerMessage?.groupID, !groupID.isEmpty {
            return readReceiptLabel.text != TUISwift.timCommonLocalizableString("TUIKitMessageReadAllRead")
        } else {
            return readReceiptLabel.text != TUISwift.timCommonLocalizableString("TUIKitMessageReadC2CRead")
        }
    }

    private func fontWithSize(size: CGFloat) -> UIFont {
        enum FontCache {
            static var cache = NSCache<NSNumber, UIFont>()
        }

        if let cachedFont = FontCache.cache.object(forKey: NSNumber(value: Float(size))) {
            return cachedFont
        } else {
            let font = UIFont.systemFont(ofSize: size)
            FontCache.cache.setObject(font, forKey: NSNumber(value: Float(size)))
            return font
        }
    }

    // MARK: Event

    @objc private func onLongPress(_ recognizer: UIGestureRecognizer) {
        if recognizer is UILongPressGestureRecognizer, recognizer.state == .began {
            delegate?.onLongPressMessage(self)
        }
    }

    @objc private func onRetryMessage(_ recognizer: UIGestureRecognizer) {
        if messageData?.status == .fail {
            delegate?.onRetryMessage(self)
        }
    }

    @objc private func onSelectMessage(_ recognizer: UIGestureRecognizer) {
        delegate?.onSelectMessage(self)
    }

    @objc private func onSelectMessageAvatar(_ recognizer: UIGestureRecognizer) {
        delegate?.onSelectMessageAvatar(self)
    }

    @objc private func onLongSelectMessageAvatar(_ recognizer: UIGestureRecognizer) {
        delegate?.onLongSelectMessageAvatar(self)
    }

    @objc private func onSelectReadReceipt(_ gesture: UITapGestureRecognizer) {
        if shouldHighlightReadReceiptLabel() {
            delegate?.onSelectReadReceipt(messageData!)
        }
    }

    @objc private func onJumpToRepliesDetailPage(_ btn: UIButton) {
        delegate?.onJumpToRepliesDetailPage(messageData!)
    }
}

public extension TUIMessageCell {
    static var incommingNameColor: UIColor? = .systemGray
    static var incommingNameFont: UIFont? = .systemFont(ofSize: 14)
    static var outgoingNameColor: UIColor? = .systemGray
    static var outgoingNameFont: UIFont? = .systemFont(ofSize: 14)
}

extension TUIMessageCell: CAAnimationDelegate {
    public func animationDidStart(_ anim: CAAnimation) {
        highlightAnimating = true
    }

    public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        highlightAnimating = false
    }
}
