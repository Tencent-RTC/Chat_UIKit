import AVFoundation
import TIMCommon
import UIKit

class TUIVoiceMessageCell: TUIBubbleMessageCell {
    var voice: UIImageView = {
        let imageView = UIImageView()
        imageView.animationDuration = 1
        return imageView
    }()

    var duration: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 12)
        return label
    }()

    var voiceReadPoint: UIImageView = {
        let imageView = UIImageView()
        imageView.backgroundColor = .red
        imageView.frame = CGRect(x: 0, y: 0, width: 5, height: 5)
        imageView.isHidden = true
        imageView.layer.cornerRadius = imageView.frame.size.width / 2
        imageView.layer.masksToBounds = true
        return imageView
    }()

    var voiceData: TUIVoiceMessageCellData?
    private var isPlayingObservation: NSKeyValueObservation?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(voice)
        bubbleView.addSubview(duration)

        bottomContainer = UIView()
        contentView.addSubview(bottomContainer)

        bubbleView.addSubview(voiceReadPoint)
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
    }

    override func notifyBottomContainerReady(of cellData: TUIMessageCellData?) {
        guard let voiceData = voiceData else { return }
        let param = ["TUICore_TUIChatExtension_BottomContainer_CellData": voiceData]
        TUICore.raiseExtension("TUICore_TUIChatExtension_BottomContainer_ClassicExtensionID", parentView: bottomContainer, param: param)
    }

    override func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let data = data as? TUIVoiceMessageCellData else { return }
        voiceData = data

        bottomContainer.isHidden = data.bottomContainerSize == .zero

        if data.duration > 0 {
            duration.text = "\(data.duration)\""
        } else {
            duration.text = "1\""
        }

        voice.image = data.voiceImage
        voice.animationImages = data.voiceAnimationImages
        let hasRiskContent = messageData?.innerMessage?.hasRiskContent ?? false

        if hasRiskContent {
            securityStrikeView.textLabel.text = TUISwift.timCommonLocalizableString("TUIKitMessageTypeSecurityStrikeVoice")
        }

        // Show unread point only for incoming messages that haven't been played
        if voiceData?.direction == .incoming {
            voiceReadPoint.isHidden = (voiceData?.innerMessage?.localCustomInt ?? 0) != 0
        } else {
            voiceReadPoint.isHidden = true
        }

        isPlayingObservation = voiceData?.observe(\.isPlaying, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let isPlaying = change.newValue else { return }
            if isPlaying {
                voice.startAnimating()
            } else {
                voice.stopAnimating()
            }
        }

        applyStyleFromDirection(data.direction)

        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }

    func applyStyleFromDirection(_ direction: TMsgDirection) {
        if direction == .incoming {
            duration.rtlAlignment = .leading
            duration.textColor = TUISwift.tuiChatDynamicColor("chat_voice_message_recv_duration_time_color", defaultColor: "#000000")
        } else {
            duration.rtlAlignment = .trailing
            duration.textColor = TUISwift.tuiChatDynamicColor("chat_voice_message_send_duration_time_color", defaultColor: "#000000")
        }
    }

    override class var requiresConstraintBasedLayout: Bool {
        return true
    }

    override func updateConstraints() {
        super.updateConstraints()

        voice.sizeToFit()
        voice.snp.remakeConstraints { make in
            make.top.equalTo(voiceData?.voiceTop ?? 0)
            make.width.height.equalTo(voiceData?.voiceHeight ?? 0)
            if voiceData?.direction == .outgoing {
                make.trailing.equalTo(-(voiceData?.cellLayout?.bubbleInsets.right ?? 0))
            } else {
                make.leading.equalTo(voiceData?.cellLayout?.bubbleInsets.left ?? 0)
            }
        }

        duration.snp.remakeConstraints { make in
            make.width.greaterThanOrEqualTo(10)
            make.height.greaterThanOrEqualTo(33)
            make.centerY.equalTo(voice)
            if voiceData?.direction == .outgoing {
                make.trailing.equalTo(voice.snp.leading).offset(-5)
            } else {
                make.leading.equalTo(voice.snp.trailing).offset(5)
            }
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

        let hasRiskContent = messageData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            securityStrikeView.snp.remakeConstraints { make in
                make.top.equalTo(voice.snp.bottom)
                make.width.equalTo(bubbleView)
                make.bottom.equalTo(container).offset(-(messageData?.messageContainerAppendSize.height ?? 0))
            }
        }

        layoutBottomContainer()
    }

    private func layoutBottomContainer() {
        let isBottomContainerSizeZero = CGSizeEqualToSize(voiceData?.bottomContainerSize ?? CGSize.zero, CGSize.zero)
        if !isBottomContainerSizeZero {
            if let size = voiceData?.bottomContainerSize {
                bottomContainer.snp.remakeConstraints { make in
                    if voiceData?.direction == .incoming {
                        make.leading.equalTo(container)
                    } else {
                        make.trailing.equalTo(container)
                    }
                    make.top.equalTo(container.snp.bottom).offset(6)
                    make.size.equalTo(size)
                }
            }
        }
        let topView = !isBottomContainerSizeZero ? bottomContainer : container
        if !messageModifyRepliesButton.isHidden {
            messageModifyRepliesButton.snp.remakeConstraints { make in
                if voiceData?.direction == .incoming {
                    make.leading.equalTo(container)
                } else {
                    make.trailing.equalTo(container)
                }
                make.top.equalTo(topView.snp.bottom).priority(100)
                make.size.equalTo(CGSize(width: messageModifyRepliesButton.frame.size.width + 10, height: 30))
            }
        }
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
        guard let voiceCellData = data as? TUIVoiceMessageCellData else { return .zero }

        var bubbleWidth = CGFloat(TVoiceMessageCell_Back_Width_Min) + CGFloat(voiceCellData.duration) / TVoiceMessageCell_Max_Duration * TUISwift.screen_Width()
        if bubbleWidth > TUISwift.tVoiceMessageCell_Back_Width_Max() {
            bubbleWidth = TUISwift.tVoiceMessageCell_Back_Width_Max()
        }

        var bubbleHeight = TUISwift.tVoiceMessageCell_Duration_Size().height
        if voiceCellData.direction == .incoming {
            bubbleWidth = max(bubbleWidth, (TUIBubbleMessageCell.incommingBubble?.size.width ?? 0))
            bubbleHeight = (voiceCellData.voiceImage?.size.height ?? 0) + 2 * voiceCellData.voiceTop
        } else {
            bubbleWidth = max(bubbleWidth, (TUIBubbleMessageCell.outgoingBubble?.size.width ?? 0))
            bubbleHeight = (voiceCellData.voiceImage?.size.height ?? 0) + 2 * voiceCellData.voiceTop
        }

        var width = bubbleWidth + TUISwift.tVoiceMessageCell_Duration_Size().width
        var height = bubbleHeight

        let hasRiskContent = voiceCellData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            width = max(width, 200)
            height += kTUISecurityStrikeViewTopLineMargin
            height += CGFloat(kTUISecurityStrikeViewTopLineToBottom)
        }

        return CGSize(width: width, height: height)
    }
}
