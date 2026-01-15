import TIMCommon
import TUICore
import UIKit
import SnapKit

protocol TUIInputBarDelegate_Minimalist: AnyObject {
    func inputBarDidTouchFace(_ textView: TUIInputBar_Minimalist)
    func inputBarDidTouchMore(_ textView: TUIInputBar_Minimalist)
    func inputBarDidTouchCamera(_ textView: TUIInputBar_Minimalist)
    func inputBarDidChangeInputHeight(_ textView: TUIInputBar_Minimalist, offset: CGFloat)
    func inputBarDidSendText(_ textView: TUIInputBar_Minimalist, text: String)
    func inputBarDidSendVoice(_ textView: TUIInputBar_Minimalist, path: String)
    func inputBarDidInputAt(_ textView: TUIInputBar_Minimalist)
    func inputBarDidDeleteAt(_ textView: TUIInputBar_Minimalist, text: String)
    func inputBarDidTouchKeyboard(_ textView: TUIInputBar_Minimalist)
    func inputBarDidDeleteBackward(_ textView: TUIInputBar_Minimalist)
    func inputTextViewShouldBeginTyping(_ textView: UITextView)
    func inputTextViewShouldEndTyping(_ textView: UITextView)
    func inputBarDidTouchAIInterrupt(_ textView: TUIInputBar_Minimalist)
}

extension TUIInputBarDelegate_Minimalist {
    func inputBarDidTouchFace(_ textView: TUIInputBar_Minimalist) {}
    func inputBarDidTouchMore(_ textView: TUIInputBar_Minimalist) {}
    func inputBarDidTouchCamera(_ textView: TUIInputBar_Minimalist) {}
    func inputBarDidChangeInputHeight(_ textView: TUIInputBar_Minimalist, offset: CGFloat) {}
    func inputBarDidSendText(_ textView: TUIInputBar_Minimalist, text: String) {}
    func inputBarDidSendVoice(_ textView: TUIInputBar_Minimalist, path: String) {}
    func inputBarDidInputAt(_ textView: TUIInputBar_Minimalist) {}
    func inputBarDidDeleteAt(_ textView: TUIInputBar_Minimalist, text: String) {}
    func inputBarDidTouchKeyboard(_ textView: TUIInputBar_Minimalist) {}
    func inputBarDidDeleteBackward(_ textView: TUIInputBar_Minimalist) {}
    func inputTextViewShouldBeginTyping(_ textView: UITextView) {}
    func inputTextViewShouldEndTyping(_ textView: UITextView) {}
    func inputBarDidTouchAIInterrupt(_ textView: TUIInputBar_Minimalist) {}
}

class TUIInputBar_Minimalist: UIView, UITextViewDelegate, TUIAudioRecorderDelegate, TUIResponderTextViewDelegate_Minimalist {
    var lineView: UIView
    var micButton: UIButton
    var cameraButton: UIButton
    var keyboardButton: UIButton
    var inputTextView: TUIResponderTextView_Minimalist
    var faceButton: UIButton
    var moreButton: UIButton

    var inputBarTextChanged: ((UITextView) -> Void)?
    var recordStartTime: Date?
    var recordTimer: Timer?
    var isFocusOn: Bool = false
    var sendTypingStatusTimer: Timer?
    var allowSendTypingStatusByChangeWord: Bool = true
    weak var delegate: TUIInputBarDelegate_Minimalist?
    
    // Voice recording related properties
    private var currentRecordingPath: String?
    private var recordingDuration: Int = 0
    
    // MARK: - AI Conversation Properties
    private var aiStyleEnabled: Bool = false
    var aiIsTyping: Bool = false
    
    /// AI chat style
    public var inputBarStyle: TUIInputBarStyle_Minimalist = .default
    
    /// AI chat state
    public var aiState: TUIInputBarAIState_Minimalist = .default
    
    /// AI interrupt button
    public var aiInterruptButton: UIButton!
    
    /// AI send button  
    public var aiSendButton: UIButton!

    lazy var recorder: TUIAudioRecorder = {
        let recorder = TUIAudioRecorder()
        recorder.delegate = self
        return recorder
    }()

    private var _recordView: TUIRecordView?
    var recordView: TUIRecordView? {
        get {
            if _recordView == nil {
                _recordView = TUIRecordView()
                _recordView?.frame = frame
            }
            return _recordView!
        }
        set {
            _recordView = newValue
        }
    }

    let normalFont: UIFont = .systemFont(ofSize: 16)
    let normalColor: UIColor = TUISwift.tuiChatDynamicColor("chat_input_text_color", defaultColor: "#000000")

    // MARK: - Init

    override init(frame: CGRect) {
        lineView = UIView()
        moreButton = UIButton()
        inputTextView = TUIResponderTextView_Minimalist()
        keyboardButton = UIButton()
        faceButton = UIButton()
        micButton = UIButton()
        cameraButton = UIButton()

        aiInterruptButton = UIButton(type: .custom)
        aiSendButton = UIButton(type: .custom)

        super.init(frame: frame)

        setupViews()
        setupAIButtons()
        defaultLayout()

        NotificationCenter.default.addObserver(self, selector: #selector(onThemeChanged), name: Notification.Name("TUIDidApplyingThemeChangedNotfication"), object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        sendTypingStatusTimer?.invalidate()
        sendTypingStatusTimer = nil
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Views and layout

    func setupViews() {
        backgroundColor = TUISwift.rgba(255, g: 255, b: 255, a: 1)

        lineView.backgroundColor = TUISwift.timCommonDynamicColor("separator_color", defaultColor: "#FFFFFF")

        moreButton.addTarget(self, action: #selector(clickMoreBtn(_:)), for: .touchUpInside)
        moreButton.setImage(getImageFromCache("TypeSelectorBtnHL_Black"), for: .normal)
        moreButton.setImage(getImageFromCache("TypeSelectorBtnHL_Black"), for: .highlighted)
        addSubview(moreButton)

        inputTextView.delegate = self
        inputTextView.font = normalFont
        inputTextView.backgroundColor = TUISwift.tuiChatDynamicColor("chat_input_bg_color", defaultColor: "#FFFFFF")
        inputTextView.textColor = TUISwift.tuiChatDynamicColor("chat_input_text_color", defaultColor: "#000000")
        inputTextView.textContainerInset = rtlEdgeInsetsWithInsets(UIEdgeInsets(top: TUISwift.kScale390(9), left: TUISwift.kScale390(16), bottom: TUISwift.kScale390(9), right: TUISwift.kScale390(30)))
        inputTextView.textAlignment = TUISwift.isRTL() ? .right : .left
        inputTextView.returnKeyType = .send
        addSubview(inputTextView)

        keyboardButton.addTarget(self, action: #selector(clickKeyboardBtn(_:)), for: .touchUpInside)
        keyboardButton.setImage(TUISwift.tuiChatBundleThemeImage("chat_ToolViewKeyboard_img", defaultImage: "ToolViewKeyboard"), for: .normal)
        keyboardButton.setImage(TUISwift.tuiChatBundleThemeImage("chat_ToolViewKeyboardHL_img", defaultImage: "ToolViewKeyboardHL"), for: .highlighted)
        keyboardButton.isHidden = true
        addSubview(keyboardButton)

        faceButton.addTarget(self, action: #selector(clickFaceBtn(_:)), for: .touchUpInside)
        faceButton.setImage(getImageFromCache("ToolViewEmotion"), for: .normal)
        faceButton.setImage(getImageFromCache("ToolViewEmotion"), for: .highlighted)
        addSubview(faceButton)

        micButton.addTarget(self, action: #selector(recordBtnDown(_:)), for: .touchDown)
        micButton.addTarget(self, action: #selector(recordBtnUp(_:)), for: .touchUpInside)
        micButton.addTarget(self, action: #selector(recordBtnCancel(_:)), for: [.touchUpOutside, .touchCancel])
        micButton.addTarget(self, action: #selector(recordBtnDragExit(_:)), for: .touchDragExit)
        micButton.addTarget(self, action: #selector(recordBtnDragEnter(_:)), for: .touchDragEnter)
        micButton.addTarget(self, action: #selector(recordBtnDrag(_:event:)), for: .touchDragInside)
        micButton.addTarget(self, action: #selector(recordBtnDrag(_:event:)), for: .touchDragOutside)
        micButton.setImage(getImageFromCache("ToolViewInputVoice"), for: .normal)
        addSubview(micButton)

        cameraButton.addTarget(self, action: #selector(clickCameraBtn(_:)), for: .touchUpInside)
        cameraButton.setImage(getImageFromCache("ToolViewInputCamera"), for: .normal)
        cameraButton.setImage(getImageFromCache("ToolViewInputCamera"), for: .highlighted)
        addSubview(cameraButton)
    }

    func defaultLayout() {
        lineView.frame = CGRect(x: 0, y: 0, width: TUISwift.screen_Width(), height: TUISwift.tLine_Height())

        if inputBarStyle == .ai {
            layoutAIStyle()
        } else {
            layoutDefaultStyle()
        }
    }
    
    private func layoutDefaultStyle() {
        let iconSize: CGFloat = 24
        moreButton.frame = CGRect(x: TUISwift.kScale390(16), y: TUISwift.kScale390(13), width: iconSize, height: iconSize)
        cameraButton.frame = CGRect(x: TUISwift.screen_Width() - TUISwift.kScale390(16) - iconSize, y: 13, width: iconSize, height: iconSize)
        micButton.frame = CGRect(x: TUISwift.screen_Width() - TUISwift.kScale390(56) - iconSize, y: 13, width: iconSize, height: iconSize)

        let faceSize: CGFloat = 19
        faceButton.frame = CGRect(x: micButton.frame.minX - TUISwift.kScale390(50), y: 15, width: faceSize, height: faceSize)

        keyboardButton.frame = faceButton.frame
        inputTextView.frame = CGRect(x: TUISwift.kScale390(56), y: 7, width: TUISwift.screen_Width() - TUISwift.kScale390(152), height: 36)

        applyBorderTheme()

        if TUISwift.isRTL() {
            for subview in subviews {
                subview.resetFrameToFitRTL()
            }
        }
        
        // Hide AI buttons
        aiInterruptButton.isHidden = true
    }

    func layoutButton(_ height: CGFloat) {
        var frame = frame
        let offset = height - frame.size.height
        frame.size.height = height
        self.frame = frame

        delegate?.inputBarDidChangeInputHeight(self, offset: offset)
    }

    @objc func onThemeChanged() {
        applyBorderTheme()
    }

    func applyBorderTheme() {
        inputTextView.layer.masksToBounds = true
        inputTextView.layer.cornerRadius = inputTextView.frame.height / 2.0
        inputTextView.layer.borderWidth = 0.5
        inputTextView.layer.borderColor = TUISwift.rgba(221, g: 221, b: 221, a: 1).cgColor
    }

    func getImageFromCache(_ path: String) -> UIImage {
        return TUIImageCache.sharedInstance().getResourceFromCache(TUISwift.tuiChatImagePath_Minimalist(path)) ?? UIImage()
    }

    func getStickerFromCache(_ path: String) -> UIImage {
        return TUIImageCache.sharedInstance().getFaceFromCache(path) ?? UIImage()
    }

    // MARK: - Button events

    @objc func clickCameraBtn(_ sender: UIButton) {
        micButton.isHidden = false
        keyboardButton.isHidden = true
        inputTextView.isHidden = false
        faceButton.isHidden = false
        delegate?.inputBarDidTouchCamera(self)
    }

    @objc func clickKeyboardBtn(_ sender: UIButton) {
        micButton.isHidden = false
        keyboardButton.isHidden = true
        inputTextView.isHidden = false
        faceButton.isHidden = false
        layoutButton(inputTextView.frame.height + CGFloat(2 * TTextView_Margin))
        delegate?.inputBarDidTouchKeyboard(self)
    }

    @objc func clickFaceBtn(_ sender: UIButton) {
        micButton.isHidden = false
        faceButton.isHidden = true
        keyboardButton.isHidden = false
        inputTextView.isHidden = false
        delegate?.inputBarDidTouchFace(self)
        keyboardButton.frame = faceButton.frame
    }

    @objc func clickMoreBtn(_ sender: UIButton) {
        delegate?.inputBarDidTouchMore(self)
    }

    @objc func recordBtnDown(_ sender: UIButton) {
        // Dismiss keyboard first
        inputTextView.resignFirstResponder()
        recorder.record()
    }

    @objc func recordBtnUp(_ sender: UIButton) {
        handleRecordingEnd()
    }

    @objc func recordBtnCancel(_ gesture: UIGestureRecognizer) {
        handleRecordingEnd()
    }
    
    // Handle recording end (called by both touchUpInside and touchCancel)
    private func handleRecordingEnd() {
        let interval = Date().timeIntervalSince(recordStartTime ?? Date())
        let currentZone = recordView?.currentZone ?? .normal
        
        // Check recording duration
        if interval < 1 {
            recorder.cancel()
            // Show toast immediately
            recordView?.showCustomToast(TUISwift.timCommonLocalizableString("TUIKitInputRecordTimeshort"))
            // Hide record view immediately with animation
            recordView?.hideWithAnimation {
                self.recordView?.removeFromSuperview()
                self.recordView = nil
            }
            return
        }
        
        if interval > min(59, TUIChatConfig.shared.maxAudioRecordDuration) {
            recorder.cancel()
            // Show toast immediately
            recordView?.showCustomToast(TUISwift.timCommonLocalizableString("TUIKitInputRecordTimeLong"))
            // Hide record view immediately with animation
            recordView?.hideWithAnimation {
                self.recordView?.removeFromSuperview()
                self.recordView = nil
            }
            return
        }
        
        // Stop recording
        recorder.stop()
        currentRecordingPath = recorder.recordedFilePath
        recordingDuration = Int(interval)
        
        // Handle based on zone
        switch currentZone {
        case .cancel:
            // Cancel recording - hide view
            if _recordView != nil {
                recordView?.hideWithAnimation {
                    self.recordView?.removeFromSuperview()
                    self.recordView = nil
                }
            }
            handleCancelRecording()
            
        case .normal:
            // Send voice directly - hide view
            if _recordView != nil {
                recordView?.hideWithAnimation {
                    self.recordView?.removeFromSuperview()
                    self.recordView = nil
                }
            }
            sendVoiceMessageDirectly()
            
        case .toText:
            // Convert to text - DON'T hide view, enter text processing state
            startVoiceToTextConversion()
        }
    }

    @objc func recordBtnDragExit(_ sender: UIButton) {
    }

    @objc func recordBtnDragEnter(_ sender: UIButton) {
    }
    
    @objc func recordBtnDrag(_ sender: UIButton, event: UIEvent) {
        guard let touch = event.allTouches?.first else { return }
        let touchPoint = touch.location(in: window)
        recordView?.updateZone(touchPoint: touchPoint)
    }

    // MARK: - UITextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
        if inputBarStyle == .default {
            keyboardButton.isHidden = true
            micButton.isHidden = false
            faceButton.isHidden = false
        }

        isFocusOn = true
        allowSendTypingStatusByChangeWord = true

        sendTypingStatusTimer = Timer.tui_scheduledTimer(withTimeInterval: 4, repeats: true, block: { [weak self] _ in
            guard let self = self else { return }
            self.allowSendTypingStatusByChangeWord = true
        })

        if isFocusOn && textView.textStorage.tui_getPlainString().count > 0 {
            delegate?.inputTextViewShouldBeginTyping(textView)
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        isFocusOn = false
        delegate?.inputTextViewShouldEndTyping(textView)
    }

    func textViewDidChange(_ textView: UITextView) {
        if allowSendTypingStatusByChangeWord && isFocusOn && textView.textStorage.tui_getPlainString().count > 0 {
            delegate?.inputTextViewShouldBeginTyping(textView)
        }

        // AI style: state switching logic
        if inputBarStyle == .ai {
            if aiIsTyping {
                // When AI is typing, always stay in active state
                setAIState(.active)
            } else {
                // When AI is not typing, decide based on user input state
                if textView.textStorage.tui_getPlainString().count > 0 {
                    setAIState(.active)
                } else {
                    setAIState(.default)
                }
            }
        }

        if isFocusOn && textView.textStorage.tui_getPlainString().count == 0 {
            delegate?.inputTextViewShouldEndTyping(textView)
        }
        if let inputBarTextChanged = inputBarTextChanged {
            inputBarTextChanged(inputTextView)
        }
        let size = inputTextView.sizeThatFits(CGSize(width: inputTextView.frame.width, height: CGFloat(TTextView_TextView_Height_Max)))
        let oldHeight = inputTextView.frame.height
        var newHeight = size.height

        if newHeight > Double(TTextView_TextView_Height_Max) {
            newHeight = Double(TTextView_TextView_Height_Max)
        }
        if newHeight < TUISwift.tTextView_TextView_Height_Min() {
            newHeight = TUISwift.tTextView_TextView_Height_Min()
        }
        if oldHeight == newHeight {
            return
        }

        UIView.animate(withDuration: 0.3) {
            var textFrame = self.inputTextView.frame
            textFrame.size.height += newHeight - oldHeight
            self.inputTextView.frame = textFrame
            
            // Update layout for AI style
            if self.inputBarStyle == .ai {
                self.layoutAIStyle()
            }
            
            self.layoutButton(newHeight + CGFloat(2 * TTextView_Margin))
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text.tui_contains("[") && text.tui_contains("]") {
            let selectedRange = textView.selectedRange
            if selectedRange.length > 0 {
                textView.textStorage.deleteCharacters(in: selectedRange)
            }
            var locations: [[NSValue: NSAttributedString]]? = nil
            let textChange = text.getAdvancedFormatEmojiString(withFont: normalFont, textColor: normalColor, emojiLocations: &locations)
            textView.textStorage.insert(textChange, at: textView.textStorage.length)
            DispatchQueue.main.async {
                self.inputTextView.selectedRange = NSRange(location: self.inputTextView.textStorage.length + 1, length: 0)
            }
            return false
        }

        if text == "\n" {
            let sp = textView.textStorage.tui_getPlainString().trimmingCharacters(in: .whitespaces)
            if sp.count == 0 {
                let ac = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitInputBlankMessageTitle"), message: nil, preferredStyle: .alert)
                ac.tuitheme_addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default, handler: nil))
                mm_viewController?.present(ac, animated: true, completion: nil)
            } else {
                delegate?.inputBarDidSendText(self, text: textView.textStorage.tui_getPlainString())
                clearInput()
            }
            return false
        } else if text == "" {
            if textView.textStorage.length > range.location {
                // Delete the @ message like @xxx at one time
                let lastAttributedStr = textView.textStorage.attributedSubstring(from: NSRange(location: range.location, length: 1))
                let lastStr = lastAttributedStr.tui_getPlainString()
                if lastStr.count > 0, lastStr.first == " " {
                    var location = range.location
                    var length = range.length

                    // @ ASCII
                    let at = 64
                    // space ASCII
                    let space = 32

                    while location != 0 {
                        location -= 1
                        length += 1
                        // Convert characters to ascii code, copy to int, avoid out of bounds
                        if let firstChar = textView.textStorage.attributedSubstring(from: NSRange(location: location, length: 1)).tui_getPlainString().first {
                            if let firstCharAscii = firstChar.asciiValue {
                                if firstCharAscii == at {
                                    let atText = textView.textStorage.attributedSubstring(from: NSRange(location: location, length: length)).tui_getPlainString()
                                    let textFont = normalFont
                                    let spaceString = NSAttributedString(string: "", attributes: [NSAttributedString.Key.font: textFont])
                                    textView.textStorage.replaceCharacters(in: NSRange(location: location, length: length), with: spaceString)
                                    delegate?.inputBarDidDeleteAt(self, text: atText)
                                    return false
                                } else if firstCharAscii == space {
                                    // Avoid "@nickname Hello, nice to meet you (space) "" Press del after a space to over-delete to @
                                    break
                                }
                            }
                        }
                    }
                }
            }
        }
        // Monitor the input of @ character, including full-width/half-width
        else if text == "@" || text == "＠" {
            delegate?.inputBarDidInputAt(self)
            return false
        }
        return true
    }

    // MARK: - TUIResponderTextViewDelegate

    func onDeleteBackward(_ textView: TUIResponderTextView_Minimalist) {
        delegate?.inputBarDidDeleteBackward(self)
    }

    // MARK: - TUIAudioRecorderDelegate

    func didCheckPermission(_ recorder: TUIAudioRecorder, _ isGranted: Bool, _ isFirstTime: Bool) {
        if isFirstTime {
            if !isGranted {
                showRequestMicAuthorizationAlert()
            }
            return
        }
        updateViewsToRecordingStatus()
    }
    
    func updateViewsToRecordingStatus() {
        guard let window = window, let recordView = recordView else { return }

        window.addSubview(recordView)
        recordView.snp.remakeConstraints { make in
            make.center.equalTo(window)
            make.width.height.equalTo(window)
        }
        
        // Show with fade-in animation
        recordView.showWithAnimation()

        recordStartTime = Date()
        recordView.setStatus(.recording)
        showHapticFeedback()
    }

    func showRequestMicAuthorizationAlert() {
        let ac = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitInputNoMicTitle"),
                                   message: TUISwift.timCommonLocalizableString("TUIKitInputNoMicTips"),
                                   preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitInputNoMicOperateLater"),
                                   style: .cancel,
                                   handler: nil))
        ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("TUIKitInputNoMicOperateEnable"),
                                   style: .default,
                                   handler: { _ in
                                       let app = UIApplication.shared
                                       if let settingsURL = URL(string: UIApplication.openSettingsURLString), app.canOpenURL(settingsURL) {
                                           app.open(settingsURL)
                                       }
                                   }))
        DispatchQueue.main.async {
            self.mm_viewController?.present(ac, animated: true, completion: nil)
        }
    }

    func showHapticFeedback() {
        if #available(iOS 10.0, *) {
            DispatchQueue.main.async {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            }
        } else {
            // Fallback on earlier versions
        }
    }

    func didRecordTimeChanged(_ recorder: TUIAudioRecorder, _ time: TimeInterval) {
        let uiMaxDuration = min(59, TUIChatConfig.shared.maxAudioRecordDuration)
        let realMaxDuration = uiMaxDuration + 0.7
        
        // Update recording time and countdown warning in recordView
        recordView?.updateRecordingTime(time, maxDuration: uiMaxDuration)

        if time > realMaxDuration {
            recorder.stop()
            let path = recorder.recordedFilePath
            recordView?.setStatus(.tooLong)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.recordView?.removeFromSuperview()
                self?.recordView = nil
            }

            delegate?.inputBarDidSendVoice(self, path: path)
        }
    }

    // MARK: - Other

    func clearInput() {
        inputTextView.textStorage.deleteCharacters(in: NSRange(location: 0, length: inputTextView.textStorage.length))
        textViewDidChange(inputTextView)
    }

    func getInput() -> String {
        return inputTextView.textStorage.tui_getPlainString()
    }

    func addEmoji(_ emoji: TUIFaceCellData) {
        // Create emoji attachment
        let emojiTextAttachment = TUIEmojiTextAttachment()
        emojiTextAttachment.faceCellData = emoji

        // Set tag and image
        emojiTextAttachment.emojiTag = emoji.name
        emojiTextAttachment.image = getStickerFromCache(emoji.path ?? "")

        // Set emoji size
        emojiTextAttachment.emojiSize = kTIMDefaultEmojiSize
        let str = NSAttributedString(attachment: emojiTextAttachment)

        let selectedRange = inputTextView.selectedRange
        if selectedRange.length > 0 {
            inputTextView.textStorage.deleteCharacters(in: selectedRange)
        }
        // Insert emoji image
        inputTextView.textStorage.insert(str, at: inputTextView.selectedRange.location)

        inputTextView.selectedRange = NSRange(location: inputTextView.selectedRange.location + 1, length: 0)
        resetTextStyle()

        if inputTextView.contentSize.height > CGFloat(TTextView_TextView_Height_Max) {
            let offset = inputTextView.contentSize.height - inputTextView.frame.size.height
            inputTextView.scrollRectToVisible(CGRect(x: 0, y: offset, width: inputTextView.frame.size.width, height: inputTextView.frame.size.height), animated: true)
        }
        textViewDidChange(inputTextView)
    }

    func resetTextStyle() {
        // After changing text selection, should reset style.
        let wholeRange = NSRange(location: 0, length: inputTextView.textStorage.length)
        inputTextView.textStorage.removeAttribute(.font, range: wholeRange)
        inputTextView.textStorage.removeAttribute(.foregroundColor, range: wholeRange)
        inputTextView.textStorage.addAttribute(.foregroundColor, value: normalColor, range: wholeRange)
        inputTextView.textStorage.addAttribute(.font, value: normalFont, range: wholeRange)
        inputTextView.font = normalFont
        inputTextView.textAlignment = TUISwift.isRTL() ? .right : .left
    }

    func backDelete() {
        if inputTextView.textStorage.length > 0 {
            inputTextView.textStorage.deleteCharacters(in: NSRange(location: inputTextView.textStorage.length - 1, length: 1))
            textViewDidChange(inputTextView)
        }
    }

    func updateTextViewFrame() {
        textViewDidChange(UITextView())
    }

    func changeToKeyboard() {
        clickKeyboardBtn(keyboardButton)
    }

    func addDraftToInputBar(_ draft: NSAttributedString) {
        addWordsToInputBar(draft)
    }

    func addWordsToInputBar(_ words: NSAttributedString) {
        let selectedRange = inputTextView.selectedRange
        if selectedRange.length > 0 {
            inputTextView.textStorage.deleteCharacters(in: selectedRange)
        }
        // Insert words
        inputTextView.textStorage.insert(words, at: inputTextView.selectedRange.location)
        inputTextView.selectedRange = NSRange(location: inputTextView.textStorage.length + 1, length: 0)
        resetTextStyle()
        updateTextViewFrame()
    }
    
    // MARK: - AI Conversation Methods
    
    /// Enable or disable AI conversation style
    func enableAIStyle(_ enable: Bool) {
        aiStyleEnabled = enable
    }
    
    /// Set input bar style
    func setInputBarStyle(_ style: TUIInputBarStyle_Minimalist) {
        inputBarStyle = style
        defaultLayout()
    }
    
    /// Set AI state
    func setAIState(_ state: TUIInputBarAIState_Minimalist) {
        aiState = state
        if inputBarStyle == .ai {
            layoutAIStyle()
        }
    }
    
    /// Set AI typing state with auto state management
    func setAITyping(_ typing: Bool) {
        print("setAITyping: \(typing)")
        aiIsTyping = typing
        if inputBarStyle == .ai {
            layoutAIStyle()
        }
    }
    
    private func layoutAIStyle() {
        // Hide default buttons
        moreButton.isHidden = true
        cameraButton.isHidden = true
        micButton.isHidden = true
        faceButton.isHidden = true
        keyboardButton.isHidden = true
        
        if aiIsTyping {
            // Show interrupt button inside the input box (right side)
            let buttonSize: CGFloat = 24
            let buttonMargin: CGFloat = 8
            aiInterruptButton.frame = CGRect(
                x: TUISwift.screen_Width() - TUISwift.kScale390(16) - buttonMargin - buttonSize,
                y: 7 + (36 - buttonSize) / 2,
                width: buttonSize,
                height: buttonSize
            )
            aiInterruptButton.isHidden = false
            
            // Use full width input box but adjust text container inset to avoid button
            inputTextView.frame = CGRect(x: TUISwift.kScale390(16), y: 7, width: TUISwift.screen_Width() - TUISwift.kScale390(32), height: 36)
            let ei = UIEdgeInsets(
                top: TUISwift.kScale390(9),
                left: TUISwift.kScale390(16),
                bottom: TUISwift.kScale390(9),
                right: buttonSize + buttonMargin * 2
            )
            inputTextView.textContainerInset = rtlEdgeInsetsWithInsets(ei)
        } else {
            // Hide interrupt button when AI is not typing
            aiInterruptButton.isHidden = true
            
            // Use full width input box with normal padding
            inputTextView.frame = CGRect(x: TUISwift.kScale390(16), y: 7, width: TUISwift.screen_Width() - TUISwift.kScale390(32), height: 36)
            let ei = UIEdgeInsets(
                top: TUISwift.kScale390(9),
                left: TUISwift.kScale390(16),
                bottom: TUISwift.kScale390(9),
                right: TUISwift.kScale390(30)
            )
            inputTextView.textContainerInset = rtlEdgeInsetsWithInsets(ei)
        }
        
        if TUISwift.isRTL() {
            for subview in subviews {
                subview.resetFrameToFitRTL()
            }
        }
    }
    
    // MARK: - AI Setup Methods
    
    private func setupAIButtons() {
        // AI interrupt button - designed to be placed inside input box
        aiInterruptButton.setBackgroundImage(TUISwift.tuiChatBundleThemeImage("",defaultImage: "chat_ai_interrupt_icon_white"), for: .normal)
        aiInterruptButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        aiInterruptButton.layer.cornerRadius = 12
        aiInterruptButton.layer.masksToBounds = true
        aiInterruptButton.addTarget(self, action: #selector(onAIInterruptButtonClicked), for: .touchUpInside)
        aiInterruptButton.isHidden = true
        addSubview(aiInterruptButton)
        
        // Remove AI send button - not needed for minimalist style
        // aiSendButton is no longer used in minimalist design
    }
    


    
    // MARK: - AI Button Actions
    
    @objc private func onAIInterruptButtonClicked() {
        delegate?.inputBarDidTouchAIInterrupt(self)
    }
    
    // MARK: - Voice to Text Methods
    
    private func handleCancelRecording() {
        currentRecordingPath = nil
        recorder.cancel()
    }
    
    private func sendVoiceMessageDirectly() {
        guard let path = currentRecordingPath else { return }
        delegate?.inputBarDidSendVoice(self, path: path)
        currentRecordingPath = nil
    }
    
    private func startVoiceToTextConversion() {
        guard let recordPath = currentRecordingPath else { return }
        
        // Don't hide recordView, instead enter text processing state
        recordView?.enterTextProcessingState()
        
        // Setup callbacks for the three buttons
        recordView?.onSendVoice = { [weak self] in
            guard let self = self else { return }
            // Send original voice
            self.recordView?.hideWithAnimation {
                self.recordView?.removeFromSuperview()
                self.recordView = nil
            }
            self.sendVoiceMessageDirectly()
        }
        
        recordView?.onSendText = { [weak self] in
            guard let self = self else { return }
            // Send converted text
            let text = self.recordView?.getConvertedText() ?? ""
            self.recordView?.hideWithAnimation {
                self.recordView?.removeFromSuperview()
                self.recordView = nil
            }
            // Send text message
            if !text.isEmpty {
                self.delegate?.inputBarDidSendText(self, text: text)
            }
        }
        
        recordView?.onCancelSend = { [weak self] in
            guard let self = self else { return }
            // Cancel - just hide and cleanup
            self.recordView?.hideWithAnimation {
                self.recordView?.removeFromSuperview()
                self.recordView = nil
            }
            self.currentRecordingPath = nil
        }
        
        // Use TUIAIMediaProcessManager for voice to text conversion
        TUIAIMediaProcessManager.shared.processVoiceToText(
            filePath: recordPath,
            progressCallback: { result in
                switch result {
                case .uploadSuccess(let url):
                    print(" Upload successful, URL: \(url)")
                case .voiceToTextSuccess(let text):
                    print(" Voice to text successful: \(text)")
                case .translationSuccess(let text):
                    print(" Translation successful: \(text)")
                case .failure(let code, let message):
                    print(" Process failed: code=\(code), message=\(message ?? "unknown")")
                }
            },
            completion: { [weak self] result in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    switch result {
                    case .success(let text):
                        self.recordView?.setConvertLocalVoiceToTextState(.success, text: text)
                        print(" Voice to text successful: \(text)")
                    case .failure(let error):
                        self.recordView?.setConvertLocalVoiceToTextState(.failure, error: error)
                        print(" Voice to text failed: \(error.localizedDescription)")
                    }
                }
            }
        )
    }
}
