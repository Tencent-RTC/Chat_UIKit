//
//  TUIChatbotMessageCell_Minimalist.swift
//  TUIChat
//
//  Created by yiliangwang on 2025/1/20.
//  Copyright © 2023 Tencent. All rights reserved.
//

import Foundation
import UIKit
import TIMCommon
import TUICore
import SDWebImage

public class TUIChatbotMessageCell_Minimalist: TUITextMessageCell_Minimalist {
    
    // MARK: - Properties
    
    private var loadingImageView: UIImageView?
    private var animationDisplayLink: CADisplayLink?
    private var currentFrameIndex: Int = 0
    private var animationFrames: [UIImage] = []
    private var currentTimer: DispatchSourceTimer?
    
    // MARK: - Initialization
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add notification listener for immediate stop rendering
        textView.isSelectable = false
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onImmediateStopRendering(_:)),
            name: NSNotification.Name("TUIChatbotImmediateStopRendering"),
            object: nil
        )
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopLoadingAnimation()
        
        // Stop current timer
        if let timer = currentTimer {
            stopTimer(timer)
            currentTimer = nil
            
            // Also clear data.timer
            if let data = textData as? TUIChatbotMessageCellData {
                data.timer = nil
            }
        }
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Cell Lifecycle
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset loading image view state to prevent cell reuse issues
        stopLoadingAnimation()
        if let loadingImageView = loadingImageView {
            loadingImageView.isHidden = true
            loadingImageView.image = nil
        }
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        updateLoadingImageViewLayout()
    }
    
    // MARK: - Notification Handlers
    
    @objc private func onImmediateStopRendering(_ notification: Notification) {
        // Check if this notification is for this specific cell
        if let targetCellData = notification.userInfo?["cellData"] as? TUIMessageCellData,
           targetCellData === textData {
            immediateStopRendering()
        }
    }
    
    // MARK: - Public Methods
    
    /// Immediately stop the streaming rendering timer and loading animation
    /// This method can be called externally to force stop the rendering process
    public func immediateStopRendering() {
        // Immediately stop timer
        if let timer = currentTimer {
            stopTimer(timer)
            currentTimer = nil
            
            // Also clear data.timer if it matches current timer
            if let data = textData as? TUIChatbotMessageCellData {
                data.timer = nil
            }
        }
        
        // Stop loading animation
        stopLoadingAnimation()
        
        // Hide loading image
        loadingImageView?.isHidden = true
        
        print("TUIChatbotMessageCell_Minimalist: Immediate stop rendering executed")
    }
    
    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        
        guard let chatbotData = data as? TUIChatbotMessageCellData else {
            return
        }
        
        // Setup loading image view
        setupLoadingImageView()
        
        // Always handle loading image visibility based on isFinished state
        if chatbotData.isFinished {
            stopLoadingAnimation()
            loadingImageView?.isHidden = true
            loadingImageView?.image = nil
        } else {
            startLoadingAnimation()
            loadingImageView?.isHidden = false
        }
        
        // Online Push text needs streaming display
        if chatbotData.source == .onlinePush {
            // Reuse existing timer from chatbotData.timer or create new one
            if let existingTimer = chatbotData.timer {
                // Reuse existing timer
                currentTimer = existingTimer
            } else {
                // Create new timer only if chatbotData.timer is nil
                let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                currentTimer = timer
                chatbotData.timer = timer
                
                let period: TimeInterval = 0.01
                timer.schedule(deadline: .now() + period, repeating: period)
                
                timer.setEventHandler { [weak self, weak chatbotData] in
                    guard let self = self, let chatbotData = chatbotData else { return }
                    
                    if chatbotData.displayedContentLength == (chatbotData.contentString?.length ?? 0) {
                        self.stopTimer(timer)
                        self.currentTimer = nil
                        chatbotData.timer = nil
                        if chatbotData.isFinished {
                            self.stopLoadingAnimation()
                            self.loadingImageView?.isHidden = true
                        }
                        return
                    }
                    
                    chatbotData.displayedContentLength += 1
                    
                    if self.textView.attributedText.length > 1 &&
                       self.getAttributeStringRect(self.textView.attributedText).size.height >
                       self.getAttributeStringRect(self.textView.attributedText.attributedSubstring(from: NSRange(location: 0, length: self.textView.attributedText.length - 1))).size.height {
                        self.stopTimer(timer)
                        self.currentTimer = nil
                        chatbotData.timer = nil
                        self.notifyCellSizeChanged()
                    } else {
                        let textColor: UIColor
                        let textFont: UIFont
                        
                        if chatbotData.direction == .incoming {
                            textColor = type(of: self).incommingTextColor!
                            textFont = type(of: self).incommingTextFont!
                        } else {
                            textColor = type(of: self).outgoingTextColor!
                            textFont = type(of: self).outgoingTextFont!
                        }
                        
                        // Use original content display method
                        self.textView.attributedText = chatbotData.getContentAttributedString(textFont: textFont)
                        self.textView.textColor = textColor
                        self.textView.textAlignment = TUISwift.isRTL() ? .right : .left
                        
                        self.updateCellConstraints()
                        
                        // Update loading image position - follow text dynamically
                        self.updateLoadingImageViewLayout()
                        
                        // Always keep loading animation visible during streaming process
                        if self.animationDisplayLink == nil {
                            self.startLoadingAnimation()
                        }
                        self.loadingImageView?.isHidden = false
                    }
                }
                
                timer.resume()
            }
        } else {
            // Non-streaming display handling
            let textFont = chatbotData.direction == .outgoing ? 
                type(of: self).outgoingTextFont! : type(of: self).incommingTextFont!
            
            textView.attributedText = chatbotData.getContentAttributedString(textFont: textFont)
            textView.textColor = type(of: self).incommingTextColor!
            textView.textAlignment = TUISwift.isRTL() ? .right : .left
            
            // Only update layout if loading image should be visible
            if !chatbotData.isFinished {
                updateLoadingImageViewLayout()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLoadingImageView() {
        if loadingImageView == nil {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.isHidden = true
            textView.addSubview(imageView)
            loadingImageView = imageView
            
            // Load GIF animation frames
            loadAnimationFrames()
        }
    }
    
    private func loadAnimationFrames() {
        let path :String? = TUISwift.tuiChatImagePath("chat_ai_loading.gif")

        guard let gifPath = path,
              let data = NSData(contentsOfFile: gifPath),
              let image = UIImage.sd_image(withGIFData: data as Data),
              let images = image.images, !images.isEmpty else {
            // If GIF not found, create simple loading animation
            createSimpleLoadingAnimation()
            return
        }
        
        animationFrames = images
    }
    
    private func createSimpleLoadingAnimation() {
        // Create simple dot animation frames
        var frames: [UIImage] = []
        let dotTexts = ["●", "●●", "●●●"]
        
        for text in dotTexts {
            UIGraphicsBeginImageContextWithOptions(CGSize(width: 20, height: 20), false, UIScreen.main.scale)
            
            text.draw(in: CGRect(x: 0, y: 0, width: 20, height: 20), withAttributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.lightGray
            ])
            
            if let image = UIGraphicsGetImageFromCurrentImageContext() {
                frames.append(image)
            }
            
            UIGraphicsEndImageContext()
        }
        
        animationFrames = frames
    }
    
    private func startLoadingAnimation() {
        guard !animationFrames.isEmpty else { return }
        
        stopLoadingAnimation()
        
        currentFrameIndex = 0
        animationDisplayLink = CADisplayLink(target: self, selector: #selector(updateAnimationFrame))
        animationDisplayLink?.preferredFramesPerSecond = 3 // 3 FPS for loading animation
        animationDisplayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopLoadingAnimation() {
        animationDisplayLink?.invalidate()
        animationDisplayLink = nil
    }
    
    @objc private func updateAnimationFrame() {
        guard !animationFrames.isEmpty else { return }
        
        currentFrameIndex = (currentFrameIndex + 1) % animationFrames.count
        loadingImageView?.image = animationFrames[currentFrameIndex]
    }
    
    private func updateLoadingImageViewLayout() {
        guard let loadingImageView = loadingImageView, 
              !loadingImageView.isHidden,
              let displayedText = textView.text, 
              !displayedText.isEmpty else { return }
        
        // Calculate actual text rendering position
        let layoutManager = textView.layoutManager
        let textContainer = textView.textContainer
        
        // Get position of the last character
        let lastCharRange = NSRange(location: displayedText.count - 1, length: 1)
        let lastCharRect = layoutManager.boundingRect(forGlyphRange: lastCharRange, in: textContainer)
        
        // Set loading image position to the right of the last character
        let imageSize: CGFloat = 16.0
        let imageX = lastCharRect.origin.x + lastCharRect.size.width + 4 // 4px spacing after last character
        let imageY = lastCharRect.origin.y + (lastCharRect.size.height - imageSize) / 2 // Vertically centered
        
        // Convert to textView coordinate system
        let textViewX = textView.textContainerInset.left + imageX
        let textViewY = textView.textContainerInset.top + imageY
        
        loadingImageView.frame = CGRect(x: textViewX, y: textViewY, width: imageSize, height: imageSize)
        
        if TUISwift.isRTL() {
            loadingImageView.resetFrameToFitRTL()
        }
    }
    
    private func getAttributeStringRect(_ attributeString: NSAttributedString) -> CGRect {
        return attributeString.boundingRect(
            with: CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(), height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
    }
    
    private func stopTimer(_ timer: DispatchSourceTimer) {
        timer.cancel()
    }
    
    private func notifyCellSizeChanged() {
        guard let innerMessage = textData?.innerMessage else { return }
        let param = [TUICore_TUIPluginNotify_PluginViewSizeChangedSubKey_Message: innerMessage]
        TUICore.notifyEvent(
            TUICore_TUIPluginNotify,
            subKey: TUICore_TUIPluginNotify_PluginViewSizeChangedSubKey,
            object: nil,
            param: param
        )
    }
    
    private func updateCellConstraints() {
        // tell constraints they need updating
        setNeedsUpdateConstraints()
        // update constraints now so we can animate the change
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }
    
    // MARK: - TUIMessageCellProtocol
    
    /// Custom getContentSize for chatbot messages to fix whitespace issues
    override public class func getContentSize(_ data: TUIMessageCellData) -> CGSize {
        guard let chatbotData = data as? TUIChatbotMessageCellData else {
            // Fallback to parent implementation for non-chatbot data
            return super.getContentSize(data)
        }
        
        let textFont = chatbotData.direction == .incoming ? incommingTextFont! : outgoingTextFont!
        let attributeString = chatbotData.getContentAttributedString(textFont: textFont)
        
        // Calculate text size with proper status positioning
        let maxTextSize = CGSize(width: TUISwift.tTextMessageCell_Text_Width_Max(), height: CGFloat.greatestFiniteMagnitude)
        let contentSize = chatbotData.getContentAttributedStringSize(attributeString: attributeString, maxTextSize: maxTextSize)
        
        var adjustedContentSize = contentSize
        let statusWidth = chatbotData.msgStatusSize.width + TUISwift.kScale390(10) // Status width + padding
        let availableWidth = TUISwift.tTextMessageCell_Text_Width_Max()
        
        // Check if we need to add space for message status (time)
        let isSingleLine = contentSize.height <= textFont.lineHeight * 1.5 // Allow some tolerance for line height
        
        if isSingleLine {
            // Single line: check if there's enough space for status
            if contentSize.width + statusWidth > availableWidth {
                // Not enough space, force status to next line
                adjustedContentSize.height += chatbotData.msgStatusSize.height
            } else {
                // Enough space, extend width to include status
                adjustedContentSize.width += statusWidth
            }
        } else {
            // Multi-line: check if last line has enough space for status
            // Use a more accurate method to determine if status needs to wrap
            
            // Create a temporary text view to measure the actual last line width
            let tempTextView = UITextView()
            tempTextView.font = textFont
            tempTextView.attributedText = attributeString
            tempTextView.textContainerInset = .zero
            tempTextView.textContainer.lineFragmentPadding = 0
            tempTextView.textContainer.size = CGSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
            
            // Force layout to get accurate line measurements
            tempTextView.layoutManager.ensureLayout(for: tempTextView.textContainer)
            
            // Get the last line's used rect by enumerating line fragments
            var lastLineRect: CGRect = .zero
            var foundLastLine = false
            
            tempTextView.layoutManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: attributeString.length)) { (rect, usedRect, textContainer, glyphRange, stop) in
                lastLineRect = usedRect
                foundLastLine = true
            }
            
            if foundLastLine {
                // Check if last line has enough space for status
                if lastLineRect.width + statusWidth > availableWidth {
                    // Last line doesn't have enough space, force status to next line
                    adjustedContentSize.height += chatbotData.msgStatusSize.height
                }
            } else {
                // Fallback: if we can't determine line info, assume status needs to wrap for safety
                adjustedContentSize.height += chatbotData.msgStatusSize.height
            }
        }
        
        chatbotData.textSize = adjustedContentSize
        
        let textOrigin = CGPoint(x: chatbotData.cellLayout?.bubbleInsets.left ?? 0,
                                y: (chatbotData.cellLayout?.bubbleInsets.top ?? 0) + TUIBubbleMessageCell_Minimalist.getBubbleTop(data: chatbotData))
        chatbotData.textOrigin = textOrigin
        
        var height = adjustedContentSize.height
        var width = adjustedContentSize.width
        
        height += (chatbotData.cellLayout?.bubbleInsets.top ?? 0) + (chatbotData.cellLayout?.bubbleInsets.bottom ?? 0)
        width += (chatbotData.cellLayout?.bubbleInsets.left ?? 0) + (chatbotData.cellLayout?.bubbleInsets.right ?? 0)
        
        if chatbotData.direction == .incoming {
            height = max(height, TUIBubbleMessageCell_Minimalist.incommingBubble?.size.height ?? 0)
        } else {
            height = max(height, TUIBubbleMessageCell_Minimalist.outgoingBubble?.size.height ?? 0)
        }
        
        let hasRiskContent = chatbotData.innerMessage?.hasRiskContent ?? false
        if hasRiskContent {
            width = max(width, 200)
            height += kTUISecurityStrikeViewTopLineMargin
            height += CGFloat(kTUISecurityStrikeViewTopLineToBottom)
        }
        
        return CGSize(width: width, height: height)
    }
}
