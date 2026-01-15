import UIKit
import TIMCommon
import SnapKit
import Photos
import SDWebImage

/// Image preview controller for official account messages
public class TUIOfficialAccountImagePreviewController: UIViewController {
    
    // MARK: - Properties
    
    private var images: [String] = []
    private var currentIndex: Int = 0
    
    // MARK: - UI Components
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.backgroundColor = .black
        // Disable scrolling for single image
        scrollView.isScrollEnabled = false
        return scrollView
    }()
    
    private lazy var pageControl: UIPageControl = {
        let pageControl = UIPageControl()
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.5)
        pageControl.hidesForSinglePage = true
        return pageControl
    }()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(TUISwift.tuiChatCommonBundleImage("video_close"), for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var downloadButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(TUISwift.tuiChatCommonBundleImage("download"), for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        button.layer.cornerRadius = 20
        button.addTarget(self, action: #selector(downloadButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var indexLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private var imageViews: [UIImageView] = []
    
    // MARK: - Initialization
    
    public init(images: [String], currentIndex: Int = 0) {
        self.images = images
        self.currentIndex = currentIndex
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }
    
    public convenience init(imageURL: String) {
        self.init(images: [imageURL], currentIndex: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupImages()
        updateIndexLabel()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateScrollViewLayout()
    }
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .black
        
        view.addSubview(scrollView)
        view.addSubview(closeButton)
        view.addSubview(downloadButton)
        view.addSubview(indexLabel)
        view.addSubview(pageControl)
        
        setupConstraints()
        setupGestures()
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.leading.equalToSuperview().offset(16)
            make.size.equalTo(40)
        }
        
        downloadButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-32)
            make.size.equalTo(40)
        }
        
        indexLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.centerX.equalToSuperview()
        }
        
        pageControl.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-20)
            make.centerX.equalToSuperview()
        }
    }
    
    private func setupGestures() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTapGesture)
        
        tapGesture.require(toFail: doubleTapGesture)
    }
    
    private func setupImages() {
        pageControl.numberOfPages = images.count
        pageControl.currentPage = currentIndex
        
        // Hide index label and page control for single image
        let isSingleImage = images.count <= 1
        indexLabel.isHidden = isSingleImage
        pageControl.isHidden = isSingleImage
        
        for (index, imageURL) in images.enumerated() {
            let containerView = createImageContainer(for: imageURL, at: index)
            scrollView.addSubview(containerView)
        }
    }
    
    private func createImageContainer(for imageURL: String, at index: Int) -> UIView {
        let containerView = UIView()
        
        let scrollView = UIScrollView()
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.tag = index + 100
        containerView.addSubview(scrollView)
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.tag = index
        scrollView.addSubview(imageView)
        
        imageViews.append(imageView)
        
        // Load image
        loadImage(from: imageURL, into: imageView)
        
        return containerView
    }
    
    private func updateScrollViewLayout() {
        let pageWidth = view.bounds.width
        let pageHeight = view.bounds.height
        
        scrollView.contentSize = CGSize(
            width: pageWidth * CGFloat(images.count),
            height: pageHeight
        )
        
        for (index, subview) in scrollView.subviews.enumerated() {
            subview.frame = CGRect(
                x: pageWidth * CGFloat(index),
                y: 0,
                width: pageWidth,
                height: pageHeight
            )
            
            if let zoomScrollView = subview.subviews.first as? UIScrollView {
                zoomScrollView.frame = subview.bounds
                
                if let imageView = zoomScrollView.subviews.first as? UIImageView {
                    imageView.frame = zoomScrollView.bounds
                }
            }
        }
        
        // Scroll to current index
        scrollView.contentOffset = CGPoint(x: pageWidth * CGFloat(currentIndex), y: 0)
    }
    
    // MARK: - Image Loading
    
    private func loadImage(from urlString: String, into imageView: UIImageView) {
        // Set placeholder
        imageView.backgroundColor = UIColor.darkGray
        
        guard let url = URL(string: urlString) else { return }
        
        // Use SDWebImage to load image with WebP support
        imageView.sd_setImage(with: url, placeholderImage: nil) { [weak imageView] image, error, cacheType, url in
            if let error = error {
                print("Failed to load image: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func downloadButtonTapped() {
        guard currentIndex < imageViews.count,
              let image = imageViews[currentIndex].image else {
            return
        }
        
        // Check photo library authorization status
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            saveImageToPhotoLibrary(image)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        self?.saveImageToPhotoLibrary(image)
                    } else {
                        self?.showToast(message: TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
                    }
                }
            }
        case .denied, .restricted:
            showToast(message: TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
        case .limited:
            if #available(iOS 14, *) {
                saveImageToPhotoLibrary(image)
            } else {
                showToast(message: TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
            }
        @unknown default:
            showToast(message: TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
        }
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        // Convert image to JPEG format to ensure compatibility with Photos library
        // This handles WebP and other formats that might not be directly supported
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            showToast(message: TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
            return
        }
        
        guard let convertedImage = UIImage(data: imageData) else {
            showToast(message: TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: convertedImage)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                let message: String
                if success {
                    message = TUISwift.timCommonLocalizableString("TUIKitImageSaved") ?? "Image saved"
                } else {
                    message = error?.localizedDescription ?? (TUISwift.timCommonLocalizableString("TUIKitPictureSavedFailed") ?? "Save failed")
                }
                self?.showToast(message: message)
            }
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let isHidden = closeButton.alpha < 1
        
        UIView.animate(withDuration: 0.25) {
            self.closeButton.alpha = isHidden ? 1 : 0
            self.downloadButton.alpha = isHidden ? 1 : 0
            self.indexLabel.alpha = isHidden ? 1 : 0
            self.pageControl.alpha = isHidden ? 1 : 0
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard currentIndex < scrollView.subviews.count else { return }
        
        let containerView = scrollView.subviews[currentIndex]
        guard let zoomScrollView = containerView.subviews.first as? UIScrollView else { return }
        
        if zoomScrollView.zoomScale > 1 {
            zoomScrollView.setZoomScale(1, animated: true)
        } else {
            let location = gesture.location(in: zoomScrollView)
            let zoomRect = CGRect(
                x: location.x - 50,
                y: location.y - 50,
                width: 100,
                height: 100
            )
            zoomScrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    // MARK: - Helpers
    
    private func updateIndexLabel() {
        indexLabel.text = "\(currentIndex + 1) / \(images.count)"
    }
    
    private func showToast(message: String) {
        let toastLabel = UILabel()
        toastLabel.text = message
        toastLabel.textColor = .white
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toastLabel.textAlignment = .center
        toastLabel.font = UIFont.systemFont(ofSize: 14)
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.alpha = 0
        
        view.addSubview(toastLabel)
        
        toastLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-100)
            make.width.greaterThanOrEqualTo(100)
            make.height.equalTo(36)
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            toastLabel.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.5, options: [], animations: {
                toastLabel.alpha = 0
            }) { _ in
                toastLabel.removeFromSuperview()
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension TUIOfficialAccountImagePreviewController: UIScrollViewDelegate {
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else { return }
        
        let pageWidth = scrollView.bounds.width
        let page = Int((scrollView.contentOffset.x + pageWidth / 2) / pageWidth)
        
        if page != currentIndex && page >= 0 && page < images.count {
            currentIndex = page
            pageControl.currentPage = currentIndex
            updateIndexLabel()
        }
    }
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return scrollView.subviews.first
    }
    
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        guard scrollView != self.scrollView else { return }
        
        guard let imageView = scrollView.subviews.first else { return }
        
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) / 2, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) / 2, 0)
        
        imageView.center = CGPoint(
            x: scrollView.contentSize.width / 2 + offsetX,
            y: scrollView.contentSize.height / 2 + offsetY
        )
    }
}
