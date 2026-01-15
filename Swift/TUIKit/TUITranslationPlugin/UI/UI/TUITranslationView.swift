import SnapKit
import TIMCommon
import TUIChat
import TUICore
import UIKit

class TUITranslationView: UIView {
    private var text: String?
    private var tips: String?
    private var bgColor: UIColor?
    
    private let tipsIcon = UIImageView()
    private let tipsLabel = UILabel()
    private let loadingView = UIImageView()
    private let textView = TUITextView()
    private let retryView = UIImageView()
    
    private var cellData: TUIMessageCellData!
    
    // Button container - will be added to parent view (bottomContainer)
    private var buttonContainer: UIView?
    
    convenience init(data: TUIMessageCellData) {
        self.init(frame: CGRect.zero)
        self.cellData = data
        
        var shouldShow = false
        if let msg = data.innerMessage {
            shouldShow = TUITranslationDataProvider.shouldShowTranslation(msg)
        }
        
        if shouldShow {
            refresh(with: data)
        } else {
            if !cellData.bottomContainerSize.equalTo(.zero) {
                notifyTranslationChanged()
            }
            self.isHidden = true
            stopLoading()
            cellData?.bottomContainerSize = .zero
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupGesture()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func refresh(with cellData: TUIMessageCellData) {
        var status = TUITranslationViewStatus.unknown
        if let msg = cellData.innerMessage {
            text = TUITranslationDataProvider.getTranslationText(msg)
            status = TUITranslationDataProvider.getTranslationStatus(msg)
        }
        
        let translationSize = calcSize(of: status)
        
        // Bottom container should include translation view and optional "Show Original" button
        var containerSize = translationSize
        if shouldShowOriginalButton() {
            let buttonHeight: CGFloat = 24
            let buttonTopMargin: CGFloat = 2
            containerSize.height += buttonHeight + buttonTopMargin
        }
        
        if !cellData.bottomContainerSize.equalTo(containerSize) {
            notifyTranslationChanged()
        }
        cellData.bottomContainerSize = containerSize
        
        // Set translation view frame to its own content size (without button area)
        mm_top(0).mm_left(0).mm_width(translationSize.width).mm_height(translationSize.height)
//        snp.makeConstraints { make in
//            make.top.left.equalTo(0)
//            make.width.equalTo(size.width)
//            make.height.equalTo(size.height)
//        }
        if status == .loading {
            startLoading()
        } else if status == .shown || status == .securityStrike {
            stopLoading()
            updateTranslationView(by: text, translationViewStatus: status)
            
            // Apply bilingual mode setting when translation is shown
            applyBilingualModeSetting(cellData: cellData, status: status)
        }
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
    }
    
    /// Apply bilingual mode setting to hide/show original text
    private func applyBilingualModeSetting(cellData: TUIMessageCellData, status: TUITranslationViewStatus) {
        guard let message = cellData.innerMessage else { return }
        
        // If user manually requested to show original, respect that choice
        if TUITranslationDataProvider.userRequestedShowOriginal(message) {
            TUITranslationDataProvider.setShouldHideOriginalText(false, for: message)
            return
        }
        
        let previousShouldHide = TUITranslationDataProvider.shouldHideOriginalText(message)
        
        // Only apply when translation is successfully shown
        if status == .shown || status == .securityStrike {
            if !TUITranslationConfig.shared.showBilingualEnabled {
                // Bilingual mode OFF: hide original text
                TUITranslationDataProvider.setShouldHideOriginalText(true, for: message)
            } else {
                // Bilingual mode ON: show both original and translation
                TUITranslationDataProvider.setShouldHideOriginalText(false, for: message)
            }
        } else {
            // Translation not shown: always show original text
            TUITranslationDataProvider.setShouldHideOriginalText(false, for: message)
        }
        
        let currentShouldHide = TUITranslationDataProvider.shouldHideOriginalText(message)
        
        // If shouldHideOriginalText changed, trigger height recalculation
        if previousShouldHide != currentShouldHide {
            notifyTranslationChanged()
        }
    }
    
    private func calcSize(of status: TUITranslationViewStatus) -> CGSize {
        let minTextWidth: CGFloat = 164
        let maxTextWidth = TUISwift.screen_Width() * 0.68
        let actualTextWidth: CGFloat = 80 - 20
        let tipsHeight: CGFloat = 20
        let tipsBottomMargin: CGFloat = 10
        let oneLineTextHeight: CGFloat = 22
        let commonMargins: CGFloat = 10 * 2
        
        if status == .loading {
            return CGSize(width: 80, height: oneLineTextHeight + commonMargins)
        }
        var locations: [[NSValue: NSAttributedString]]? = nil
        let attrStr = text?.getAdvancedFormatEmojiString(withFont: UIFont.systemFont(ofSize: 16), textColor: .gray, emojiLocations: &locations) ?? NSAttributedString()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left
        
        var textRect = attrStr.boundingRect(with: CGSize(width: actualTextWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        
        if textRect.height < 30 {
            return CGSize(width: max(textRect.width, minTextWidth) + commonMargins, height: max(textRect.height, oneLineTextHeight) + commonMargins + tipsHeight + tipsBottomMargin)
        }
        
        textRect = attrStr.boundingRect(with: CGSize(width: maxTextWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        let result = CGSize(width: max(textRect.width, minTextWidth) + commonMargins, height: max(textRect.height, oneLineTextHeight) + commonMargins + tipsHeight + tipsBottomMargin)
        return CGSize(width: ceil(result.width), height: ceil(result.height))
    }
    
    /// Determine if \"Show Original\" button should be displayed
    func shouldShowOriginalButton() -> Bool {
        guard let message = cellData?.innerMessage else { return false }
        
        // Reference and reply messages should NOT show this button
        // They must always display original text
        if isReferenceOrReplyMessage(message) {
            return false
        }
        
        // Show button only when:
        // 1. Translation is shown
        // 2. Global bilingual mode is OFF
        // 3. Original text is currently hidden
        return TUITranslationDataProvider.shouldHideOriginalText(message) && !TUITranslationConfig.shared.showBilingualEnabled
    }
    
    /// Check if message is a reference or reply message by parsing cloudCustomData
    private func isReferenceOrReplyMessage(_ message: V2TIMMessage) -> Bool {
        guard let cloudCustomData = message.cloudCustomData,
              let dict = try? JSONSerialization.jsonObject(with: cloudCustomData) as? [String: Any]
        else {
            return false
        }
        
        // Check for messageReply key which indicates reply/reference message
        if dict["messageReply"] as? [String: Any] != nil {
            return true
        }
        return false
    }
    
    private func setupViews() {
        backgroundColor = bgColor ?? TUISwift.tuiTranslationDynamicColor("translation_view_bg_color", defaultColor: "#F2F7FF")
        layer.cornerRadius = 10.0
        clipsToBounds = true
        
        loadingView.frame = CGRect(x: 0, y: 0, width: 15, height: 15)
        loadingView.image = TUISwift.tuiTranslationBundleThemeImage("translation_view_icon_loading_img", defaultImage: "translation_loading")
        loadingView.isHidden = true
        addSubview(loadingView)
        
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.isScrollEnabled = false
        textView.isEditable = false
        textView.textAlignment = TUISwift.isRTL() ? .right : .left
        textView.disableHighlightLink()
        addSubview(textView)
        textView.isHidden = true
        textView.isUserInteractionEnabled = false
        
        tipsIcon.frame = CGRect(x: 0, y: 0, width: 13, height: 13)
        tipsIcon.image = TUISwift.tuiTranslationBundleThemeImage("translation_view_icon_tips_img", defaultImage: "translation_tips")
        tipsIcon.alpha = 0.4
        addSubview(tipsIcon)
        tipsIcon.isHidden = true
        
        tipsLabel.font = UIFont.systemFont(ofSize: 12)
        tipsLabel.text = TUISwift.timCommonLocalizableString("TUIKitTranslateDefaultTips")
        tipsLabel.textColor = TUISwift.tuiTranslationDynamicColor("translation_view_tips_color", defaultColor: "#000000")
        tipsLabel.alpha = 0.4
        tipsLabel.numberOfLines = 0
        tipsLabel.textAlignment = TUISwift.isRTL() ? .right : .left
        addSubview(tipsLabel)
        tipsLabel.isHidden = true
        
        retryView.image = UIImage.safeImage(TUISwift.tuiChatImagePath("msg_error"))
        retryView.isHidden = true
        addSubview(retryView)
    }
    
    private func setupGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(onLongPressed(_:)))
        addGestureRecognizer(longPress)
    }
    
    override class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    override func updateConstraints() {
        super.updateConstraints()
        
        if text?.isEmpty ?? true {
            loadingView.snp.remakeConstraints { make in
                make.height.width.equalTo(15)
                make.leading.equalTo(10)
                make.centerY.equalToSuperview()
            }
        } else {
            retryView.snp.remakeConstraints { make in
                if cellData?.direction == .outgoing {
                    make.leading.equalToSuperview().offset(-27)
                } else {
                    make.trailing.equalToSuperview().offset(27)
                }
                make.centerY.equalToSuperview()
                make.width.height.equalTo(20)
            }
            
            let adjustedHeight = self.frame.height
            
            textView.snp.remakeConstraints { make in
                make.height.equalTo(adjustedHeight - 10 - 40 + 2)
                make.leading.equalTo(10)
                make.trailing.equalTo(-10)
                make.top.equalTo(10)
            }
            tipsIcon.snp.remakeConstraints { make in
                make.top.equalTo(textView.snp.bottom).offset(14)
                make.leading.equalTo(10)
                make.height.width.equalTo(13)
            }
            tipsLabel.sizeToFit()
            tipsLabel.snp.remakeConstraints { make in
                make.centerY.equalTo(tipsIcon.snp.centerY)
                make.leading.equalTo(tipsIcon.snp.trailing).offset(4)
                make.trailing.equalTo(textView.snp.trailing)
            }
        }
        
        // Update button container if exists
        updateShowOriginalButton()
    }
    
    private func updateTranslationView(by text: String?, translationViewStatus status: TUITranslationViewStatus) {
        let isTranslated = !(text?.isEmpty ?? true)
        var textColor = TUISwift.tuiTranslationDynamicColor("translation_view_text_color", defaultColor: "#000000")
        var bgColor = TUISwift.tuiTranslationDynamicColor("translation_view_bg_color", defaultColor: "#F2F7FF")
        if status == .securityStrike {
            bgColor = UIColor.tui_color(withHex: "#FA5151", alpha: 0.16) ?? UIColor()
            textColor = TUISwift.tuiTranslationDynamicColor("", defaultColor: "#DA2222")
        }
        self.bgColor = bgColor
        backgroundColor = bgColor
        
        if isTranslated {
            var locations: [[NSValue: NSAttributedString]]? = nil
            let originAttributedText = text?.getAdvancedFormatEmojiString(withFont: UIFont.systemFont(ofSize: 16), textColor: textColor, emojiLocations: &locations) ?? NSAttributedString()
            textView.attributedText = TUISwift.isRTL() ? rtlAttributeString(originAttributedText, textAlignment: .right) : originAttributedText
        }
        textView.isHidden = !isTranslated
        tipsIcon.isHidden = !isTranslated
        tipsLabel.isHidden = !isTranslated
        retryView.isHidden = !(status == .securityStrike)
        
        // Update "Show Original" button (in parent container)
        updateShowOriginalButton()
    }
    
    /// Update or create "Show Original" button in parent container (bottomContainer)
    private func updateShowOriginalButton() {
        guard let parentView = superview else {
            return
        }
        
        let shouldShow = shouldShowOriginalButton()
        
        if shouldShow {
            // Create or show button
            if buttonContainer == nil {
                // Create button container
                let container = UIView()
                container.isUserInteractionEnabled = true
                parentView.addSubview(container)
                
                let button = UIButton(type: .system)
                button.setTitle(TUISwift.timCommonLocalizableString("ShowOriginalText"), for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
                button.setTitleColor(TUISwift.tuiTranslationDynamicColor("translation_view_button_text_color", defaultColor: "#147AFF"), for: .normal)
                button.contentHorizontalAlignment = cellData?.direction == .incoming ? .left : .right
                button.isUserInteractionEnabled = true
                button.addTarget(self, action: #selector(onShowOriginalButtonTapped), for: .touchUpInside)
                
                container.addSubview(button)
                
                button.snp.makeConstraints { make in
                    make.edges.equalToSuperview().inset(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
                }
                
                buttonContainer = container
            }
            
            // Layout button container below translation view
            if let buttonContainer = buttonContainer {
                buttonContainer.isHidden = false
                buttonContainer.isUserInteractionEnabled = true
                
                // Ensure parent view has user interaction enabled
                parentView.isUserInteractionEnabled = true
                
                buttonContainer.snp.remakeConstraints { make in
                    make.top.equalTo(self.snp.bottom).offset(2)
                    if cellData?.direction == .incoming {
                        make.leading.equalTo(self)
                    } else {
                        make.trailing.equalTo(self)
                    }
                    make.width.equalTo(self)
                    make.height.equalTo(24)
                }
                
                // Bring button to front
                parentView.bringSubviewToFront(buttonContainer)
                
                // Force layout update
                parentView.setNeedsLayout()
                parentView.layoutIfNeeded()
            }
        } else {
            // Hide button
            buttonContainer?.isHidden = true
        }
    }
    
    func startLoading() {
        if !loadingView.isHidden {
            return
        }
        
        loadingView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
            rotate.toValue = Double.pi * 2.0
            rotate.duration = 1
            rotate.repeatCount = .greatestFiniteMagnitude
            self.loadingView.layer.add(rotate, forKey: "rotationAnimation")
        }
    }
    
    func stopLoading() {
        if loadingView.isHidden {
            return
        }
        loadingView.isHidden = true
        loadingView.layer.removeAllAnimations()
    }
    
    @objc private func onLongPressed(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began, let cellData = cellData else {
            return
        }
        
        let popMenu = TUIChatPopMenu()
        var hasRiskContent = false
        if let msg = cellData.innerMessage {
            let status = TUITranslationDataProvider.getTranslationStatus(msg)
            hasRiskContent = (status == .securityStrike)
        }

        let copy = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Copy"), image: TUISwift.tuiTranslationBundleThemeImage("translation_view_pop_menu_copy_img", defaultImage: "icon_copy"), weight: 1) { [weak self] in
            self?.onCopy(self?.text)
        }
        popMenu.addAction(copy)
        
        let forward = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Forward"), image: TUISwift.tuiTranslationBundleThemeImage("translation_view_pop_menu_forward_img", defaultImage: "icon_forward"), weight: 2) { [weak self] in
            self?.onForward(self?.text)
        }
        if !hasRiskContent {
            popMenu.addAction(forward)
        }
        
        let hide = TUIChatPopMenuAction(title: TUISwift.timCommonLocalizableString("Hide"), image: TUISwift.tuiTranslationBundleThemeImage("translation_view_pop_menu_hide_img", defaultImage: "icon_hide"), weight: 3) { [weak self] in
            self?.onHide(self)
        }
        popMenu.addAction(hide)
        
        if let keyWindow = TUITool.applicationKeywindow() {
            let frame = keyWindow.convert(self.frame, from: superview)
            popMenu.setArrawPosition(CGPoint(x: frame.origin.x + frame.size.width * 0.5, y: frame.origin.y + 66), adjustHeight: 0)
            popMenu.showInView(keyWindow)
        }
    }
    
    private func onCopy(_ text: String?) {
        guard let text = text, !text.isEmpty else {
            return
        }
        UIPasteboard.general.string = text
        TUITool.makeToast(TUISwift.timCommonLocalizableString("Copied"))
    }
    
    private func onForward(_ text: String?) {
        notifyTranslationForward(text)
    }
    
    private func onHide(_ sender: Any?) {
        // Clear visibility state in localCustomData
        if let innerMessage = cellData?.innerMessage {
            TUITranslationDataProvider.clearVisibilityState(innerMessage)
            TUITranslationDataProvider.saveTranslationResult(innerMessage, text: "", status: .hidden)
        }
        
        // Remove button container
        buttonContainer?.removeFromSuperview()
        buttonContainer = nil
        
        cellData?.bottomContainerSize = .zero
        removeFromSuperview()
        notifyTranslationViewHidden()
    }
    
    @objc func onShowOriginalButtonTapped() {
        guard let message = cellData?.innerMessage else {
            return
        }
        
        // Mark that user manually requested to show original text (save to localCustomData)
        TUITranslationDataProvider.setUserRequestedShowOriginal(true, for: message)
        
        // Show original text (enable bilingual mode for this message)
        TUITranslationDataProvider.setShouldHideOriginalText(false, for: message)
        
        // Remove button container
        buttonContainer?.removeFromSuperview()
        buttonContainer = nil
        
        // Recalculate size without button (no more "Show Original" button)
        let translationSize = calcSize(of: .shown)
        cellData?.bottomContainerSize = translationSize
        mm_top(0).mm_left(0).mm_width(translationSize.width).mm_height(translationSize.height)
        
        setNeedsUpdateConstraints()
        updateConstraintsIfNeeded()
        layoutIfNeeded()
        
        // Notify to refresh ONLY this cell (not other messages)
        notifyHeightCacheNeedsInvalidation()
    }
    
    // MARK: - Notify

    private func notifyTranslationViewShown() {
        notifyTranslationChanged()
    }
    
    private func notifyTranslationViewHidden() {
        notifyTranslationChanged()
    }
    
    private func notifyTranslationForward(_ text: String?) {
        let param: [String: Any] = ["TUICore_TUIPluginNotify_WillForwardTextSubKey_Text": text ?? ""]
        TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_WillForwardTextSubKey", object: nil, param: param)
    }
    
    private func notifyTranslationChanged() {
        let param: [String: Any] = ["TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData as Any, "TUICore_TUIPluginNotify_DidChangePluginViewSubKey_VC": self]
        TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey", object: nil, param: param)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.setNeedsUpdateConstraints()
            self.updateConstraintsIfNeeded()
            self.layoutIfNeeded()
        }
    }
    
    /// Notify to invalidate height cache and reload the cell completely
    private func notifyHeightCacheNeedsInvalidation() {
        guard let msgID = cellData?.innerMessage?.msgID else {
            return
        }
        
        // First notify about data change (will trigger height cache invalidation)
        let param: [String: Any] = [
            "TUICore_TUIPluginNotify_DidChangePluginViewSubKey_Data": cellData as Any,
            "TUICore_TUIPluginNotify_DidChangePluginViewSubKey_VC": self,
            "invalidateHeightCache": true  // Custom flag to indicate cache invalidation needed
        ]
        TUICore.notifyEvent("TUICore_TUIPluginNotify", subKey: "TUICore_TUIPluginNotify_DidChangePluginViewSubKey", object: nil, param: param)
    }
}
