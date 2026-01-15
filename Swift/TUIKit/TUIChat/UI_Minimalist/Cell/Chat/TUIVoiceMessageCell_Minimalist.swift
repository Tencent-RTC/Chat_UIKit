import AVFoundation
import TIMCommon
import UIKit

class TUIVoiceMessageCell_Minimalist: TUIBubbleMessageCell_Minimalist {
    var voicePlay: UIImageView!
    var voiceAnimations: [UIImageView]!
    var duration: UILabel!
    var voiceReadPoint: UIImageView!
    var voiceData: TUIVoiceMessageCellData?
    private var isPlayingObservation: NSKeyValueObservation?
    private var currentTimeObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        voicePlay = UIImageView()
        voicePlay.image = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("voice_play"))
        bubbleView.addSubview(voicePlay)

        voiceAnimations = []
        for _ in 0 ..< 6 {
            let animation = UIImageView()
            animation.image = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("voice_play_animation"))
            bubbleView.addSubview(animation)
            voiceAnimations.append(animation)
        }

        duration = UILabel()
        duration.font = UIFont.boldSystemFont(ofSize: 14)
        duration.rtlAlignment = .trailing
        bubbleView.addSubview(duration)

        voiceReadPoint = UIImageView()
        voiceReadPoint.backgroundColor = .red
        voiceReadPoint.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
        voiceReadPoint.isHidden = true
        voiceReadPoint.layer.cornerRadius = voiceReadPoint.frame.size.width / 2
        voiceReadPoint.layer.masksToBounds = true
        bubbleView.addSubview(voiceReadPoint)

        bottomContainer = UIView()
        contentView.addSubview(bottomContainer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        for view in bottomContainer.subviews {
            view.removeFromSuperview()
        }

        isPlayingObservation?.invalidate()
        isPlayingObservation = nil
        currentTimeObservation?.invalidate()
        currentTimeObservation = nil
    }

    override func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        guard let voiceData = voiceData else { return }
        let param = ["TUICore_TUIChatExtension_BottomContainer_CellData": voiceData]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_MinimalistExtensionID", parentView: bottomContainer, param: param)
    }

    override func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIVoiceMessageCellData else { return }
        voiceData = data

        if data.duration > 0 {
            duration.text = String(format: "%d:%.2d", Int(data.duration) / 60, Int(data.duration) % 60)
        } else {
            duration.text = "0:01"
        }

        bottomContainer.isHidden = CGSizeEqualToSize(data.bottomContainerSize, CGSize.zero)

        // Show unread point only for incoming messages that haven't been played
        if voiceData?.direction == .incoming {
            voiceReadPoint.isHidden = (voiceData?.innerMessage?.localCustomInt ?? 0) != 0
        } else {
            voiceReadPoint.isHidden = true
        }

        isPlayingObservation = data.observe(\.isPlaying, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let isPlaying = change.newValue else { return }
            if isPlaying {
                self.startAnimating()
            } else {
                self.stopAnimating()
                if data.duration > 0 {
                    self.duration.text = String(format: "%d:%.2d", Int(data.duration) / 60, Int(data.duration) % 60)
                } else {
                    self.duration.text = "0:01"
                }
            }
        }

        currentTimeObservation = data.observe(\.currentTime, options: [.new, .initial]) { [weak self] _, _ in
            guard let self = self, data.isPlaying == true else { return }
            let min = Int(data.currentTime) / 60
            let sec = Int(data.currentTime) % 60
            self.duration.text = String(format: "%d:%.2d", min, sec)
        }

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    override class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override func updateConstraints() {
        super.updateConstraints()

        voicePlay.snp.remakeConstraints { make in
            make.top.equalTo(12)
            make.leading.equalTo(TUISwift.kScale390(16))
            make.width.equalTo(11)
            make.height.equalTo(13)
        }

        let animationStartX: CGFloat = TUISwift.kScale390(35)
        for (index, animation) in voiceAnimations.enumerated() {
            animation.snp.remakeConstraints { make in
                make.leading.equalTo(bubbleView).offset(animationStartX + TUISwift.kScale390(25) * CGFloat(index))
                make.top.equalTo(bubbleView).offset(voiceData?.voiceTop ?? 0)
                make.width.height.equalTo(voiceData?.voiceHeight ?? 0)
            }
        }

        duration.snp.remakeConstraints { make in
            make.width.greaterThanOrEqualTo(TUISwift.kScale390(34))
            make.height.greaterThanOrEqualTo(17)
            make.top.equalTo((voiceData?.voiceTop ?? 0) + 2)
            make.trailing.equalTo(container).offset(-TUISwift.kScale390(14))
        }

        if voiceData?.direction == .outgoing {
            voiceReadPoint.isHidden = true
        } else {
            voiceReadPoint.snp.remakeConstraints { make in
                make.top.equalTo(bubbleView)
                make.leading.equalTo(bubbleView.snp.trailing).offset(1)
                make.size.equalTo(CGSize(width: 5, height: 5))
            }
        }
        layoutBottomContainer()
    }

    private func layoutBottomContainer() {
        if CGSizeEqualToSize(voiceData?.bottomContainerSize ?? CGSize.zero, CGSize.zero) {
            return
        }

        if let size = voiceData?.bottomContainerSize {
            bottomContainer.snp.remakeConstraints { make in
                if voiceData?.direction == .incoming {
                    make.leading.equalTo(container)
                } else {
                    make.trailing.equalTo(container)
                }
                make.top.equalTo(container.snp.bottom).offset((self.messageData?.messageContainerAppendSize.height ?? 0) + 6)
                make.size.equalTo(size)
            }
        }

        if !messageModifyRepliesButton.isHidden {
            if let lastAvatarImageView = replyAvatarImageViews.last {
                messageModifyRepliesButton.snp.remakeConstraints { make in
                    if voiceData?.direction == .incoming {
                        make.leading.equalTo(lastAvatarImageView.snp.trailing)
                    } else {
                        make.trailing.equalTo(container)
                    }
                    make.top.equalTo(bottomContainer.snp.bottom)
                    make.size.equalTo(CGSize(width: messageModifyRepliesButton.frame.size.width + 10, height: 30))
                }
            }
        }
    }

    private func startAnimating() {
        voicePlay.image = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("voice_pause"))
    }

    private func stopAnimating() {
        voicePlay.image = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist("voice_play"))
    }

    // MARK: - TUIMessageCellProtocol

    override class func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat {
        var height = super.getHeight(data, withWidth: width)
        if data.bottomContainerSize.height > 0 {
            height += data.bottomContainerSize.height + TUISwift.kScale375(6)
        }
        return height
    }

    override class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let voiceCellData = data as? TUIVoiceMessageCellData else {
            assertionFailure("data must be kind of TUIVoiceMessageCellData")
            return CGSize.zero
        }
        return CGSizeMake((voiceCellData.voiceHeight + TUISwift.kScale390(5)) * 6 + TUISwift.kScale390(82),
                          voiceCellData.voiceHeight + voiceCellData.voiceTop * 3 + voiceCellData.msgStatusSize.height)
    }
}
