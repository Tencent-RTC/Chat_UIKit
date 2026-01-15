import UIKit
import TIMCommon
import TUIChat
import SnapKit

// MARK: - Cell Data

/// Cell data for official account message
/// Inherits from TUIBubbleMessageCellData for bubble style support
public class TUIOfficialAccountMessageCellData: TUIBubbleMessageCellData {
    
    /// Message model
    public var messageModel: TUIOfficialAccountMessage?
    
    /// Account info
    public var accountInfo: TUIOfficialAccountInfo?
    
    /// Message type
    public var messageType: TUIOfficialAccountMessageType = .text
    
    /// Text content
    public var textContent: String?
    
    /// Image URL
    public var imageURL: String?
    
    /// Image size
    public var imageSize: CGSize = .zero
    
    /// Link URL
    public var linkURL: String?
    
    /// Link title
    public var linkTitle: String?
    
    /// Link description
    public var linkDescription: String?
    
    /// Link thumbnail URL
    public var linkThumbnailURL: String?
    
    /// Calculated content size (cached)
    public var cachedContentSize: CGSize = .zero
    
    // MARK: - Required Class Methods for Custom Message
    
    /// Create cell data from V2TIMMessage (required for custom message registration)
    override public class func getCellData(message: V2TIMMessage) -> TUIMessageCellData {
        guard let customElem = message.customElem,
              let data = customElem.data,
              let rawDict = TUITool.jsonData2Dictionary(data),
              let businessID = rawDict["businessID"] as? String,
              businessID == OfficialAccountMessageBusinessID else {
            return TUIOfficialAccountMessageCellData(direction: .incoming)
        }
        
        // Convert [AnyHashable: Any] to [String: Any]
        var dict: [String: Any] = [:]
        for (key, value) in rawDict {
            if let stringKey = key as? String {
                dict[stringKey] = value
            }
        }
        
        let cellData = TUIOfficialAccountMessageCellData(direction: message.isSelf ? .outgoing : .incoming)
        cellData.msgID = message.msgID
        cellData.innerMessage = message
        cellData.reuseId = OfficialAccountMessageBusinessID
        
        // Parse message content (matches Android format)
        cellData.textContent = dict["content"] as? String ?? ""
        cellData.linkTitle = dict["title"] as? String ?? ""
        cellData.linkURL = dict["link"] as? String ?? ""
        
        // Parse imageInfo
        if let imageInfoDict = dict["imageInfo"] as? [String: Any] {
            cellData.imageURL = imageInfoDict["url"] as? String
            let width = imageInfoDict["width"] as? Int ?? 0
            let height = imageInfoDict["height"] as? Int ?? 0
            cellData.imageSize = CGSize(width: width, height: height)
        }
        
        // Determine message type
        if cellData.imageURL != nil && !cellData.imageURL!.isEmpty {
            cellData.messageType = .image
        } else if cellData.linkURL != nil && !cellData.linkURL!.isEmpty {
            cellData.messageType = .link
        } else {
            cellData.messageType = .text
        }
        
        // Create message model
        let messageModel = TUIOfficialAccountMessage(dict: dict)
        messageModel?.message = message
        messageModel?.messageID = message.msgID ?? ""
        messageModel?.accountID = message.sender ?? ""
        messageModel?.timestampInMS = TimeInterval((message.timestamp?.timeIntervalSince1970 ?? 0) * 1000)
        cellData.messageModel = messageModel
        
        return cellData
    }
    
    /// Get display string for message list preview (required for custom message registration)
    override public class func getDisplayString(message: V2TIMMessage) -> String {
        guard let customElem = message.customElem,
              let data = customElem.data,
              let rawDict = TUITool.jsonData2Dictionary(data),
              let businessID = rawDict["businessID"] as? String,
              businessID == OfficialAccountMessageBusinessID else {
            return ""
        }
        
        // Return content text if available (matches Android behavior)
        if let content = rawDict["content"] as? String, !content.isEmpty {
            return content
        }
        
        // Check for image
        if let imageInfo = rawDict["imageInfo"] as? [String: Any],
           let url = imageInfo["url"] as? String, !url.isEmpty {
            return TUISwift.timCommonLocalizableString("TUIKitMessageTypeImage")
        }
        
        return ""
    }
    
    // MARK: - Initialization
    
    public override init(direction: TMsgDirection) {
        super.init(direction: direction)
        self.reuseId = OfficialAccountMessageBusinessID
        // Disable avatar and name display completely for official account
        self.showAvatar = false
        self.showName = false
    }
    
    /// Initialize from message model
    public convenience init(message: TUIOfficialAccountMessage) {
        self.init(direction: .incoming)
        self.messageModel = message
        self.messageType = message.messageType
        self.reuseId = OfficialAccountMessageBusinessID
        
        // Set inner message if available
        self.innerMessage = message.message
        self.msgID = message.messageID
        
        // Parse content from message model
        self.textContent = message.contentText
        if let img = message.imageInfo {
            self.imageURL = img.url
            self.imageSize = CGSize(width: img.width, height: img.height)
        }
        self.linkURL = message.link
        self.linkTitle = message.title
    }
    
    /// Calculate image display size based on original aspect ratio
    public func calculateImageDisplaySize() -> CGSize {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            return CGSize(width: 150, height: 150)
        }
        
        let screenWidth = UIScreen.main.bounds.width
        let maxWidth: CGFloat = screenWidth - TUIOfficialAccountMessageCell.Constants.cellHorizontalMargin * 2
        let maxHeight: CGFloat = 400.0
        
        let aspectRatio = imageSize.width / imageSize.height
        
        // Scale image to fit maxWidth
        var width = maxWidth
        var height = width / aspectRatio
        
        // If height exceeds maxHeight, scale down by height
        if height > maxHeight {
            height = maxHeight
            width = height * aspectRatio
        }
        
        return CGSize(width: width, height: height)
    }
}

// MARK: - Cell

/// Cell for displaying official account message
/// Inherits from TUIBubbleMessageCell_Minimalist for bubble style with gray border
/// Completely overrides layout to hide avatar and use custom card-style design
public class TUIOfficialAccountMessageCell: TUIBubbleMessageCell_Minimalist, TUIAttributedLabelDelegate {
    
    // MARK: - Constants
    
    public enum Constants {
        public static let cellHorizontalMargin: CGFloat = 16.0
        public static let contentPadding: CGFloat = 16.0
        public static let cornerRadius: CGFloat = 16.0
        public static let textFont: UIFont = UIFont.systemFont(ofSize: 16)
        public static let timeFont: UIFont = UIFont.systemFont(ofSize: 12)
        public static var maxContentWidth: CGFloat {
            return UIScreen.main.bounds.width - cellHorizontalMargin * 2
        }
    }
    
    // MARK: - UI Components
    
    private lazy var contentTextLabel: TUIAttributedLabel = {
        let label = TUIAttributedLabel(frame: .zero)
        label.font = Constants.textFont
        label.textColor = TUISwift.timCommonDynamicColor("chat_text_message_receive_text_color", defaultColor: "#000000")
        label.numberOfLines = 0
        label.isUserInteractionEnabled = true
        label.delegate = self
        label.linkAttributes = [
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): UIColor.systemBlue
        ]
        return label
    }()
    
    private lazy var contentImageView: UIImageView = {
        let imgView = UIImageView()
        imgView.contentMode = .scaleAspectFill
        imgView.clipsToBounds = true
        imgView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
        imgView.addGestureRecognizer(tapGesture)
        return imgView
    }()
    
    private lazy var msgTimeLabelCustom: UILabel = {
        let label = UILabel()
        label.font = Constants.timeFont
        label.textColor = TUISwift.timCommonDynamicColor("chat_message_read_status_text_gray_color", defaultColor: "#999999")
        label.textAlignment = .right
        return label
    }()
    
    // MARK: - Properties
    
    private var officialAccountCellData: TUIOfficialAccountMessageCellData?
    
    public var onImageTapped: ((String) -> Void)?
    public var onLinkTapped: ((String) -> Void)?
    
    // MARK: - Initialization
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCustomUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    
    private func setupCustomUI() {
        // Add custom views to bubbleView (inside the bubble with gray border)
        bubbleView.addSubview(contentImageView)
        bubbleView.addSubview(contentTextLabel)
        bubbleView.addSubview(msgTimeLabelCustom)
        
        // Set bubble corner radius
        bubbleView.layer.cornerRadius = Constants.cornerRadius
        bubbleView.layer.masksToBounds = true
        
        // Disable long press gesture inherited from parent TUIMessageCell
        disableLongPressGesture()
    }
    
    /// Disable long press gesture on container (inherited from TUIMessageCell)
    private func disableLongPressGesture() {
        for gesture in container.gestureRecognizers ?? [] {
            if gesture is UILongPressGestureRecognizer {
                gesture.isEnabled = false
            }
        }
    }
    
    // MARK: - Fill Data
    
    override open func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        
        // Force hide avatar and other parent UI elements
        avatarView.isHidden = true
        avatarView.alpha = 0
        nameLabel.isHidden = true
        retryView.isHidden = true
        indicator.stopAnimating()
        indicator.isHidden = true
        readReceiptLabel.isHidden = true
        messageModifyRepliesButton.isHidden = true
        msgTimeLabel.isHidden = true
        msgStatusView.isHidden = true
        
        guard let cellData = data as? TUIOfficialAccountMessageCellData else { return }
        self.officialAccountCellData = cellData
        
        // Reset visibility
        contentTextLabel.isHidden = true
        contentImageView.isHidden = true
        
        // Show content based on message type
        let hasText = !(cellData.textContent?.isEmpty ?? true)
        let hasImage = !(cellData.imageURL?.isEmpty ?? true)
        
        if hasText {
            contentTextLabel.isHidden = false
            configureRichText(cellData.textContent ?? "")
        }
        
        if hasImage {
            contentImageView.isHidden = false
            loadImage(from: cellData.imageURL)
            
            // Configure image corner radius based on content
            if hasText {
                // Image at top, only top corners rounded
                contentImageView.layer.cornerRadius = Constants.cornerRadius
                contentImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            } else {
                // Image only, all corners rounded
                contentImageView.layer.cornerRadius = Constants.cornerRadius
                contentImageView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            }
        }
        
        // Set time
        if let timestamp = cellData.innerMessage?.timestamp {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            msgTimeLabelCustom.text = formatter.string(from: timestamp)
        }
        
        // Setup constraints directly in fill 
        setupLayoutConstraints(cellData: cellData, hasText: hasText, hasImage: hasImage)
    }
    
    /// Setup layout constraints 
    private func setupLayoutConstraints(cellData: TUIOfficialAccountMessageCellData, hasText: Bool, hasImage: Bool) {
        let contentSize = Self.getContentSize(cellData)
        
        // Override parent's avatar constraints 
        avatarView.snp.remakeConstraints { make in
            make.size.equalTo(CGSize.zero)
            make.leading.equalTo(-100)
            make.top.equalTo(0)
        }
        
        // Override parent's container constraints 
        container.snp.remakeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(8)
            make.width.equalTo(contentSize.width)
            make.height.equalTo(contentSize.height)
        }
        
        // Bubble fills container
        bubbleView.snp.remakeConstraints { make in
            make.edges.equalTo(container)
        }
        
        if hasImage {
            let imageSize = cellData.calculateImageDisplaySize()
            contentImageView.snp.remakeConstraints { make in
                make.top.leading.trailing.equalToSuperview()
                make.width.equalTo(imageSize.width)
                make.height.equalTo(imageSize.height)
            }
        }
        
        if hasText {
            contentTextLabel.snp.remakeConstraints { make in
                make.leading.equalToSuperview().offset(Constants.contentPadding)
                make.trailing.equalToSuperview().offset(-Constants.contentPadding)
                if hasImage {
                    make.top.equalTo(contentImageView.snp.bottom).offset(Constants.contentPadding)
                } else {
                    make.top.equalToSuperview().offset(Constants.contentPadding)
                }
            }
            
            msgTimeLabelCustom.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-Constants.contentPadding)
                make.top.equalTo(contentTextLabel.snp.bottom).offset(4)
                make.bottom.equalToSuperview().offset(-Constants.contentPadding)
            }
        } else if hasImage {
            // Image only - time label overlays on image
            msgTimeLabelCustom.snp.remakeConstraints { make in
                make.trailing.equalToSuperview().offset(-Constants.contentPadding)
                make.bottom.equalToSuperview().offset(-Constants.contentPadding)
            }
        }
    }
    
    /// Configure rich text with link detection
    private func configureRichText(_ text: String) {
        // First, parse and replace Markdown-style links: [text](url) -> text with link
        let (displayText, links) = parseMarkdownLinks(in: text)
        
        let attributedString = NSMutableAttributedString(string: displayText)
        let wholeRange = NSRange(location: 0, length: displayText.utf16.count)
        
        // Apply base attributes
        attributedString.addAttribute(.font, value: Constants.textFont, range: wholeRange)
        attributedString.addAttribute(.foregroundColor, value: TUISwift.timCommonDynamicColor("chat_text_message_receive_text_color", defaultColor: "#000000"), range: wholeRange)
        
        contentTextLabel.attributedText = attributedString
        
        // Add Markdown links
        for (url, range) in links {
            contentTextLabel.addLink(to: url, withRange: range)
        }
        
        // Auto-detect plain URLs in text
        detectURLs(in: displayText)
    }
    
    /// Parse Markdown-style links: [text](url) and return display text with link positions
    /// - Parameter text: Original text with Markdown links
    /// - Returns: Tuple of (display text, array of (URL, range) pairs)
    private func parseMarkdownLinks(in text: String) -> (String, [(URL, NSRange)]) {
        let pattern = "\\[([^\\]]+)\\]\\(([^)]+)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (text, [])
        }
        
        var displayText = text
        var links: [(URL, NSRange)] = []
        let nsText = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        // Process matches in reverse order to maintain correct ranges after replacement
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }
            let fullRange = match.range(at: 0)  // Full match: [text](url)
            let textRange = match.range(at: 1)  // Captured group 1: text
            let urlRange = match.range(at: 2)   // Captured group 2: url
            
            let linkText = nsText.substring(with: textRange)
            let urlString = nsText.substring(with: urlRange)
            
            guard let url = URL(string: urlString) else { continue }
            
            // Replace [text](url) with text in displayText
            let nsDisplayText = displayText as NSString
            displayText = nsDisplayText.replacingCharacters(in: fullRange, with: linkText)
            
            // Calculate the new range for the link text in displayText
            let newRange = NSRange(location: fullRange.location, length: linkText.utf16.count)
            links.insert((url, newRange), at: 0)
        }
        
        return (displayText, links)
    }
    
    /// Auto-detect URLs in text
    private func detectURLs(in text: String) {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return }
        
        let nsText = text as NSString
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))
        
        for match in matches {
            if let url = match.url {
                contentTextLabel.addLink(to: url, withRange: match.range)
            }
        }
    }
    
    private func loadImage(from urlString: String?) {
        guard let urlString = urlString, let url = URL(string: urlString) else { return }
        contentImageView.sd_setImage(with: url, placeholderImage: nil)
    }
    
    // MARK: - Actions
    
    @objc private func imageTapped() {
        guard let imageURL = officialAccountCellData?.imageURL else { return }
        
        // Show image preview controller (single image, non-scrollable)
        let previewVC = TUIOfficialAccountImagePreviewController(imageURL: imageURL)
        if let viewController = findViewController() {
            viewController.present(previewVC, animated: true)
        }
        
        onImageTapped?(imageURL)
    }
    
    /// Find the view controller that contains this cell
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let nextResponder = responder?.next {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            responder = nextResponder
        }
        return nil
    }
    
    // MARK: - Reuse
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        contentTextLabel.text = nil
        contentTextLabel.attributedText = nil
        contentImageView.image = nil
        officialAccountCellData = nil
    }
    
    // MARK: - TUIAttributedLabelDelegate
    
    public func attributedLabel(_ label: TUIAttributedLabel, didSelectLink link: URL) {
        // Open link in system browser
        if UIApplication.shared.canOpenURL(link) {
            UIApplication.shared.open(link, options: [:], completionHandler: nil)
        }
        onLinkTapped?(link.absoluteString)
    }
    
    public func attributedLabel(_ label: TUIAttributedLabel, didSelectAddress addressComponents: [NSTextCheckingKey: String]) {}
    
    public func attributedLabel(_ label: TUIAttributedLabel, didSelectDate date: Date, timeZone: TimeZone, duration: TimeInterval) {}
    
    public func attributedLabel(_ label: TUIAttributedLabel, didSelectPhoneNumber phoneNumber: String) {}
    
    public func attributedLabel(_ label: TUIAttributedLabel, didSelectTextCheckingResult result: NSTextCheckingResult) {}
    
    public func attributedLabel(_ label: TUIAttributedLabel, didSelectTransitInfo transitInfo: [NSTextCheckingKey: String]) {}
    
    // MARK: - TUIMessageCellProtocol
    
    override public class func getEstimatedHeight(_ data: TUIMessageCellData) -> CGFloat {
        return 100.0
    }
    
    override public class func getHeight(_ data: TUIMessageCellData, withWidth width: CGFloat) -> CGFloat {
        guard let cellData = data as? TUIOfficialAccountMessageCellData else {
            return 60.0
        }
        let contentSize = getContentSize(cellData)
        return contentSize.height + 16 // Add vertical margins
    }
    
    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let cellData = data as? TUIOfficialAccountMessageCellData else {
            return CGSize(width: 200, height: 60)
        }
        return getContentSize(cellData)
    }
    
    /// Calculate content size for the cell
    public class func getContentSize(_ data: TUIOfficialAccountMessageCellData) -> CGSize {
        // Return cached size if available
        if data.cachedContentSize != .zero {
            return data.cachedContentSize
        }
        
        var totalHeight: CGFloat = 0
        let maxWidth: CGFloat = Constants.maxContentWidth
        
        let hasText = !(data.textContent?.isEmpty ?? true)
        let hasImage = !(data.imageURL?.isEmpty ?? true)
        
        // Calculate image size
        if hasImage {
            let imageSize = data.calculateImageDisplaySize()
            totalHeight += imageSize.height
        }
        
        // Calculate text size
        if hasText, let text = data.textContent {
            let textMaxWidth = maxWidth - Constants.contentPadding * 2
            let rect = (text as NSString).boundingRect(
                with: CGSize(width: textMaxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: Constants.textFont],
                context: nil
            )
            
            // Text height + padding + time label
            totalHeight += ceil(rect.height) + Constants.contentPadding * 2 + 20
        }
        
        // Ensure minimum size
        totalHeight = max(totalHeight, 44)
        
        let size = CGSize(width: maxWidth, height: totalHeight)
        data.cachedContentSize = size
        return size
    }
}
