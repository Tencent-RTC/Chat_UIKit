import SnapKit
import TIMCommon
import UIKit

/// Floating status bar that serves the "listen from here" feature only.
///
/// Collapsed: a white tab flush to the right screen edge (rounded left corners,
/// flat right edge) showing a blue waveform icon, matching the design spec.
/// Expanded: grows leftward to show the text currently being read plus a close
/// button. A loading spinner is shown only while the first item is preparing.
public final class TUIListenPlaybackBar: UIView {
    // MARK: - Public

    /// Invoked when the user taps the close button.
    public var onClose: (() -> Void)?

    // MARK: - Constants

    private static let tabHeight: CGFloat = 48
    private static let expandedHeight: CGFloat = 38
    private static let cornerRadius: CGFloat = 14
    private static let leadingPadding: CGFloat = 9
    private static let trailingPadding: CGFloat = 9
    private static let expandedTrailingInset: CGFloat = 8
    private static let waveformColor = UIColor(red: 0x1C / 255.0, green: 0x66 / 255.0, blue: 0xE5 / 255.0, alpha: 1)
    private static let shadowOpacity: Float = 0.12
    private static let shadowRadius: CGFloat = 12
    private static let shadowOffset = CGSize(width: 0, height: 6)
    private static let borderWidth: CGFloat = 1
    private static let borderColor = UIColor(white: 0, alpha: 0.08)

    // MARK: - State

    private var isExpanded: Bool = false
    private var shadowTrailingConstraint: Constraint?
    private var shadowHeightConstraint: Constraint?

    // MARK: - Subviews

    private let shadowView = UIView()
    private let contentView = UIView()
    private let contentStack = UIStackView()
    private let iconWrapper = UIView()
    private let waveformView = ListenWaveformView()
    private let spinner = UIActivityIndicatorView(style: .gray)
    private let textLabel = UILabel()
    private let closeButton = UIButton(type: .system)

    // MARK: - Init

    override public init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
        applyCollapsedAppearance()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Hit Testing

    /// The bar fills its parent as a transparent overlay. When collapsed, only
    /// touches on the visible tab are intercepted so everything else passes
    /// through to the message list underneath. When expanded, the whole overlay
    /// intercepts touches so a tap outside the tab can collapse it.
    override public func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        if isExpanded {
            return bounds.contains(point)
        }
        let pointInTab = convert(point, to: shadowView)
        return shadowView.bounds.contains(pointInTab)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        let corners: UIRectCorner = isExpanded ? .allCorners : [.topLeft, .bottomLeft]
        let path = UIBezierPath(
            roundedRect: contentView.bounds,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: TUIListenPlaybackBar.cornerRadius, height: TUIListenPlaybackBar.cornerRadius)
        )
        shadowView.layer.shadowPath = path.cgPath
    }

    // MARK: - Public API

    /// Shows the bar (collapsed) flush to the right edge, vertically centered.
    public func show(in parentView: UIView) {
        parentView.addSubview(self)
        snp.remakeConstraints { make in
            make.edges.equalToSuperview()
        }
        shadowView.snp.remakeConstraints { make in
            make.centerY.equalToSuperview()
            self.shadowTrailingConstraint = make.trailing.equalToSuperview().constraint
            self.shadowHeightConstraint = make.height.equalTo(TUIListenPlaybackBar.tabHeight).constraint
            make.width.lessThanOrEqualTo(TUIListenPlaybackBar.expandedMaxWidth())
        }
    }

    /// Max expanded width so the bar's left edge aligns with a same-side text
    /// message's left edge: text bubble width (text content max width plus the
    /// bubble's horizontal insets) + avatar width + the gap between the avatar
    /// and the bubble.
    private static func expandedMaxWidth() -> CGFloat {
        let textLayout = TUIMessageCellLayout.outgoingTextMessageLayout
        let bubbleWidth = TUISwift.tTextMessageCell_Text_Width_Max()
            + textLayout.bubbleInsets.left + textLayout.bubbleInsets.right
        let avatarWidth = textLayout.avatarSize.width
        let avatarBubbleGap = textLayout.messageInsets.right
        return bubbleWidth + avatarWidth + avatarBubbleGap
    }

    /// Enters the preparing state: shows the loading spinner.
    public func showPreparing() {
        spinner.startAnimating()
        spinner.isHidden = false
        waveformView.isHidden = true
    }

    /// Enters the playing state: hides the spinner and shows the waveform icon.
    public func showPlaying() {
        spinner.stopAnimating()
        spinner.isHidden = true
        waveformView.isHidden = false
    }

    /// Updates the text shown in the expanded state.
    public func updateText(_ text: String) {
        textLabel.text = text
    }

    /// Removes the bar from its superview.
    public func dismiss() {
        spinner.stopAnimating()
        removeFromSuperview()
    }

    // MARK: - Setup

    private func setupSubviews() {
        addSubview(shadowView)
        shadowView.backgroundColor = .clear
        shadowView.layer.shadowColor = UIColor.black.cgColor
        shadowView.layer.shadowOpacity = TUIListenPlaybackBar.shadowOpacity
        shadowView.layer.shadowRadius = TUIListenPlaybackBar.shadowRadius
        shadowView.layer.shadowOffset = TUIListenPlaybackBar.shadowOffset

        shadowView.addSubview(contentView)
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = TUIListenPlaybackBar.cornerRadius
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        contentView.layer.borderWidth = TUIListenPlaybackBar.borderWidth
        contentView.layer.borderColor = TUIListenPlaybackBar.borderColor.cgColor
        contentView.clipsToBounds = true
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        setupContentStack()
        setupIcon()
        setupTextLabel()
        setupCloseButton()
        setupTapGesture()
    }

    private func setupContentStack() {
        contentView.addSubview(contentStack)
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 6
        contentStack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(TUIListenPlaybackBar.leadingPadding)
            make.trailing.equalToSuperview().offset(-TUIListenPlaybackBar.trailingPadding)
        }
    }

    private func setupIcon() {
        iconWrapper.snp.makeConstraints { make in
            make.width.equalTo(18)
            make.height.equalTo(20)
        }
        iconWrapper.addSubview(waveformView)
        waveformView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(17)
            make.height.equalTo(18)
        }
        spinner.color = TUIListenPlaybackBar.waveformColor
        spinner.hidesWhenStopped = true
        iconWrapper.addSubview(spinner)
        spinner.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        contentStack.addArrangedSubview(iconWrapper)
    }

    private func setupTextLabel() {
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.textColor = UIColor(red: 0x1F / 255.0, green: 0x23 / 255.0, blue: 0x29 / 255.0, alpha: 1)
        textLabel.numberOfLines = 1
        textLabel.lineBreakMode = .byTruncatingTail
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textLabel.isHidden = true
        contentStack.addArrangedSubview(textLabel)
    }

    private func setupCloseButton() {
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(UIColor(white: 0.4, alpha: 1), for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        closeButton.addTarget(self, action: #selector(onCloseTapped), for: .touchUpInside)
        closeButton.isHidden = true
        closeButton.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
        contentStack.addArrangedSubview(closeButton)
    }

    private func setupTapGesture() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(onBarTapped))
        contentView.addGestureRecognizer(tap)

        let outsideTap = UITapGestureRecognizer(target: self, action: #selector(onOutsideTapped))
        outsideTap.delegate = self
        addGestureRecognizer(outsideTap)
    }

    // MARK: - Interaction

    @objc private func onBarTapped() {
        isExpanded.toggle()
        if isExpanded {
            applyExpandedAppearance()
        } else {
            applyCollapsedAppearance()
        }
    }

    @objc private func onCloseTapped() {
        onClose?()
    }

    @objc private func onOutsideTapped() {
        guard isExpanded else { return }
        isExpanded = false
        applyCollapsedAppearance()
    }

    // MARK: - Appearance

    private func applyCollapsedAppearance() {
        textLabel.isHidden = true
        closeButton.isHidden = true
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        shadowTrailingConstraint?.update(offset: 0)
        shadowHeightConstraint?.update(offset: TUIListenPlaybackBar.tabHeight)
        animateLayout()
    }

    private func applyExpandedAppearance() {
        textLabel.isHidden = false
        closeButton.isHidden = false
        contentView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        shadowTrailingConstraint?.update(offset: -TUIListenPlaybackBar.expandedTrailingInset)
        shadowHeightConstraint?.update(offset: TUIListenPlaybackBar.expandedHeight)
        animateLayout()
    }

    private func animateLayout() {
        UIView.animate(withDuration: 0.2) {
            self.superview?.layoutIfNeeded()
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TUIListenPlaybackBar: UIGestureRecognizerDelegate {
    /// The overlay's tap should only fire when the touch lands outside the
    /// visible tab; taps on the tab are handled by the content view's own tap
    /// so the expand/collapse toggle keeps working.
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let pointInTab = touch.location(in: shadowView)
        return !shadowView.bounds.contains(pointInTab)
    }
}

// MARK: - ListenWaveformView

/// Draws the three blue vertical bars of the waveform icon (per the design SVG).
private final class ListenWaveformView: UIView {
    private static let barColor = UIColor(red: 0x1C / 255.0, green: 0x66 / 255.0, blue: 0xE5 / 255.0, alpha: 1)
    private static let barWidth: CGFloat = 3
    private static let barRatios: [CGFloat] = [0.53, 0.95, 0.40]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        let count = ListenWaveformView.barRatios.count
        let barWidth = ListenWaveformView.barWidth
        let totalBarWidth = barWidth * CGFloat(count)
        let spacing = (rect.width - totalBarWidth) / CGFloat(count - 1)
        ListenWaveformView.barColor.setFill()

        for (index, ratio) in ListenWaveformView.barRatios.enumerated() {
            let barHeight = rect.height * ratio
            let x = CGFloat(index) * (barWidth + spacing)
            let y = (rect.height - barHeight) / 2
            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: barWidth / 2)
            path.fill()
        }
    }
}
