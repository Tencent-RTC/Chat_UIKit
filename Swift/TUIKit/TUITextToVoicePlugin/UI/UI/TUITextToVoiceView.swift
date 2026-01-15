import AVFoundation
import SnapKit
import TIMCommon
import TUIChat
import TUICore
import UIKit

/// View for text-to-voice playback control displayed above text message bubble
/// This view is a pure UI component that:
/// - Displays play/pause icon and duration
/// - Shows unread dot for unplayed messages
/// - Listens to playback state changes via notifications
/// - Delegates actual playback control to TUITextToVoiceDataProvider
class TUITextToVoiceView: UIView {
    
    // MARK: - UI Components
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.tui_color(withHex: "#F9FAFC")
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.tui_color(withHex: "#D1D4DE").cgColor
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()
    
    private lazy var playIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        imageView.image = UIImage(systemName: "play.fill", withConfiguration: config)
        imageView.tintColor = UIColor.tui_color(withHex: "#161616")
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.tui_color(withHex: "#161616")
        label.textAlignment = .left
        return label
    }()
    
    private lazy var playButton: UIButton = {
        let button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(onPlayButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var unreadDot: UIView = {
        let dot = UIView()
        dot.backgroundColor = .red
        dot.layer.cornerRadius = 2.5
        dot.layer.masksToBounds = true
        dot.isHidden = true
        return dot
    }()
    
    // MARK: - Properties
    
    /// Cached message ID - immutable after init to avoid cell reuse issues
    private let msgID: String
    
    /// Weak reference to message for data access
    private weak var message: V2TIMMessage?
    
    /// Current playing state (updated via notifications)
    private var isPlaying: Bool = false
    
    /// Audio duration
    private var duration: TimeInterval = 0
    
    // MARK: - Initialization
    
    init?(cellData: TUIMessageCellData) {
        guard let message = cellData.innerMessage,
              let msgID = message.msgID,
              TUITextToVoiceDataProvider.getTextToVoiceStatus(message) == .shown
        else {
            return nil
        }
        
        self.msgID = msgID
        self.message = message
        self.duration = TUITextToVoiceDataProvider.getTextToVoiceDuration(message)
        
        super.init(frame: .zero)
        
        setupViews()
        setupNotifications()
        refreshUI()
    }
    
    override init(frame: CGRect) {
        fatalError("Use init(cellData:) instead")
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        addSubview(containerView)
        containerView.addSubview(playIcon)
        containerView.addSubview(durationLabel)
        containerView.addSubview(playButton)
        containerView.addSubview(unreadDot)
        
        durationLabel.text = Self.formatDuration(duration)
    }
    
    private func setupNotifications() {
        // Listen for playback state changes from TUITextToVoiceDataProvider
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onPlaybackStateChanged(_:)),
            name: NSNotification.Name("TUITextToVoicePlaybackStateChanged"),
            object: nil
        )
    }
    
    private func refreshUI() {
        // Check current playing state
        isPlaying = TUITextToVoiceDataProvider.shared.isPlaying(msgID: msgID)
        updatePlayIcon()
        
        // Check if already played
        if let message = message {
            unreadDot.isHidden = TUITextToVoiceDataProvider.isTextToVoicePlayed(message)
        }
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let iconSize: CGFloat = 10
        let containerHeight: CGFloat = 24
        let paddingTop: CGFloat = 2
        let paddingLeft: CGFloat = 6
        let paddingRight: CGFloat = 6
        let gap: CGFloat = 4
        
        let durationText = durationLabel.text ?? ""
        let textWidth = (durationText as NSString).size(withAttributes: [.font: durationLabel.font!]).width
        let containerWidth = paddingLeft + iconSize + gap + ceil(textWidth) + paddingRight
        
        containerView.frame = CGRect(x: 0, y: 0, width: containerWidth, height: containerHeight)
        
        let contentHeight = containerHeight - paddingTop * 2
        playIcon.frame = CGRect(
            x: paddingLeft,
            y: paddingTop + (contentHeight - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        
        durationLabel.frame = CGRect(
            x: playIcon.frame.maxX + gap,
            y: paddingTop,
            width: containerWidth - playIcon.frame.maxX - gap - paddingRight,
            height: contentHeight
        )
        
        playButton.frame = containerView.bounds
        
        let dotSize: CGFloat = 5
        unreadDot.frame = CGRect(
            x: containerWidth - dotSize - 2,
            y: 2,
            width: dotSize,
            height: dotSize
        )
        
        frame = CGRect(x: frame.origin.x, y: frame.origin.y, width: containerWidth, height: containerHeight)
    }
    
    override var intrinsicContentSize: CGSize {
        let iconSize: CGFloat = 10
        let containerHeight: CGFloat = 24
        let paddingLeft: CGFloat = 6
        let paddingRight: CGFloat = 6
        let gap: CGFloat = 4
        
        let durationText = durationLabel.text ?? ""
        let textWidth = (durationText as NSString).size(withAttributes: [.font: durationLabel.font!]).width
        let containerWidth = paddingLeft + iconSize + gap + ceil(textWidth) + paddingRight
        
        return CGSize(width: containerWidth, height: containerHeight)
    }
    
    // MARK: - Actions
    
    @objc private func onPlayButtonTapped() {
        guard let message = message else { return }
        
        if isPlaying {
            // Stop current playback
            TUITextToVoiceDataProvider.shared.stopCurrentAudio()
        } else {
            // Start playback - DataProvider will send notifications to update UI
            TUITextToVoiceDataProvider.shared.playAudio(for: message) { _ in
                // State callback is handled, but UI updates come via notifications
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func onPlaybackStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let notificationMsgID = userInfo["msgID"] as? String,
              let playing = userInfo["isPlaying"] as? Bool
        else { return }
                
        guard notificationMsgID == self.msgID else { return }
        
        isPlaying = playing
        updatePlayIcon()
        
        // Hide unread dot when playback starts
        if playing {
            unreadDot.isHidden = true
        }
    }
    
    // MARK: - UI Updates
    
    private func updatePlayIcon() {
        let config = UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)
        let iconName = isPlaying ? "pause.fill" : "play.fill"
        playIcon.image = UIImage(systemName: iconName, withConfiguration: config)
    }
    
    // MARK: - Static Helpers
    
    private class func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = max(1, Int(ceil(duration)))
        if totalSeconds >= 60 {
            let minutes = totalSeconds / 60
            let seconds = totalSeconds % 60
            return String(format: "%d'%02d\"", minutes, seconds)
        } else {
            return String(format: "%d\"", totalSeconds)
        }
    }
    
    class func getViewSize(for message: V2TIMMessage) -> CGSize {
        let status = TUITextToVoiceDataProvider.getTextToVoiceStatus(message)
        if status != .shown {
            return .zero
        }
        
        let duration = TUITextToVoiceDataProvider.getTextToVoiceDuration(message)
        let durationText = formatDuration(duration)
        
        let iconSize: CGFloat = 10
        let containerHeight: CGFloat = 24
        let paddingLeft: CGFloat = 6
        let paddingRight: CGFloat = 6
        let gap: CGFloat = 4
        
        let textWidth = (durationText as NSString).size(withAttributes: [.font: UIFont.systemFont(ofSize: 12)]).width
        let containerWidth = paddingLeft + iconSize + gap + ceil(textWidth) + paddingRight
        
        return CGSize(width: containerWidth, height: containerHeight)
    }
}
