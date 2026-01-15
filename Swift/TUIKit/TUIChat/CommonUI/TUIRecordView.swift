import TIMCommon
import TUICore
import UIKit
import SnapKit

public enum RecordZone {
    case cancel      // Cancel zone (left)
    case normal      // Normal send zone (center)
    case toText      // Convert to text zone (right)
}

public class TUIRecordView: UIView {
    
    // MARK: - Layout Constants
    
    private enum Layout {
        static let sendAreaHeight: CGFloat = 120
        static let buttonCircleSize: CGFloat = 80
        static let buttonSize: CGFloat = 48
        static let sendButtonSize: CGFloat = 80
        static let buttonContainerHeight: CGFloat = 100
        static let buttonBottomOffset: CGFloat = 135
        static let paddingSide: CGFloat = 30
        static let minBubbleHeight: CGFloat = 64
        static let maxBubbleHeight: CGFloat = 200
        static let bubbleArrowHeight: CGFloat = 6
        static let bubbleTextPadding: CGFloat = 12
        static let bubbleSpacing: CGFloat = 20
        static let animationDuration: TimeInterval = 0.22
        static let arrowOffsetFromRight: CGFloat = 58
        static let bubbleCornerRadius: CGFloat = 12
        static let waveformBarCount: Int = 13
        static let bottomWaveformBarCount: Int = 26
    }
    
    // MARK: - Color Constants
    
    private enum Colors {
        // Error red color
        static var errorRed: UIColor {
            TUISwift.tuiChatDynamicColor("chat_record_error_color", defaultColor: "#FA5251")
        }
        // Disabled button color (light blue)
        static var disabledBlue: UIColor {
            TUISwift.tuiChatDynamicColor("chat_record_disabled_btn_color", defaultColor: "#CCE2FF")
        }
        // Button background color - light: #DFE4ED, dark: #3D3D3D
        static var grayBackground: UIColor {
            TUISwift.tuiChatDynamicColor("chat_record_btn_bg_color", defaultColor: "#DFE4ED")
        }
        // Button text color - light: gray, dark: lighter gray
        static var grayText: UIColor {
            TUISwift.tuiChatDynamicColor("chat_record_btn_text_color", defaultColor: "#8F8F8F")
        }
        // Gradient background color - use existing theme color
        static var gradientBackground: UIColor {
            TUISwift.tuiChatDynamicColor("chat_input_controller_bg_color", defaultColor: "#FFFFFF")
        }
        // Waveform bar dark color for text processing state
        static var waveformBarDark: UIColor {
            TUISwift.tuiChatDynamicColor("chat_record_waveform_bar_color", defaultColor: "#0000004D")
        }
        // Dark text color for labels
        static var darkText: UIColor {
            TUISwift.tuiChatDynamicColor("chat_record_dark_text_color", defaultColor: "#000000E5")
        }
    }
    
    // MARK: - UI Components
    
    // Voice bubble container
    private var bubbleContainerView: UIView!
    private var bubbleBackgroundLayer: CAShapeLayer!
    
    // Waveform visualization 
    private var waveformContainer: UIView!
    private var waveformBars: [UIView] = []
    private var waveformValues: [CGFloat] = [] // Amplitude list
    
    
    private var bottomGradientLayer: CAGradientLayer!
    private var bottomOvalView: UIView!
    private var bottomOvalLayer: CAShapeLayer!
    
    // Bottom waveform background bubble (changes color based on state)
    private var bottomWaveformBackgroundView: UIView!
    
    // Bottom waveform bars (from Figma design)
    private var bottomWaveformContainer: UIView!
    private var bottomWaveformBars: [UIView] = []
    
    // Left/Right ellipse buttons 
    private var leftButtonContainer: UIView!
    private var leftButtonView: UIView!
    private var leftButtonIconView: UIImageView!
    
    private var rightButtonContainer: UIView!
    private var rightButtonView: UIView!
    private var rightButtonLabel: UILabel!
    
    
    private var centerHintLabel: UILabel!
    
    
    private var textProcessedContainer: UIView!
    
    private var textBubbleTextView: UITextView!
    private var bubbleLoadingIndicator: TUIBouncingDotsView! // Custom bouncing dots loading indicator
    
    
    private var cancelButtonView: UIView!
    private var cancelButtonContainer: UIView!
    private var cancelIconView: UIImageView!
    private var cancelLabel: UILabel!
    
    
    private var sendVoiceButtonView: UIView!
    private var sendVoiceButtonContainer: UIView!
    private var sendVoiceIconView: UIImageView!
    private var sendVoiceLabel: UILabel!
    
    
    private var sendButtonContainer: UIView!
    private var sendButtonView: UIView!
    private var sendButtonIconView: UIImageView! // Send button icon
    private var sendButtonTextLabel: UILabel! // Send button text label below icon
    private var sendButtonLabel: UILabel! // Keep for compatibility
    private var sendButtonLoadingBackgroundView: UIView!
    private var sendButtonLoadingLabel: UILabel! // Loading text label
    
    
    private var textProcessedContainerBottomConstraint: Constraint?
    
    private var overlayView: UIView! // Transparent overlay for dismissing error state
    
    public enum ConvertLocalVoiceToTextState {
        case idle           // Not started
        case processing     // Converting (loading)
        case success        // Conversion successful
        case failure        // Conversion failed
    }
    
    
    public var onSendVoice: (() -> Void)?
    public var onSendText: (() -> Void)?
    public var onCancelSend: (() -> Void)?
    
    
    private var convertedText: String = ""
    
    private var convertLocalVoiceToTextState: ConvertLocalVoiceToTextState = .idle
    private var isAnimatingTextHeight: Bool = false
    private var isAnimatingBubbleShape: Bool = false
    
    // MARK: - State
    
    private(set) public var currentZone: RecordZone = .normal
    
    private var bubbleLeadingConstraint: Constraint?
    private var bubbleTrailingConstraint: Constraint?
    private var bubbleHeightConstraint: Constraint?
    
    // Waveform animation timer
    private var waveformTimer: Timer?
    
    // Bottom waveform animation values
    private var bottomWaveformValues: [CGFloat] = []
    
    // Configurable bubble color
    public var bubbleNormalColor: UIColor = UIColor.tui_color(withHex: "#1C66E5");
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupLayout()
        
        // Initialize waveform values (13 items)
        waveformValues = Array(repeating: 0.1, count: 13)
        
        // Initialize bottom waveform values (26 items, matching bottom bar count)
        bottomWaveformValues = Array(repeating: 0.3, count: 26)
        
        // Start with alpha 0 for fade-in animation
        alpha = 0
        
        // Setup keyboard observers
        setupKeyboardObservers()
        
        // Listen for theme changes
        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: Notification.Name("TUIDidApplyingThemeChangedNotfication"), object: nil)
    }
    
    /// Show with fade-in animation (should be called after addSubview)
    public func showWithAnimation() {
        // Force layout first to ensure all frames are set correctly
        layoutIfNeeded()
        
        // Set initial state for spring animation (scale only, no translation)
        alpha = 0
        bubbleContainerView.alpha = 0 // Hide bubble during recording
        bubbleContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        centerHintLabel.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        leftButtonContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        rightButtonContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        bottomWaveformContainer.alpha = 0
        
        // Animate with spring effect (no translation, just scale and fade)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
            self.alpha = 1.0
            // Keep bubble hidden during recording (will be shown in enterTextProcessingState)
            self.centerHintLabel.transform = .identity
            self.leftButtonContainer.transform = .identity
            self.rightButtonContainer.transform = .identity
            self.bottomWaveformContainer.alpha = 1.0
            self.bottomWaveformBackgroundView.alpha = 1.0
        })
        
        // Start waveform animation
        startWaveformAnimation()
    }
    
    /// Hide with fade-out animation
    public func hideWithAnimation(completion: (() -> Void)? = nil) {
        // Stop waveform animation
        stopWaveformAnimation()
        
        // Animate with smooth scale-down effect (no translation)
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseIn], animations: {
            self.alpha = 0
            self.bubbleContainerView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            self.leftButtonContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            self.rightButtonContainer.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { _ in
            // Reset transforms for next show
            self.bubbleContainerView.transform = .identity
            self.leftButtonContainer.transform = .identity
            self.rightButtonContainer.transform = .identity
            completion?()
        })
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopWaveformAnimation()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        backgroundColor = .clear // Transparent background (gradient will be added)
        
        // Half-screen gradient (solid at bottom half, gradient to transparent above)
        // Uses theme color for dark mode support
        bottomGradientLayer = CAGradientLayer()
        updateGradientColors()
        bottomGradientLayer.locations = [0.0, 0.7, 1.0] // Bottom half solid, top half gradient
        bottomGradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0) // Bottom
        bottomGradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0) // Top
        layer.addSublayer(bottomGradientLayer)
        
        // Bottom waveform background bubble (rounded rectangle behind waveform bars)
        bottomWaveformBackgroundView = UIView()
        bottomWaveformBackgroundView.backgroundColor = bubbleNormalColor // Initial blue color
        bottomWaveformBackgroundView.layer.cornerRadius = 12 // Larger corner radius for taller bubble
        bottomWaveformBackgroundView.clipsToBounds = true
        addSubview(bottomWaveformBackgroundView)
        
        // Bottom waveform visualization (from Figma design: replaces oval)
        bottomWaveformContainer = UIView()
        bottomWaveformContainer.backgroundColor = .clear
        addSubview(bottomWaveformContainer)
        
        // Create bottom waveform bars (similar to bubble waveform but different heights)
        createBottomWaveformBars()
        
        // Keep bottomOvalView for compatibility (hidden)
        bottomOvalView = UIView()
        bottomOvalView.backgroundColor = .clear
        bottomOvalView.alpha = 0 // Hidden by default
        addSubview(bottomOvalView)
        
        bottomOvalLayer = CAShapeLayer()
        bottomOvalLayer.fillColor = UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1.0).cgColor
        bottomOvalView.layer.addSublayer(bottomOvalLayer)
        
        // Left ellipse button (cancel)
        leftButtonContainer = UIView()
        addSubview(leftButtonContainer)
        
        leftButtonView = UIView()
        leftButtonView.backgroundColor = Colors.grayBackground
        leftButtonContainer.addSubview(leftButtonView)
        
        leftButtonIconView = UIImageView(image: UIImage(systemName: "xmark"))
        leftButtonIconView.tintColor = Colors.grayText
        leftButtonIconView.contentMode = .scaleAspectFit
        leftButtonView.addSubview(leftButtonIconView)
        
        // Right ellipse button (convert to text)
        rightButtonContainer = UIView()
        addSubview(rightButtonContainer)
        
        rightButtonView = UIView()
        rightButtonView.backgroundColor = Colors.grayBackground
        rightButtonContainer.addSubview(rightButtonView)
        
        rightButtonLabel = UILabel()
        rightButtonLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        rightButtonLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputConvertToText")
        rightButtonLabel.textColor = Colors.grayText
        rightButtonLabel.textAlignment = .center
        rightButtonView.addSubview(rightButtonLabel)
        
        
        centerHintLabel = UILabel()
        centerHintLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        centerHintLabel.textColor = Colors.grayText
        centerHintLabel.textAlignment = .center
        centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputReleaseToSend")
        addSubview(centerHintLabel)
        
        // Bubble container
        bubbleContainerView = UIView()
        bubbleContainerView.backgroundColor = .clear
        bubbleContainerView.clipsToBounds = false
        addSubview(bubbleContainerView)
        
        // Bubble background layer (will be drawn with CustomPainter style)
        bubbleBackgroundLayer = CAShapeLayer()
        bubbleBackgroundLayer.fillColor = UIColor(red: 0.58, green: 0.93, blue: 0.42, alpha: 1.0).cgColor
        bubbleContainerView.layer.insertSublayer(bubbleBackgroundLayer, at: 0)
        
        // Waveform container
        waveformContainer = UIView()
        waveformContainer.backgroundColor = .clear
        waveformContainer.isUserInteractionEnabled = false 
        bubbleContainerView.addSubview(waveformContainer)
        
        // Create 13 waveform bars 
        createWaveformBars()
        
        // Text processing UI (second level, hidden by default)
        setupTextProcessedUI()
    }
    
    private func setupTextProcessedUI() {
        // Container for text processing UI
        textProcessedContainer = UIView()
        textProcessedContainer.backgroundColor = .clear
        textProcessedContainer.alpha = 0 // Hidden by default
        addSubview(textProcessedContainer)
        
        // Transparent overlay view for dismissing error state (tapping blank area)
        overlayView = UIView()
        overlayView.backgroundColor = .clear
        overlayView.alpha = 0 // Hidden by default
        textProcessedContainer.addSubview(overlayView)
        
        let overlayTap = UITapGestureRecognizer(target: self, action: #selector(handleOverlayTap))
        overlayView.addGestureRecognizer(overlayTap)
        overlayView.isUserInteractionEnabled = false
        textBubbleTextView = UITextView()
        textBubbleTextView.backgroundColor = .clear
        textBubbleTextView.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        textBubbleTextView.textColor = .white
        textBubbleTextView.tintColor = .white
        textBubbleTextView.textAlignment = .left
        textBubbleTextView.isEditable = true
        textBubbleTextView.isScrollEnabled = false
        textBubbleTextView.isUserInteractionEnabled = true
        textBubbleTextView.textContainerInset = UIEdgeInsets.zero
        textBubbleTextView.delegate = self
        textBubbleTextView.showsVerticalScrollIndicator = true
        textBubbleTextView.indicatorStyle = .white
        
        // Custom bouncing dots loading indicator (replaces GIF)
        bubbleLoadingIndicator = TUIBouncingDotsView()
        bubbleLoadingIndicator.isHidden = true
        
        
        cancelButtonContainer = UIView()
        textProcessedContainer.addSubview(cancelButtonContainer)
        
        cancelButtonView = UIView()
        cancelButtonView.backgroundColor = Colors.grayBackground
        cancelButtonContainer.addSubview(cancelButtonView)
        
        cancelIconView = UIImageView(image: UIImage(systemName: "xmark"))
        cancelIconView.tintColor = Colors.grayText
        cancelIconView.contentMode = .scaleAspectFit
        cancelButtonView.addSubview(cancelIconView)
        
        cancelLabel = UILabel()
        cancelLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        cancelLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputCancel")
        cancelLabel.textColor = Colors.grayText
        cancelLabel.textAlignment = .center
        cancelButtonContainer.addSubview(cancelLabel)
        
        let cancelTap = UITapGestureRecognizer(target: self, action: #selector(handleCancelSend))
        cancelButtonContainer.addGestureRecognizer(cancelTap)
        cancelButtonContainer.isUserInteractionEnabled = true
        
        
        sendVoiceButtonContainer = UIView()
        textProcessedContainer.addSubview(sendVoiceButtonContainer)
        
        sendVoiceButtonView = UIView()
        sendVoiceButtonView.backgroundColor = Colors.grayBackground
        sendVoiceButtonContainer.addSubview(sendVoiceButtonView)
        
        sendVoiceIconView = UIImageView(image: createVoiceWaveIcon(color: Colors.grayText))
        sendVoiceIconView.contentMode = .scaleAspectFit
        sendVoiceButtonView.addSubview(sendVoiceIconView)
        
        sendVoiceLabel = UILabel()
        sendVoiceLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        sendVoiceLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputSendOriginalVoice")
        sendVoiceLabel.textColor = Colors.grayText
        sendVoiceLabel.textAlignment = .center
        sendVoiceButtonContainer.addSubview(sendVoiceLabel)
        
        let sendVoiceTap = UITapGestureRecognizer(target: self, action: #selector(handleSendVoice))
        sendVoiceButtonContainer.addGestureRecognizer(sendVoiceTap)
        sendVoiceButtonContainer.isUserInteractionEnabled = true
        
        // Send button container (right, large 80x80 button with loading/send state)
        sendButtonContainer = UIView()
        textProcessedContainer.addSubview(sendButtonContainer)
        
        // Send button view (large circular 80x80, light blue during loading, blue after conversion)
        sendButtonView = UIView()
        sendButtonView.backgroundColor = Colors.disabledBlue
        sendButtonView.alpha = 0
        sendButtonView.isUserInteractionEnabled = false
        sendButtonContainer.addSubview(sendButtonView)
        
        // Send button icon (hidden, not used)
        sendButtonIconView = UIImageView(image: UIImage(systemName: "paperplane.fill"))
        sendButtonIconView.tintColor = Colors.grayText
        sendButtonIconView.contentMode = .scaleAspectFit
        sendButtonIconView.alpha = 0
        sendButtonView.addSubview(sendButtonIconView)
        
        // Send button label
        sendButtonLabel = UILabel()
        sendButtonLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        sendButtonLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputSend")
        sendButtonLabel.textColor = UIColor.tui_color(withHex: "#1C66E5") // Blue text during loading
        sendButtonLabel.textAlignment = .center
        sendButtonView.addSubview(sendButtonLabel)
        
        // Send button text label below the button (hidden, not used)
        sendButtonTextLabel = UILabel()
        sendButtonTextLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        sendButtonTextLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputSend")
        sendButtonTextLabel.textColor = Colors.grayText
        sendButtonTextLabel.textAlignment = .center
        sendButtonTextLabel.alpha = 0
        sendButtonContainer.addSubview(sendButtonTextLabel)
        
        let sendTap = UITapGestureRecognizer(target: self, action: #selector(handleSendText))
        sendButtonView.addGestureRecognizer(sendTap)
        
        // Loading background view (circular 80x80, light blue)
        sendButtonLoadingBackgroundView = UIView()
        sendButtonLoadingBackgroundView.backgroundColor = Colors.disabledBlue
        sendButtonLoadingBackgroundView.alpha = 0
        sendButtonContainer.addSubview(sendButtonLoadingBackgroundView)
        
        // Loading label (shown during conversion)
        sendButtonLoadingLabel = UILabel()
        sendButtonLoadingLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
        sendButtonLoadingLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputSend")
        sendButtonLoadingLabel.textColor = .white
        sendButtonLoadingLabel.textAlignment = .center
        sendButtonLoadingLabel.alpha = 0
        sendButtonLoadingBackgroundView.addSubview(sendButtonLoadingLabel)
    }
    
    @objc private func handleSendVoice() {
        onSendVoice?()
    }
    
    @objc private func handleSendText() {
        textBubbleTextView.resignFirstResponder()
        onSendText?()
    }
    
    @objc private func handleCancelSend() {
        onCancelSend?()
    }
    
    @objc private func handleOverlayTap() {
        // Completely dismiss when tapping overlay (same as cancel button)
        onCancelSend?()
    }
    
    private func createWaveformBars() {
        for _ in 0..<Layout.waveformBarCount {
            let bar = UIView()
            bar.backgroundColor = .white
            bar.layer.cornerRadius = 2
            waveformContainer.addSubview(bar)
            waveformBars.append(bar)
        }
    }
    
    /// Create bottom waveform bars based on Figma design
    private func createBottomWaveformBars() {
        for _ in 0..<Layout.bottomWaveformBarCount {
            let bar = UIView()
            bar.backgroundColor = .white
            bar.layer.cornerRadius = 2
            bottomWaveformContainer.addSubview(bar)
            bottomWaveformBars.append(bar)
        }
    }
    
    private func setupLayout() { 
        
        // Bottom oval view (hidden, replaced by waveform)
        bottomOvalView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(Layout.sendAreaHeight)
        }
        
        // Bottom waveform background bubble (behind waveform bars)
        // Width = screen width - 8px on each side
        bottomWaveformBackgroundView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
            make.bottom.equalToSuperview().offset(-Layout.sendAreaHeight / 2 + 10)
            make.height.equalTo(40) // Capsule height (matching Figma design)
        }
        
        // Bottom waveform container (from Figma design)
        // Width = 2/3 of capsule width
        bottomWaveformContainer.snp.makeConstraints { make in
            make.center.equalTo(bottomWaveformBackgroundView) // Centered on background bubble
            make.width.equalTo(bottomWaveformBackgroundView).multipliedBy(2.0 / 3.0) // 2/3 of capsule width
            make.height.equalTo(24) // Increased height for dynamic animation
        }
        
        // Layout bottom waveform bars
        layoutBottomWaveformBars()
        
        // Left circle button container (centered relative to screen)
        let buttonSpacing: CGFloat = 60 // Spacing between two buttons
        leftButtonContainer.snp.makeConstraints { make in
            make.trailing.equalTo(self.snp.centerX).offset(-buttonSpacing / 2)
            make.bottom.equalToSuperview().offset(-(Layout.sendAreaHeight + 15))
            make.width.height.equalTo(Layout.buttonCircleSize)
        }
        
        leftButtonView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        leftButtonIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(24)
        }
        
        // Right circle button container (centered relative to screen)
        rightButtonContainer.snp.makeConstraints { make in
            make.leading.equalTo(self.snp.centerX).offset(buttonSpacing / 2)
            make.bottom.equalToSuperview().offset(-(Layout.sendAreaHeight + 15))
            make.width.height.equalTo(Layout.buttonCircleSize)
        }
        
        rightButtonView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        rightButtonLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        // Center hint label (above the buttons)
        centerHintLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(leftButtonContainer.snp.top).offset(-10)
        }
        
        bubbleContainerView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            bubbleHeightConstraint = make.height.equalTo(Layout.minBubbleHeight + Layout.bubbleArrowHeight).constraint
            bubbleLeadingConstraint = make.leading.equalToSuperview().offset(Layout.paddingSide + Layout.buttonCircleSize / 2 + 10).constraint
            bubbleTrailingConstraint = make.trailing.equalToSuperview().offset(-(Layout.paddingSide + Layout.buttonCircleSize / 2 + 10)).constraint
        }
        
        // Waveform container
        waveformContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(40)
        }
        
        // Layout waveform bars (13 bars, centered)
        layoutWaveformBars()
        
        // Layout text processing UI
        layoutTextProcessedUI()
    }
    
    private func layoutTextProcessedUI() {
        let screenWidth = TUISwift.screen_Width()
        let sideMargin: CGFloat = 48 // All buttons group 48px from both sides
        let buttonSize = Layout.buttonSize // Small buttons 48x48
        let sendButtonSize = Layout.sendButtonSize // Send button 80x80
        // Use same bottom offset as first stage buttons (sendAreaHeight + 15)
        let buttonBottomOffset = Layout.sendAreaHeight + 15
        
        // Text processed container
        textProcessedContainer.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            textProcessedContainerBottomConstraint = make.bottom.equalToSuperview().constraint
        }
        
        // Overlay view (full screen, behind bubble and buttons)
        overlayView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Calculate spacing between buttons
        // Total width available = screenWidth - sideMargin * 2
        // Total buttons width = buttonSize * 2 + sendButtonSize
        // Spacing = (available - buttons) / 2
        let totalButtonsWidth = buttonSize * 2 + sendButtonSize
        let availableWidth = screenWidth - sideMargin * 2
        let buttonSpacing = (availableWidth - totalButtonsWidth) / 2
        
        // Cancel button container (left, 48x48, 48px from left edge)
        cancelButtonContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(sideMargin)
            make.width.height.equalTo(buttonSize)
        }
        
        // Send voice button container (middle, 48x48)
        sendVoiceButtonContainer.snp.makeConstraints { make in
            make.leading.equalTo(cancelButtonContainer.snp.trailing).offset(buttonSpacing)
            make.width.height.equalTo(buttonSize)
        }
        
        // Send button container (right, 80x80, same bottom offset as first stage)
        sendButtonContainer.snp.makeConstraints { make in
            make.leading.equalTo(sendVoiceButtonContainer.snp.trailing).offset(buttonSpacing)
            make.trailing.equalToSuperview().offset(-sideMargin) // 48px from right edge
            make.bottom.equalToSuperview().offset(-buttonBottomOffset)
            make.width.height.equalTo(sendButtonSize)
        }
        
        // Small buttons Y-axis centered relative to send button
        cancelButtonContainer.snp.makeConstraints { make in
            make.centerY.equalTo(sendButtonContainer)
        }
        
        sendVoiceButtonContainer.snp.makeConstraints { make in
            make.centerY.equalTo(sendButtonContainer)
        }
        
        cancelButtonView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(buttonSize)
        }
        
        cancelIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(Layout.bubbleSpacing)
        }
        
        cancelLabel.snp.makeConstraints { make in
            make.top.equalTo(cancelButtonView.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
        }
        
        sendVoiceButtonView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.centerX.equalToSuperview()
            make.width.height.equalTo(buttonSize)
        }
        
        sendVoiceIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        sendVoiceLabel.snp.makeConstraints { make in
            make.top.equalTo(sendVoiceButtonView.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
        }
        
        // Send button view (large circular 80x80)
        sendButtonView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Send button icon (hidden)
        sendButtonIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(20)
        }
        
        // Send button label 
        sendButtonLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        // Send button text label below the button (hidden)
        sendButtonTextLabel.snp.makeConstraints { make in
            make.top.equalTo(sendButtonView.snp.bottom).offset(4)
            make.centerX.equalToSuperview()
        }
        
        // Loading background view (circular 80x80)
        sendButtonLoadingBackgroundView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Loading label (centered in circular loading background)
        sendButtonLoadingLabel.snp.makeConstraints { make in
            make.center.equalTo(sendButtonLoadingBackgroundView)
        }
    }
    
    private func layoutWaveformBars() {
        let barWidth: CGFloat = 3
        let barSpacing: CGFloat = 3
        let centerIndex = waveformBars.count / 2
        
        for (index, bar) in waveformBars.enumerated() {
            let offset = CGFloat(index - centerIndex) * (barWidth + barSpacing)
            bar.snp.makeConstraints { make in
                make.width.equalTo(barWidth)
                make.centerX.equalToSuperview().offset(offset)
                make.centerY.equalToSuperview()
                make.height.equalTo(8) // Initial height
            }
        }
    }
    
    /// Layout bottom waveform bars based on Figma design (dynamic style like bubble waveform)
    private func layoutBottomWaveformBars() {
        let barWidth: CGFloat = 3 // Bar width
        let barSpacing: CGFloat = 6 // Spacing between bars
        let barCount = bottomWaveformBars.count
        
        // Calculate total width
        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = -totalWidth / 2
        
        for (index, bar) in bottomWaveformBars.enumerated() {
            let xOffset = startX + CGFloat(index) * (barWidth + barSpacing) + barWidth / 2
            
            bar.snp.makeConstraints { make in
                make.width.equalTo(barWidth)
                make.centerX.equalToSuperview().offset(xOffset)
                make.centerY.equalToSuperview()
                make.height.equalTo(6) // Initial height (will animate)
            }
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Update gradient frame (half-screen white gradient from bottom)
        let gradientHeight = bounds.height / 2 // Half screen height
        bottomGradientLayer.frame = CGRect(
            x: 0,
            y: bounds.height - gradientHeight,
            width: bounds.width,
            height: gradientHeight
        )
        
        // Bottom oval is now replaced by waveform bars (no oval drawing needed)
        // Update bottom oval layer frame to match bottomOvalView (for compatibility)
        bottomOvalLayer.frame = bottomOvalView.bounds
        
        // Round corners for ellipse buttons (use height / 2 for fully rounded ends)
        leftButtonView.layer.cornerRadius = leftButtonView.bounds.height / 2
        rightButtonView.layer.cornerRadius = rightButtonView.bounds.height / 2
        
        // Round corners for text processing buttons
        if cancelButtonView != nil {
            cancelButtonView.layer.cornerRadius = cancelButtonView.bounds.height / 2
        }
        if sendVoiceButtonView != nil {
            sendVoiceButtonView.layer.cornerRadius = sendVoiceButtonView.bounds.height / 2
        }
        if sendButtonView != nil {
            sendButtonView.layer.cornerRadius = sendButtonView.bounds.height / 2
        }
        if sendButtonLoadingBackgroundView != nil {
            sendButtonLoadingBackgroundView.layer.cornerRadius = sendButtonLoadingBackgroundView.bounds.height / 2
        }
        
        // Draw bubble with arrow (without animation in layoutSubviews)
        if !isAnimatingTextHeight && !isAnimatingBubbleShape {
            updateBubbleShape(animated: false)
        }
    }
    
    // MARK: - Theme Support
    
    @objc private func onThemeChanged() {
        updateGradientColors()
        applyThemeColors()
    }
    
    /// Update gradient layer colors for dark mode support
    private func updateGradientColors() {
        let bgColor = Colors.gradientBackground
        bottomGradientLayer.colors = [
            bgColor.cgColor,
            bgColor.cgColor,
            bgColor.withAlphaComponent(0.0).cgColor
        ]
    }
    
    /// Apply theme colors to all UI elements
    private func applyThemeColors() {
        // Update button backgrounds
        leftButtonView.backgroundColor = Colors.grayBackground
        rightButtonView.backgroundColor = Colors.grayBackground
        cancelButtonView?.backgroundColor = Colors.grayBackground
        sendVoiceButtonView?.backgroundColor = Colors.grayBackground
        
        // Update text colors
        leftButtonIconView.tintColor = Colors.grayText
        rightButtonLabel.textColor = Colors.grayText
        centerHintLabel.textColor = Colors.grayText
        cancelLabel?.textColor = Colors.grayText
        sendVoiceLabel?.textColor = Colors.grayText
        sendButtonTextLabel?.textColor = Colors.grayText
        
        // Update icon colors
        cancelIconView?.tintColor = Colors.grayText
        sendVoiceIconView?.image = createVoiceWaveIcon(color: Colors.grayText)
        sendButtonIconView?.tintColor = Colors.grayText
        
        // Update loading button colors
        sendButtonLoadingBackgroundView?.backgroundColor = Colors.disabledBlue
    }
    
    /// Calculate arrow X position based on current state and zone
    private func calculateArrowCenterX(for width: CGFloat, zone: RecordZone? = nil) -> CGFloat {
        let targetZone = zone ?? currentZone
        
        // Check if in text processing state (stage 2)
        let isTextProcessing = convertLocalVoiceToTextState == .processing ||
                               convertLocalVoiceToTextState == .success ||
                               convertLocalVoiceToTextState == .failure
        
        if isTextProcessing {
            return width - Layout.arrowOffsetFromRight
        }
        
        switch targetZone {
        case .cancel:
            return width * 0.25
        case .toText:
            return width - Layout.arrowOffsetFromRight
        case .normal:
            return width / 2
        }
    }
    
    private func updateBubbleShape(animated: Bool = false) {
        let rect = bubbleContainerView.bounds
        let bubbleHeight = max(Layout.minBubbleHeight, rect.height - Layout.bubbleArrowHeight)
        let arrowCenterX = calculateArrowCenterX(for: rect.width)
        let path = createBubblePath(width: rect.width, height: bubbleHeight, arrowX: arrowCenterX)
        bubbleBackgroundLayer.path = path
    }
    
    /// Create bubble path with specified parameters
    private func createBubblePath(width: CGFloat, height: CGFloat, arrowX: CGFloat) -> CGPath {
        let path = UIBezierPath()
        let rrect = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: width, height: height), cornerRadius: Layout.bubbleCornerRadius)
        path.append(rrect)
        
        // Triangle arrow (bottom part)
        path.move(to: CGPoint(x: arrowX - 7, y: height))
        path.addLine(to: CGPoint(x: arrowX, y: height + Layout.bubbleArrowHeight))
        path.addLine(to: CGPoint(x: arrowX + 7, y: height))
        path.close()
        
        return path.cgPath
    }
    
    // MARK: - Public Methods
    
    func setStatus(_ status: RecordStatus) {
        switch status {
        case .recording:
            updateZoneUI(.normal)
        case .cancel:
            updateZoneUI(.cancel)
        case .tooShort:
            centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputRecordTimeshort")
        case .tooLong:
            centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputRecordTimeLong")
        }
    }
    
    /// Update recording time and show countdown warning when approaching max duration
    func updateRecordingTime(_ currentTime: TimeInterval, maxDuration: TimeInterval) {
        let remainingSeconds = Int(maxDuration - currentTime)
        
        // Show countdown warning in last 10 seconds
        if remainingSeconds <= 10 && remainingSeconds > 0 {
            centerHintLabel.text = String(format: TUISwift.timCommonLocalizableString("TUIKitInputWillFinishRecordInSeconds"), remainingSeconds)
        } else if currentZone == .normal {
            // Reset to normal hint when not in countdown
            centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputReleaseToSend")
        }
    }
    
    func setPower(_ power: Int) {
        // Update amplitude list 
        let normalizedPower = CGFloat(power + 60) / 60.0
        let amplitude = max(0.1, min(1.0, normalizedPower))
        
        // Shift list and add new value
        waveformValues.removeFirst()
        waveformValues.append(amplitude)
        
        // Animate waveform bars
        animateWaveformBars()
    }
    
    private func animateWaveformBars() {
        // Update bar heights 
        let maxHeight: CGFloat = 30 
        
        for (index, bar) in waveformBars.enumerated() {
            let amplitude = waveformValues[safe: index] ?? 0.1
            // Matches 
            let scale = min(max(amplitude * 1.5, 0.1), 1.0)
            let targetHeight = maxHeight * scale
            
            UIView.animate(withDuration: 0.1, delay: 0, options: [.curveEaseInOut], animations: {
                bar.snp.updateConstraints { make in
                    make.height.equalTo(targetHeight)
                }
                self.waveformContainer.layoutIfNeeded()
            })
        }
    }
    
    /// Animate bottom waveform bars (similar to bubble waveform, or small dots in text processing state)
    private func animateBottomWaveformBars() {
        // Check if in text processing state
        if convertLocalVoiceToTextState == .processing || convertLocalVoiceToTextState == .success || convertLocalVoiceToTextState == .failure {
            // Show as small black dots (fixed small height)
            let dotHeight: CGFloat = 6
            
            for bar in bottomWaveformBars {
                UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: {
                    bar.snp.updateConstraints { make in
                        make.height.equalTo(dotHeight)
                    }
                    self.bottomWaveformContainer.layoutIfNeeded()
                })
            }
        } else {
            // Normal recording state: dynamic waveform animation
            let maxHeight: CGFloat = 20
            
            for (index, bar) in bottomWaveformBars.enumerated() {
                let amplitude = bottomWaveformValues[safe: index] ?? 0.3
                let scale = min(max(amplitude, 0.2), 1.0)
                let targetHeight = maxHeight * scale
                
                UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseInOut], animations: {
                    bar.snp.updateConstraints { make in
                        make.height.equalTo(targetHeight)
                    }
                    self.bottomWaveformContainer.layoutIfNeeded()
                })
            }
        }
    }
    
    /// Update bottom waveform background bubble color
    private func updateBottomWaveformBackgroundColor(_ color: UIColor) {
        UIView.animate(withDuration: Layout.animationDuration) {
            self.bottomWaveformBackgroundView.backgroundColor = color
        }
    }
    
    // MARK: - Waveform Animation
    
    private func startWaveformAnimation() {
        stopWaveformAnimation()
        
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.updateWaveformWithRandomValues()
        }
    }
    
    private func stopWaveformAnimation() {
        waveformTimer?.invalidate()
        waveformTimer = nil
    }
    
    private func updateWaveformWithRandomValues() {
        // Generate random amplitude values with center emphasis (higher in middle, lower at edges)
        let centerIndex = 6 // Center of 13 bars (0-12)
        let randomAmplitudes = (0..<13).map { index -> CGFloat in
            // Calculate distance from center (0.0 at center, 1.0 at edges)
            let distanceFromCenter = abs(CGFloat(index - centerIndex)) / CGFloat(centerIndex)
            
            // Create a curve that reduces amplitude at edges
            // At center: multiplier ≈ 1.0, at edges: multiplier ≈ 0.3
            let positionMultiplier = 1.0 - (distanceFromCenter * 0.7)
            
            // Random base amplitude
            let baseAmplitude = CGFloat.random(in: 0.4...1.0)
            
            // Apply position-based reduction
            return baseAmplitude * positionMultiplier
        }
        
        waveformValues = randomAmplitudes
        animateWaveformBars()
        
        // Update bottom waveform with different random values (26 bars)
        let bottomRandomAmplitudes = (0..<26).map { _ -> CGFloat in
            CGFloat.random(in: 0.3...0.9)
        }
        
        bottomWaveformValues = bottomRandomAmplitudes
        animateBottomWaveformBars()
    }
    
    // MARK: - Haptic Feedback
    
    private lazy var hapticGenerator: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        return generator
    }()
    
    private func showHapticFeedback() {
        hapticGenerator.impactOccurred()
        hapticGenerator.prepare() // Prepare for next use
    }
    
    // MARK: - Zone Update Methods
    
    /// Update current zone based on touch point 
    public func updateZone(touchPoint: CGPoint) {
        // Convert touch point to button container's coordinate system directly
        let leftLocalPoint = leftButtonContainer.convert(touchPoint, from: nil)
        let rightLocalPoint = rightButtonContainer.convert(touchPoint, from: nil)
        
        // Expand button bounds for easier touch (add padding)
        let padding: CGFloat = 20
        let leftButtonBounds = leftButtonContainer.bounds.insetBy(dx: -padding, dy: -padding)
        let rightButtonBounds = rightButtonContainer.bounds.insetBy(dx: -padding, dy: -padding)
        
        var newZone: RecordZone = .normal
        
        let isInLeftButton = leftButtonBounds.contains(leftLocalPoint)
        let isInRightButton = rightButtonBounds.contains(rightLocalPoint)
        
        if isInLeftButton && !isInRightButton {
            newZone = .cancel
        } else if isInRightButton && !isInLeftButton {
            newZone = .toText
        } else if isInLeftButton && isInRightButton {
            // Overlapping area, use X position relative to screen center
            let localPoint = convert(touchPoint, from: nil)
            let middleX = bounds.width / 2
            newZone = localPoint.x < middleX ? .cancel : .toText
        } else {
            // Not in any button area
            newZone = .normal
        }
        
        if currentZone != newZone {
            currentZone = newZone
            showHapticFeedback()
            updateZoneUI(newZone)
        }
    }
    
    /// Enter text processing state (called when user releases in toText zone)
    public func enterTextProcessingState() {
        convertLocalVoiceToTextState = .processing
        
        // Hide normal UI (but keep bottom waveform visible with new styling)
        UIView.animate(withDuration: Layout.animationDuration) {
            self.leftButtonContainer.alpha = 0
            self.rightButtonContainer.alpha = 0
            self.centerHintLabel.alpha = 0
            
            // Change bottom waveform to gray background with black dots
            self.bottomWaveformBackgroundView.backgroundColor = Colors.grayBackground
            for bar in self.bottomWaveformBars {
                bar.backgroundColor = Colors.waveformBarDark
            }
        }
        
        // Move bubble to textProcessedContainer for proper keyboard handling
        if bubbleContainerView.superview != textProcessedContainer {
            bubbleContainerView.removeFromSuperview()
            textProcessedContainer.addSubview(bubbleContainerView)
            
            bubbleContainerView.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(Layout.paddingSide)
                make.trailing.equalToSuperview().offset(-Layout.paddingSide)
                make.bottom.equalTo(sendButtonContainer.snp.top).offset(-42)
                bubbleHeightConstraint = make.height.greaterThanOrEqualTo(Layout.minBubbleHeight + Layout.bubbleArrowHeight).constraint
            }
        }
        
        // Show bubble and text processed UI with animation
        bubbleContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        textProcessedContainer.alpha = 1
        waveformContainer.alpha = 0
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseOut], animations: {
            self.bubbleContainerView.alpha = 1
            self.bubbleContainerView.transform = .identity
        })
        
        // Add text view to first stage bubble container
        if textBubbleTextView.superview != bubbleContainerView {
            bubbleContainerView.addSubview(textBubbleTextView)
            textBubbleTextView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(12)
                make.leading.equalToSuperview().offset(12)
                make.trailing.equalToSuperview().offset(-12)
                make.bottom.equalToSuperview().offset(-12 - 6) // Subtract arrow height
            }
        }
        textBubbleTextView.alpha = 0  // Will show after conversion
        textBubbleTextView.backgroundColor = .clear
        
        // Add loading indicator to bubble (centered vertically, left-aligned)
        if bubbleLoadingIndicator.superview != bubbleContainerView {
            bubbleContainerView.addSubview(bubbleLoadingIndicator)
            bubbleLoadingIndicator.snp.makeConstraints { make in
                make.centerY.equalToSuperview().offset(-Layout.bubbleArrowHeight / 2)
                make.leading.equalToSuperview().offset(16)
                make.width.equalTo(36)
                make.height.equalTo(20)
            }
        }
        bubbleLoadingIndicator.isHidden = false
        bubbleLoadingIndicator.startAnimating()
        
        // Ensure text view is above background layer
        bubbleContainerView.bringSubviewToFront(textBubbleTextView)
        bubbleContainerView.bringSubviewToFront(bubbleLoadingIndicator)
        
        // Show buttons immediately (always visible)
        cancelButtonContainer.alpha = 1
        sendVoiceButtonContainer.alpha = 1
        
        // Show circular loading button with text (no spinner)
        sendButtonLoadingBackgroundView.alpha = 1
        sendButtonLoadingLabel.alpha = 1 // Show loading text
        sendButtonView.alpha = 0
        
        
    }
    
    /// Set conversion state and update UI accordingly
    public func setConvertLocalVoiceToTextState(_ state: ConvertLocalVoiceToTextState, text: String = "", error: Error? = nil) {
        convertLocalVoiceToTextState = state
        
        switch state {
        case .idle:
            // Do nothing, initial state
            break
            
        case .processing:
            // Already handled in enterTextProcessingState()
            break
            
        case .success:
            handleConversionSuccess(text: text)
            
        case .failure:
            handleConversionFailure(error: error)
        }
    }
    
    /// Handle successful text conversion
    private func handleConversionSuccess(text: String) {
        // Hide bubble loading indicator
        bubbleLoadingIndicator.stopAnimating()
        bubbleLoadingIndicator.isHidden = true
        
        convertedText = text
        textBubbleTextView.text = text
        textBubbleTextView.isEditable = true
        textBubbleTextView.isUserInteractionEnabled = true
        textBubbleTextView.textAlignment = .left
        
        updateBubbleHeightForText(text)
        
        // Transition from light blue loading to blue enabled send button
        UIView.animate(withDuration: 0.3) {
            // Hide circular loading
            self.sendButtonLoadingBackgroundView.alpha = 0
            self.sendButtonLoadingLabel.alpha = 0
            
            // Show text view
            self.textBubbleTextView.alpha = 1
            
            // Enable and show send button with blue background
            self.sendButtonView.alpha = 1
            self.sendButtonView.backgroundColor = self.bubbleNormalColor
            self.sendButtonView.isUserInteractionEnabled = true
            self.sendButtonLabel.textColor = .white
        }
    }
    
    /// Check if error code indicates network error or IM SDK not logged in
    private func isNetworkOrLoginError(code: Int32) -> Bool {
        let errorCodes: Set<Int32> = [6008, 6013, 6014, 6015]
        return errorCodes.contains(code)
    }
    
    /// Handle text conversion failure
    private func handleConversionFailure(error: Error? = nil) {
        bubbleLoadingIndicator.stopAnimating()
        bubbleLoadingIndicator.isHidden = true
        
        let errorMessage: String
        if let error = error {
            var errorCode: Int32 = 0
            
            // Extract error code from TUIAIMediaProcessError
            if let aiError = error as? TUIAIMediaProcessError {
                errorCode = aiError.code
            }
            
            // Classify error by code
            if isNetworkOrLoginError(code: errorCode) {
                errorMessage = TUISwift.timCommonLocalizableString("TUIKitInputNoNetworkOrNotLoggedIn")
            } else {
                errorMessage = TUISwift.timCommonLocalizableString("TUIKitInputNoTextRecognized")
            }
        } else {
            // No error object, use default message
            errorMessage = TUISwift.timCommonLocalizableString("TUIKitInputNoTextRecognized")
        }
        
        convertedText = errorMessage
        textBubbleTextView.text = convertedText
        textBubbleTextView.isEditable = false
        textBubbleTextView.textAlignment = .center
        textBubbleTextView.textColor = .white
        
        // Calculate vertical padding to center text in bubble
        let font = textBubbleTextView.font ?? UIFont.systemFont(ofSize: 16)
        let verticalPadding = max(0, (Layout.minBubbleHeight - font.lineHeight) / 2)
        textBubbleTextView.textContainerInset = UIEdgeInsets(top: verticalPadding, left: 0, bottom: verticalPadding, right: 0)
        
        // Change first stage bubble to red and narrow it
        UIView.animate(withDuration: 0.3) {
            self.sendButtonLoadingBackgroundView.alpha = 0
            self.sendButtonLoadingLabel.alpha = 0
            
            // Change bubble background to red
            self.bubbleBackgroundLayer.fillColor = Colors.errorRed.cgColor
            
            // Narrow the bubble
            self.bubbleLeadingConstraint?.update(offset: 60)
            self.bubbleTrailingConstraint?.update(offset: -60)
            self.bubbleHeightConstraint?.update(offset: Layout.minBubbleHeight + Layout.bubbleArrowHeight)
            
            // Show text view with error message
            self.textBubbleTextView.alpha = 1
            
            // Show send button in disabled state
            self.sendButtonView.alpha = 1
            self.sendButtonView.backgroundColor = Colors.disabledBlue
            self.sendButtonView.isUserInteractionEnabled = false
            self.sendButtonLabel.textColor = .white
            
            // Show overlay to allow dismissing by tapping blank area
            self.overlayView.alpha = 1
            self.overlayView.isUserInteractionEnabled = true
            
            self.layoutIfNeeded()
            self.updateBubbleShape(animated: false)
        }
    }
    
    /// Get current conversion state
    public func getConvertLocalVoiceToTextState() -> ConvertLocalVoiceToTextState {
        return convertLocalVoiceToTextState
    }
    
    private func updateBubbleHeightForText(_ text: String) {
        let padding = Layout.bubbleTextPadding * 2
        let availableWidth = TUISwift.screen_Width() - Layout.paddingSide * 2 - padding
        
        let textSize = (text as NSString).boundingRect(
            with: CGSize(width: availableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .regular)],
            context: nil
        )
        
        let requiredHeight = textSize.height + padding
        let contentHeight = max(Layout.minBubbleHeight, min(Layout.maxBubbleHeight, requiredHeight))
        let totalHeight = contentHeight + Layout.bubbleArrowHeight
        
        let shouldEnableScroll = requiredHeight > Layout.maxBubbleHeight
        if textBubbleTextView.isScrollEnabled != shouldEnableScroll {
            textBubbleTextView.isScrollEnabled = shouldEnableScroll
        }
        
        let oldPath = bubbleBackgroundLayer.path
        let currentWidth = bubbleContainerView.bounds.width
        let arrowCenterX = calculateArrowCenterX(for: currentWidth)
        let newPath = createBubblePath(width: currentWidth, height: contentHeight, arrowX: arrowCenterX)
        
        bubbleHeightConstraint?.update(offset: totalHeight)
        isAnimatingTextHeight = true
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(Layout.animationDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        CATransaction.setCompletionBlock { self.isAnimatingTextHeight = false }
        
        if let oldPath = oldPath {
            let pathAnimation = CABasicAnimation(keyPath: "path")
            pathAnimation.fromValue = oldPath
            pathAnimation.toValue = newPath
            pathAnimation.duration = Layout.animationDuration
            pathAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            bubbleBackgroundLayer.add(pathAnimation, forKey: "pathAnimation")
        }
        
        bubbleBackgroundLayer.path = newPath
        CATransaction.commit()
        
        UIView.animate(withDuration: Layout.animationDuration, delay: 0, options: [.curveEaseOut], animations: {
            self.layoutIfNeeded()
        })
    }
    
    /// Exit text processing state (back to normal)
    public func exitTextProcessingState() {
        // Move bubble back to main view
        if bubbleContainerView.superview == textProcessedContainer {
            let offset = Layout.paddingSide + Layout.buttonCircleSize / 2 + 10
            
            bubbleContainerView.removeFromSuperview()
            addSubview(bubbleContainerView)
            
            bubbleContainerView.snp.remakeConstraints { make in
                make.centerY.equalToSuperview()
                bubbleHeightConstraint = make.height.equalTo(Layout.minBubbleHeight + Layout.bubbleArrowHeight).constraint
                bubbleLeadingConstraint = make.leading.equalToSuperview().offset(offset).constraint
                bubbleTrailingConstraint = make.trailing.equalToSuperview().offset(-offset).constraint
            }
        }
        
        UIView.animate(withDuration: Layout.animationDuration) {
            self.textProcessedContainer.alpha = 0
            self.textBubbleTextView.alpha = 0
            self.bubbleContainerView.alpha = 0
            self.waveformContainer.alpha = 1
            self.leftButtonContainer.alpha = 1
            self.rightButtonContainer.alpha = 1
            self.centerHintLabel.alpha = 1
            self.bottomWaveformContainer.alpha = 1
            
            // Hide overlay
            self.overlayView.alpha = 0
            self.overlayView.isUserInteractionEnabled = false
            
            // Restore bottom waveform to blue background with white bars
            self.bottomWaveformBackgroundView.alpha = 1
            self.bottomWaveformBackgroundView.backgroundColor = self.bubbleNormalColor
            for bar in self.bottomWaveformBars {
                bar.backgroundColor = .white
            }
            
            self.layoutIfNeeded()
        }
    }
    
    /// Get converted text (from editable text view)
    public func getConvertedText() -> String {
        textBubbleTextView.text ?? convertedText
    }
    

    /// Update UI based on zone 
    private func updateZoneUI(_ zone: RecordZone) {
        let screenWidth = TUISwift.screen_Width()
        let paddingSide = Layout.paddingSide
        let bubbleHeight = Layout.minBubbleHeight + Layout.bubbleArrowHeight
        
        var leftMargin: CGFloat
        var rightMargin: CGFloat
        var bubbleColor: UIColor
        
        switch zone {
        case .cancel:
            leftMargin = paddingSide
            rightMargin = -(screenWidth - paddingSide - 200)
            bubbleColor = Colors.errorRed
            
            animateIconButton(leftButtonView, leftButtonIconView, isFocus: true, buttonType: .cancel)
            
            animateButton(rightButtonView, rightButtonLabel, isFocus: false, text: TUISwift.timCommonLocalizableString("TUIKitInputConvertToText"), buttonType: .toText)
            centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputReleaseToCancel")
            updateBottomWaveformBackgroundColor(Colors.errorRed)
            
        case .normal:
            leftMargin = paddingSide + Layout.buttonCircleSize / 2 + 10
            rightMargin = -(paddingSide + Layout.buttonCircleSize / 2 + 10)
            bubbleColor = bubbleNormalColor
            
            animateIconButton(leftButtonView, leftButtonIconView, isFocus: false, buttonType: .cancel)
            animateButton(rightButtonView, rightButtonLabel, isFocus: false, text: TUISwift.timCommonLocalizableString("TUIKitInputConvertToText"), buttonType: .toText)
            centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputReleaseToSend")
            updateBottomWaveformBackgroundColor(bubbleNormalColor)
            
        case .toText:
            leftMargin = paddingSide
            rightMargin = -paddingSide
            bubbleColor = bubbleNormalColor
            
            animateIconButton(leftButtonView, leftButtonIconView, isFocus: false, buttonType: .cancel)
            animateButton(rightButtonView, rightButtonLabel, isFocus: true, text: TUISwift.timCommonLocalizableString("TUIKitInputConvertToText"), buttonType: .toText)
            centerHintLabel.text = TUISwift.timCommonLocalizableString("TUIKitInputReleaseToConvertToText")
            updateBottomWaveformBackgroundColor(bubbleNormalColor)
        }
        
        centerHintLabel.alpha = 1
        
        // Update constraints
        bubbleLeadingConstraint?.update(offset: leftMargin)
        bubbleTrailingConstraint?.update(offset: rightMargin)
        bubbleHeightConstraint?.update(offset: bubbleHeight)
        
        isAnimatingBubbleShape = true
        
        // Animate fill color
        CATransaction.begin()
        CATransaction.setAnimationDuration(Layout.animationDuration)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        
        let colorAnimation = CABasicAnimation(keyPath: "fillColor")
        colorAnimation.fromValue = bubbleBackgroundLayer.fillColor
        colorAnimation.toValue = bubbleColor.cgColor
        colorAnimation.duration = Layout.animationDuration
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        bubbleBackgroundLayer.add(colorAnimation, forKey: "fillColorAnimation")
        bubbleBackgroundLayer.fillColor = bubbleColor.cgColor
        
        CATransaction.commit()
        
        // Animate layout changes
        UIView.animate(withDuration: Layout.animationDuration,
                       delay: 0,
                       options: [.curveEaseInOut, .allowUserInteraction],
                       animations: {
            self.layoutIfNeeded()
            self.bubbleContainerView.layoutIfNeeded()
        }, completion: { _ in
            self.isAnimatingBubbleShape = false
        })
        
        animateBubbleShape(to: zone)
    }
    
    /// Animate bubble shape change using CAAnimation
    private func animateBubbleShape(to zone: RecordZone) {
        DispatchQueue.main.async {
            let targetWidth = self.bubbleContainerView.bounds.width
            let arrowCenterX = self.calculateArrowCenterX(for: targetWidth, zone: zone)
            let targetPath = self.createBubblePath(width: targetWidth, height: Layout.minBubbleHeight, arrowX: arrowCenterX)
            
            if let oldPath = self.bubbleBackgroundLayer.path {
                let pathAnimation = CABasicAnimation(keyPath: "path")
                pathAnimation.fromValue = oldPath
                pathAnimation.toValue = targetPath
                pathAnimation.duration = Layout.animationDuration
                pathAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.bubbleBackgroundLayer.add(pathAnimation, forKey: "pathAnimation")
            }
            
            self.bubbleBackgroundLayer.path = targetPath
        }
    }
    
    /// Animate button - Large circle buttons (Figma design)
    private func animateButton(_ buttonView: UIView, _ label: UILabel, isFocus: Bool, text: String, buttonType: RecordZone = .normal) {
        // Circle buttons don't change size, only background color
        label.text = text
        
        let targetBackgroundColor: UIColor
        let targetTextColor: UIColor
        
        if isFocus {
            switch buttonType {
            case .cancel:
                targetBackgroundColor = Colors.errorRed
                targetTextColor = .white
            case .toText:
                targetBackgroundColor = bubbleNormalColor
                targetTextColor = .white
            case .normal:
                targetBackgroundColor = .white
                targetTextColor = .black
            }
        } else {
            targetBackgroundColor = Colors.grayBackground
            targetTextColor = Colors.darkText
        }
        
        UIView.animate(withDuration: Layout.animationDuration, delay: 0, options: [.curveEaseInOut], animations: {
            buttonView.backgroundColor = targetBackgroundColor
            label.textColor = targetTextColor
            buttonView.transform = isFocus ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
            self.layoutIfNeeded()
        })
    }
    
    /// Animate icon button - For cancel button with icon
    private func animateIconButton(_ buttonView: UIView, _ iconView: UIImageView, isFocus: Bool, buttonType: RecordZone = .normal) {
        let targetBackgroundColor: UIColor
        let targetIconColor: UIColor
        
        if isFocus {
            switch buttonType {
            case .cancel:
                targetBackgroundColor = Colors.errorRed
                targetIconColor = .white
            case .toText:
                targetBackgroundColor = bubbleNormalColor
                targetIconColor = .white
            case .normal:
                targetBackgroundColor = .white
                targetIconColor = .black
            }
        } else {
            targetBackgroundColor = Colors.grayBackground
            targetIconColor = Colors.darkText
        }
        
        UIView.animate(withDuration: Layout.animationDuration, delay: 0, options: [.curveEaseInOut], animations: {
            buttonView.backgroundColor = targetBackgroundColor
            iconView.tintColor = targetIconColor
            buttonView.transform = isFocus ? CGAffineTransform(scaleX: 1.05, y: 1.05) : .identity
            self.layoutIfNeeded()
        })
    }
    
    // MARK: - Keyboard Handling
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        let keyboardHeight = keyboardFrame.height
        
        // Move the entire view up by keyboard height
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve),
            animations: {
                self.transform = CGAffineTransform(translationX: 0, y: -keyboardHeight)
            }
        )
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt else {
            return
        }
        
        // Reset view position
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: UIView.AnimationOptions(rawValue: curve),
            animations: {
                self.transform = .identity
            }
        )
    }
    
    // MARK: - Custom Toast
    
    /// Show custom toast with Figma design style
    public func showCustomToast(_ message: String) {
        guard let parentView = self.superview else { return }
        
        // Remove existing toast if any
        parentView.subviews.filter { $0.tag == 9999 }.forEach { $0.removeFromSuperview() }
        
        // Create toast container
        let toastContainer = UIView()
        toastContainer.tag = 9999
        toastContainer.backgroundColor = .white
        toastContainer.layer.cornerRadius = 8
        toastContainer.clipsToBounds = true
        toastContainer.alpha = 0
        parentView.addSubview(toastContainer)
        
        // Create icon
        let iconView = UIImageView()
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        iconView.image = UIImage(systemName: "exclamationmark.circle.fill", withConfiguration: iconConfig)
        iconView.tintColor = Colors.errorRed
        iconView.contentMode = .scaleAspectFit
        toastContainer.addSubview(iconView)
        
        // Create toast label
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = UIColor(white: 0.2, alpha: 1.0)
        toastLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        toastLabel.textAlignment = .left
        toastLabel.numberOfLines = 0
        toastContainer.addSubview(toastLabel)
        
        // Calculate size
        let iconSize: CGFloat = 20
        let iconSpacing: CGFloat = 8
        let padding: CGFloat = 16
        let maxWidth = parentView.bounds.width - 100
        
        let textSize = (message as NSString).boundingRect(
            with: CGSize(width: maxWidth - iconSize - iconSpacing, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 16, weight: .regular)],
            context: nil
        )
        
        let containerWidth = min(textSize.width + iconSize + iconSpacing + padding * 2, maxWidth + padding * 2)
        let containerHeight = max(textSize.height, iconSize) + padding * 2
        
        // Position toast in center
        toastContainer.frame = CGRect(
            x: (parentView.bounds.width - containerWidth) / 2,
            y: (parentView.bounds.height - containerHeight) / 2,
            width: containerWidth,
            height: containerHeight
        )
        
        iconView.frame = CGRect(x: padding, y: (containerHeight - iconSize) / 2, width: iconSize, height: iconSize)
        toastLabel.frame = CGRect(
            x: padding + iconSize + iconSpacing,
            y: padding,
            width: containerWidth - padding * 2 - iconSize - iconSpacing,
            height: textSize.height
        )
        
        // Animate toast appearance
        UIView.animate(withDuration: 0.3) {
            toastContainer.alpha = 1
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                UIView.animate(withDuration: 0.3) {
                    toastContainer.alpha = 0
                } completion: { _ in
                    toastContainer.removeFromSuperview()
                }
            }
        }
    }
    
    /// Create custom voice wave icon (speaker with sound waves)
    private func createVoiceWaveIcon(color: UIColor) -> UIImage? {
        let size = CGSize(width: 20, height: 20)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        context.setFillColor(color.cgColor)
        
        // Path 1: Outermost wave
        let path1 = UIBezierPath()
        path1.move(to: CGPoint(x: 11.8427, y: 18.3046))
        path1.addCurve(to: CGPoint(x: 15, y: 9.99997), controlPoint1: CGPoint(x: 13.8068, y: 16.0966), controlPoint2: CGPoint(x: 15, y: 13.1876))
        path1.addCurve(to: CGPoint(x: 11.8427, y: 1.69533), controlPoint1: CGPoint(x: 15, y: 6.81232), controlPoint2: CGPoint(x: 13.8068, y: 3.90335))
        path1.addLine(to: CGPoint(x: 12.777, y: 0.864868))
        path1.addCurve(to: CGPoint(x: 16.25, y: 9.99997), controlPoint1: CGPoint(x: 14.9375, y: 3.29369), controlPoint2: CGPoint(x: 16.25, y: 6.49356))
        path1.addCurve(to: CGPoint(x: 12.777, y: 19.1351), controlPoint1: CGPoint(x: 16.25, y: 13.5064), controlPoint2: CGPoint(x: 14.9375, y: 16.7062))
        path1.close()
        path1.fill()
        
        // Path 2: Middle wave
        let path2 = UIBezierPath()
        path2.move(to: CGPoint(x: 9.97417, y: 3.35626))
        path2.addCurve(to: CGPoint(x: 12.5, y: 9.99997), controlPoint1: CGPoint(x: 11.5455, y: 5.12268), controlPoint2: CGPoint(x: 12.5, y: 7.44985))
        path2.addCurve(to: CGPoint(x: 9.97417, y: 16.6437), controlPoint1: CGPoint(x: 12.5, y: 12.5501), controlPoint2: CGPoint(x: 11.5455, y: 14.8773))
        path2.addLine(to: CGPoint(x: 9.0399, y: 15.8132))
        path2.addCurve(to: CGPoint(x: 11.25, y: 9.99997), controlPoint1: CGPoint(x: 10.4148, y: 14.2676), controlPoint2: CGPoint(x: 11.25, y: 12.2313))
        path2.addCurve(to: CGPoint(x: 9.0399, y: 4.18672), controlPoint1: CGPoint(x: 11.25, y: 7.76862), controlPoint2: CGPoint(x: 10.4148, y: 5.73234))
        path2.close()
        path2.fill()
        
        // Path 3: Inner wave
        let path3 = UIBezierPath()
        path3.move(to: CGPoint(x: 7.17136, y: 14.1523))
        path3.addCurve(to: CGPoint(x: 8.75, y: 9.99997), controlPoint1: CGPoint(x: 8.15341, y: 13.0483), controlPoint2: CGPoint(x: 8.75, y: 11.5938))
        path3.addCurve(to: CGPoint(x: 7.17136, y: 5.84765), controlPoint1: CGPoint(x: 8.75, y: 8.40615), controlPoint2: CGPoint(x: 8.15341, y: 6.95166))
        path3.addLine(to: CGPoint(x: 6.23709, y: 6.67811))
        path3.addCurve(to: CGPoint(x: 7.5, y: 9.99997), controlPoint1: CGPoint(x: 7.02273, y: 7.56132), controlPoint2: CGPoint(x: 7.5, y: 8.72491))
        path3.addCurve(to: CGPoint(x: 6.23709, y: 13.3218), controlPoint1: CGPoint(x: 7.5, y: 11.275), controlPoint2: CGPoint(x: 7.02273, y: 12.4386))
        path3.close()
        path3.fill()
        
        // Path 4: Speaker cone
        let path4 = UIBezierPath()
        path4.move(to: CGPoint(x: 4.36854, y: 11.6609))
        path4.addCurve(to: CGPoint(x: 5, y: 9.99997), controlPoint1: CGPoint(x: 4.76136, y: 11.2193), controlPoint2: CGPoint(x: 5, y: 10.6375))
        path4.addCurve(to: CGPoint(x: 4.36854, y: 8.33904), controlPoint1: CGPoint(x: 5, y: 9.36244), controlPoint2: CGPoint(x: 4.76136, y: 8.78065))
        path4.addLine(to: CGPoint(x: 2.5, y: 9.99997))
        path4.close()
        path4.fill()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
}

// MARK: - UITextViewDelegate

extension TUIRecordView: UITextViewDelegate {
    public func textViewDidChange(_ textView: UITextView) {
        updateBubbleHeightForText(textView.text)
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - TUIBouncingDotsView

/// Custom bouncing dots loading animation view
/// Displays three dots that bounce up and down in sequence
public class TUIBouncingDotsView: UIView {
    
    // MARK: - Configuration
    
    private enum Config {
        static let dotCount: Int = 3
        static let dotSize: CGFloat = 6
        static let dotSpacing: CGFloat = 6
        static let bounceHeight: CGFloat = 6
        static let animationDuration: TimeInterval = 0.4
        static let delayBetweenDots: TimeInterval = 0.15
    }
    
    // MARK: - Properties
    
    private var dots: [UIView] = []
    private var isAnimating: Bool = false
    
    /// Dot color (default: white)
    public var dotColor: UIColor = .white {
        didSet {
            dots.forEach { $0.backgroundColor = dotColor }
        }
    }
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupDots()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupDots()
    }
    
    // MARK: - Setup
    
    private func setupDots() {
        backgroundColor = .clear
        
        for _ in 0..<Config.dotCount {
            let dot = UIView()
            dot.backgroundColor = dotColor
            dot.layer.cornerRadius = Config.dotSize / 2
            addSubview(dot)
            dots.append(dot)
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        layoutDots()
    }
    
    private func layoutDots() {
        let totalWidth = CGFloat(Config.dotCount) * Config.dotSize + CGFloat(Config.dotCount - 1) * Config.dotSpacing
        let startX = (bounds.width - totalWidth) / 2
        let centerY = bounds.height / 2
        
        for (index, dot) in dots.enumerated() {
            let x = startX + CGFloat(index) * (Config.dotSize + Config.dotSpacing)
            dot.frame = CGRect(
                x: x,
                y: centerY - Config.dotSize / 2,
                width: Config.dotSize,
                height: Config.dotSize
            )
        }
    }
    
    public override var intrinsicContentSize: CGSize {
        let width = CGFloat(Config.dotCount) * Config.dotSize + CGFloat(Config.dotCount - 1) * Config.dotSpacing
        let height = Config.dotSize + Config.bounceHeight * 2
        return CGSize(width: width, height: height)
    }
    
    // MARK: - Animation
    
    /// Start the bouncing animation
    public func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        animateDots()
    }
    
    /// Stop the bouncing animation
    public func stopAnimating() {
        isAnimating = false
        layer.removeAllAnimations()
        dots.forEach { dot in
            dot.layer.removeAllAnimations()
            dot.transform = .identity
        }
    }
    
    private func animateDots() {
        guard isAnimating else { return }
        
        for (index, dot) in dots.enumerated() {
            let delay = Double(index) * Config.delayBetweenDots
            
            UIView.animate(
                withDuration: Config.animationDuration,
                delay: delay,
                options: [.curveEaseInOut],
                animations: {
                    dot.transform = CGAffineTransform(translationX: 0, y: -Config.bounceHeight)
                },
                completion: { [weak self] _ in
                    UIView.animate(
                        withDuration: Config.animationDuration,
                        delay: 0,
                        options: [.curveEaseInOut],
                        animations: {
                            dot.transform = .identity
                        },
                        completion: { _ in
                            // Restart animation cycle after last dot completes
                            if index == Config.dotCount - 1 {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self?.animateDots()
                                }
                            }
                        }
                    )
                }
            )
        }
    }
}
