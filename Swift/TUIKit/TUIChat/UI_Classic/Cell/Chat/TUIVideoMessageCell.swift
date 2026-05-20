import TIMCommon
import UIKit

class TUIVideoMessageCell: TUIBubbleMessageCell, TUIMessageProgressManagerDelegate {
    var videoData: TUIVideoMessageCellData?
    private var videoTranscodingObservation: NSKeyValueObservation?
    private var thumbImageObservation: NSKeyValueObservation?
    private var thumbProgressObservation: NSKeyValueObservation?
    private var uploadProgressObservation: NSKeyValueObservation?
    private var videoProgressObservation: NSKeyValueObservation?
    
    lazy var downloadImage: UIImageView = {
        let imageView = UIImageView(frame: CGRect(x: 0, y: 0, width: TUISwift.tVideoMessageCell_Play_Size().width, height: TUISwift.tVideoMessageCell_Play_Size().height))
        imageView.contentMode = .scaleAspectFit
        imageView.image = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("download"))
        imageView.isHidden = true
        thumb.addSubview(imageView)
        return imageView
    }()

    lazy var duration: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12)
        thumb.addSubview(label)
        return label
    }()

    lazy var thumb: UIImageView = {
        let image = UIImageView()
        image.layer.cornerRadius = 5.0
        image.layer.masksToBounds = true
        image.contentMode = .scaleAspectFit
        image.backgroundColor = .clear
        image.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return image
    }()

    lazy var play: UIImageView = {
        let image = UIImageView(frame: CGRect(x: 0, y: 0, width: TUISwift.tVideoMessageCell_Play_Size().width, height: TUISwift.tVideoMessageCell_Play_Size().height))
        image.contentMode = .scaleAspectFit
        image.image = TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath("play_normal"))
        return image
    }()

    lazy var animateCircleView: TUICircleLoadingView = {
        let view = TUICircleLoadingView(frame: CGRectMake(0, 0, TUISwift.kScale390(40), TUISwift.kScale390(40)))
        view.progress = 0
        return view
    }()

    lazy var progress: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 15)
        label.textAlignment = .center
        label.layer.cornerRadius = 5.0
        label.isHidden = true
        label.backgroundColor = TUISwift.tVideoMessageCell_Progress_Color()
        label.layer.masksToBounds = true
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return label
    }()
                                        
    lazy var animateHighlightView: UIView? = {
        let view = UIView()
        view.backgroundColor = .orange
        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        videoTranscodingObservation?.invalidate()
        videoTranscodingObservation = nil
        thumbImageObservation?.invalidate()
        thumbImageObservation = nil
        thumbProgressObservation?.invalidate()
        thumbProgressObservation = nil
        uploadProgressObservation?.invalidate()
        uploadProgressObservation = nil
        videoProgressObservation?.invalidate()
        videoProgressObservation = nil
    }

    private func setupViews() {
        container.addSubview(thumb)
        thumb.addSubview(play)
        thumb.addSubview(downloadImage)
        thumb.addSubview(duration)
        thumb.addSubview(animateCircleView)
        container.addSubview(progress)

        TUIMessageProgressManager.shared.addDelegate(self)
    }
    
    override func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        guard let videoData = data as? TUIVideoMessageCellData else { return }
        
        self.videoData = videoData
        thumb.image = nil
        
        let hasRiskContent = messageData?.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            thumb.image = TUISwift.timCommonBundleThemeImage("", defaultImage: "icon_security_strike")
            securityStrikeView.textLabel.text = TUISwift.timCommonLocalizableString("TUIKitMessageTypeSecurityStrikeImage")
            duration.text = ""
            play.isHidden = true
            downloadImage.isHidden = true
            indicator.isHidden = true
            animateCircleView.isHidden = true
            return
        }
        
        if videoData.thumbImage == nil {
            videoData.downloadThumb()
        }
        
        if videoData.isPlaceHolderCellData {
            thumb.backgroundColor = .gray
            animateCircleView.progress = videoData.videoTranscodingProgress * 100
            duration.text = ""
            play.isHidden = true
            downloadImage.isHidden = true
            indicator.isHidden = true
            animateCircleView.isHidden = false
            
            videoTranscodingObservation = self.videoData?.observe(\.videoTranscodingProgress, options: [.new, .initial]) { [weak self] _, change in
                guard let self = self, let progress = change.newValue else { return }
                let factor = 0.6
                self.animateCircleView.progress = progress * 100 * factor
            }
            if let thumbImage = videoData.thumbImage {
                thumb.image = thumbImage
            }
            setNeedsUpdateConstraints()
            updateConstraintsIfNeeded()
            layoutIfNeeded()
            return
        }
        
        thumbImageObservation = self.videoData?.observe(\.thumbImage, options: [.new, .initial]) { [weak self] _, change in
            guard let self = self, let thumbImage = change.newValue else { return }
            self.thumb.image = thumbImage
        }
        
        duration.text = String(format: "%02ld:%02ld", (videoData.videoItem?.duration ?? 0) / 60, (videoData.videoItem?.duration ?? 0) % 60)
        
        play.isHidden = true
        downloadImage.isHidden = true
        indicator.isHidden = true

        if videoData.direction == .incoming {
            thumbProgressObservation = self.videoData?.observe(\.thumbProgress, options: [.new, .initial]) { [weak self] _, change in
                guard let self = self, let progress = change.newValue else { return }
                self.progress.text = "\(progress)%"
                self.progress.isHidden = progress >= 100 || progress == 0
                animateCircleView.progress = CGFloat(progress)
                if progress >= 100 || progress == 0 {
                    if videoData.isVideoExist() {
                        self.play.isHidden = false
                    } else {
                        self.downloadImage.isHidden = false
                    }
                } else {
                    self.play.isHidden = true
                    self.downloadImage.isHidden = true
                }
            }
            videoProgressObservation = self.videoData?.observe(\.videoProgress, options: [.new, .initial]) { [weak self] _, change in
                guard let self = self, var progress = change.newValue else { return }
                self.animateCircleView.progress = Double(progress)
                if progress >= 100 || progress == 0 {
                    self.play.isHidden = false
                    self.animateCircleView.isHidden = true
                } else {
                    self.play.isHidden = true
                    self.downloadImage.isHidden = true
                    self.animateCircleView.isHidden = false
                }
            }
        } else {
            if videoData.isVideoExist() {
                uploadProgressObservation = self.videoData?.observe(\.uploadProgress, options: [.new, .initial]) { [weak self] _, change in
                    guard let self = self, var progress = change.newValue else { return }
                    if (videoData.placeHolder?.videoTranscodingProgress ?? 0) > 0 {
                        progress = max(progress, 60)
                    }
                    self.animateCircleView.progress = Double(progress)
                    if progress >= 100 || progress == 0 {
                        self.indicator.stopAnimating()
                        self.play.isHidden = false
                        self.animateCircleView.isHidden = true
                    } else {
                        self.indicator.startAnimating()
                        self.play.isHidden = true
                        self.animateCircleView.isHidden = false
                    }
                }
            } else {
                thumbProgressObservation = self.videoData?.observe(\.thumbProgress, options: [.new, .initial]) { [weak self] _, change in
                    guard let self = self, var progress = change.newValue else { return }
                    self.progress.text = "\(progress)%"
                    self.progress.isHidden = (progress >= 100 || progress == 0)
                    self.animateCircleView.progress = Double(progress)
                    if progress >= 100 || progress == 0 {
                        if videoData.isVideoExist() {
                            self.play.isHidden = false
                        } else {
                            self.downloadImage.isHidden = false
                        }
                    } else {
                        self.play.isHidden = true
                        self.downloadImage.isHidden = true
                    }
                }
                   
                videoProgressObservation = self.videoData?.observe(\.videoProgress, options: [.new, .initial]) { [weak self] _, change in
                    guard let self = self, var progress = change.newValue else { return }
                    self.animateCircleView.progress = Double(progress)
                    if progress >= 100 || progress == 0 {
                        self.play.isHidden = false
                        self.animateCircleView.isHidden = true
                    } else {
                        self.play.isHidden = true
                        self.downloadImage.isHidden = true
                        self.animateCircleView.isHidden = false
                    }
                }
            }
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
        guard let messageData = messageData else { return }
            
        if messageData.messageContainerAppendSize.height > 0 {
            let topMargin: CGFloat = 10
            let tagViewTopMargin: CGFloat = 6
            let thumbHeight = bubbleView.mm_h - topMargin - messageData.messageContainerAppendSize.height - tagViewTopMargin
            let size = TUIVideoMessageCell.getContentSize(messageData)
            thumb.snp.remakeConstraints { make in
                make.height.equalTo(thumbHeight)
                make.width.equalTo(size.width)
                make.centerX.equalTo(bubbleView)
                make.top.equalTo(container).offset(topMargin)
            }
            duration.snp.remakeConstraints { make in
                make.trailing.equalTo(thumb.snp.trailing).offset(-2)
                make.width.greaterThanOrEqualTo(20)
                make.height.equalTo(20)
                make.bottom.equalTo(thumb.snp.bottom)
            }
        } else {
            thumb.snp.remakeConstraints { make in
                make.top.equalTo(bubbleView).offset(messageData.cellLayout?.bubbleInsets.top ?? 0)
                make.bottom.equalTo(bubbleView).offset(-(messageData.cellLayout?.bubbleInsets.bottom ?? 0))
                make.leading.equalTo(bubbleView).offset(messageData.cellLayout?.bubbleInsets.left ?? 0)
                make.trailing.equalTo(bubbleView).offset(-(messageData.cellLayout?.bubbleInsets.right ?? 0))
            }
            duration.snp.remakeConstraints { make in
                make.trailing.equalTo(thumb.snp.trailing).offset(-2)
                make.width.greaterThanOrEqualTo(20)
                make.height.equalTo(20)
                make.bottom.equalTo(thumb.snp.bottom)
            }
        }
            
        let hasRiskContent = messageData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            thumb.snp.remakeConstraints { make in
                make.top.equalTo(bubbleView).offset(12)
                make.size.equalTo(CGSize(width: 150, height: 150))
                make.centerX.equalTo(bubbleView)
            }
                
            securityStrikeView.snp.remakeConstraints { make in
                make.top.equalTo(thumb.snp.bottom)
                make.width.equalTo(bubbleView)
                if messageData.messageContainerAppendSize.height > 0 {
                    make.bottom.equalTo(container).offset(-messageData.messageContainerAppendSize.height)
                } else {
                    make.bottom.equalTo(container).offset(-12)
                }
            }
        }
            
        play.snp.remakeConstraints { make in
            make.size.equalTo(TUISwift.tVideoMessageCell_Play_Size())
            make.center.equalTo(thumb)
        }
        downloadImage.snp.remakeConstraints { make in
            make.size.equalTo(TUISwift.tVideoMessageCell_Play_Size())
            make.center.equalTo(thumb)
        }
            
        animateCircleView.snp.remakeConstraints { make in
            make.center.equalTo(thumb)
            make.size.equalTo(CGSize(width: TUISwift.kScale390(40), height: TUISwift.kScale390(40)))
        }
    }
        
    override open func highlightWhenMatchKeyword(_ keyword: String?) {
        if keyword != nil {
            if highlightAnimating {
                return
            }
            animate(times: 3)
        }
    }
    
    func animate(times: Int) {
        var times = times
        times -= 1
        if times < 0 {
            animateHighlightView?.removeFromSuperview()
            highlightAnimating = false
            return
        }
        highlightAnimating = true
        animateHighlightView?.frame = container.bounds
        animateHighlightView?.alpha = 0.1
        if animateHighlightView != nil {
            container.addSubview(animateHighlightView!)
        }
        UIView.animate(withDuration: 0.25, animations: {
            self.animateHighlightView?.alpha = 0.5
        }, completion: { _ in
            UIView.animate(withDuration: 0.25) {
                self.animateHighlightView?.alpha = 0.1
            } completion: { _ in
                if let videoData = self.videoData, !(videoData.highlightKeyword?.isEmpty ?? false) {
                    self.animate(times: 0)
                    return
                }
                self.animate(times: times)
            }

        })
    }
    
    // MARK: - TUIMessageProgressManagerDelegate
    
    func onUploadProgress(msgID: String, progress: Int) {
        if msgID != videoData?.msgID {
            return
        }
        if videoData?.direction == .outgoing {
            videoData?.uploadProgress = UInt(progress)
        }
    }
    
    func onDownloadProgress(msgID: String, progress: Int) {}
    func onMessageSendingResultChanged(type: TUIMessageSendingResultType, messageID: String) {}
    
    // MARK: - TUIMessageCellProtocol
    
    override class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let videoCellData = data as? TUIVideoMessageCellData else {
            assertionFailure("data must be kind of TUIVideoMessageCellData")
            return CGSize.zero
        }
        
        var size = CGSize.zero
        var isDir = ObjCBool(false)
        if let snapshotPath = videoCellData.snapshotPath, !snapshotPath.isEmpty && FileManager.default.fileExists(atPath: snapshotPath, isDirectory: &isDir) {
            if !isDir.boolValue {
                if let image = UIImage(contentsOfFile: snapshotPath) {
                    size = image.size
                }
            }
        } else {
            size = videoCellData.snapshotItem?.size ?? CGSize.zero
        }
        
        if size == CGSize.zero {
            return size
        }
        
        if size.height > size.width {
            size.width = size.width / size.height * TUISwift.tVideoMessageCell_Image_Height_Max()
            size.height = TUISwift.tVideoMessageCell_Image_Height_Max()
        } else {
            size.height = size.height / size.width * TUISwift.tVideoMessageCell_Image_Width_Max()
            size.width = TUISwift.tVideoMessageCell_Image_Width_Max()
        }
        let hasRiskContent = videoCellData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            let bubbleTopMargin: CGFloat = 12
            let bubbleBottomMargin: CGFloat = 12
            size.height = max(size.height, 150)
            size.width = max(size.width, 200)
            size.height += bubbleTopMargin
            size.height += kTUISecurityStrikeViewTopLineMargin
            size.height += CGFloat(kTUISecurityStrikeViewTopLineToBottom)
            size.height += bubbleBottomMargin
        }
        return size
    }
}
