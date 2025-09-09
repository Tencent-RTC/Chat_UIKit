//
//  TUIChatbotMessagePlaceholderCell_Minimalist.swift
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

public class TUIChatbotMessagePlaceholderCell_Minimalist: TUITextMessageCell_Minimalist {
    
    // MARK: - Properties
    
    private var _loadingImageView: UIImageView?
    public var loadingImageView: UIImageView {
        if _loadingImageView == nil {
            setupLoadingImageView()
        }
        return _loadingImageView!
    }
    
    private var animationDisplayLink: CADisplayLink?
    private var currentFrameIndex: Int = 0
    private var animationFrames: [UIImage] = []
    
    // MARK: - Initialization
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupLoadingImageView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        stopLoadingAnimation()
    }
    
    // MARK: - Cell Lifecycle
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        stopLoadingAnimation()
        _loadingImageView?.isHidden = true
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Position loading image view in the center of the bubble
        if let loadingImageView = _loadingImageView, !loadingImageView.isHidden {
            let imageSize: CGFloat = 24.0
            let containerWidth = container.frame.size.width
            let containerHeight = container.frame.size.height
            
            let imageX = (containerWidth - imageSize) / 2
            let imageY = (containerHeight - imageSize) / 2
            
            loadingImageView.frame = CGRect(x: imageX, y: imageY, width: imageSize, height: imageSize)
        }
    }
    
    // MARK: - Public Methods
    
    override public func fill(with data: TUICommonCellData) {
        super.fill(with: data)
        
        guard let placeholderData = data as? TUIChatbotMessagePlaceholderCellData else {
            return
        }
        
        // Hide the text view since we only want to show loading animation
        textView.isHidden = true
        
        // Setup and show loading animation
        setupLoadingImageView()
        
        if placeholderData.isAITyping {
            _loadingImageView?.isHidden = false
            startLoadingAnimation()
        } else {
            _loadingImageView?.isHidden = true
            stopLoadingAnimation()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupLoadingImageView() {
        if _loadingImageView == nil {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.isHidden = false
            
            // Add to container instead of textView since we want it to be the main content
            container.addSubview(imageView)
            _loadingImageView = imageView
            
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
            UIGraphicsBeginImageContextWithOptions(CGSize(width: 30, height: 20), false, UIScreen.main.scale)
            
            text.draw(in: CGRect(x: 0, y: 0, width: 30, height: 20), withAttributes: [
                .font: UIFont.systemFont(ofSize: 14),
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
        _loadingImageView?.image = animationFrames[currentFrameIndex]
    }
}
