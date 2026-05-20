import AVFoundation
import Photos
import UIKit
import AlbumPicker
import TIMCommon

class TUIAlbumPickerMediaSendManager {

    static let shared = TUIAlbumPickerMediaSendManager()
    private init() {}

    private static let kMaxImageSizeBytes = 28 * 1024 * 1024
    private static let kMaxGIFSizeBytes = 10 * 1024 * 1024
    private static let kMaxVideoSizeBytes = 100 * 1024 * 1024
    private static let kThumbnailSize = CGSize(width: 320, height: 320)

    private var pickerSessions: [ObjectIdentifier: PickerSession] = [:]
    private var mediaToSession: [UInt64: ObjectIdentifier] = [:]

    // MARK: - Public API

    func pickAlbumMedia(from presentingVC: UIViewController, listener: TUIChatMediaDataListener, conversationID: String?) {
        let albumVC = TUIAlbumPickerViewController()
        albumVC.modalPresentationStyle = .fullScreen

        let sessionKey = ObjectIdentifier(albumVC)
        let session = PickerSession(albumVC: albumVC, listener: listener, conversationID: conversationID)
        pickerSessions[sessionKey] = session

        albumVC.onPickConfirmHandler = { [weak self, weak albumVC] medias, _ in
            guard let self = self, let albumVC = albumVC else { return }
            let key = ObjectIdentifier(albumVC)
            self.dismissAlbumPicker(albumVC)
            self.createPlaceholdersForAllMedia(medias, sessionKey: key)
        }

        albumVC.onMediaProcessingHandler = { [weak self, weak albumVC] media, progress, error in
            guard let self = self, !error, let albumVC = albumVC else { return }
            let key = ObjectIdentifier(albumVC)
            DispatchQueue.main.async {
                self.mediaToSession[media.id] = key
                self.handleMediaProcessing(media: media, progress: progress, sessionKey: key)
            }
        }

        albumVC.onCancelHandler = { [weak self, weak albumVC] in
            guard let self = self, let albumVC = albumVC else { return }
            self.dismissAlbumPicker(albumVC) {
                self.pickerSessions.removeValue(forKey: ObjectIdentifier(albumVC))
            }
        }

        albumVC.onMediaProcessedHandler = { [weak self, weak albumVC] in
            guard let self = self, let albumVC = albumVC else { return }
            self.pickerSessions.removeValue(forKey: ObjectIdentifier(albumVC))
        }

        presentingVC.present(albumVC, animated: true, completion: nil)
    }

    func restorePlaceholders(via listener: TUIChatMediaDataListener, conversationID: String) {
        for (_, session) in pickerSessions {
            guard session.conversationID == conversationID else { continue }
            session.listener = listener

            for mediaId in session.mediaOrder {
                guard let state = session.mediaStates[mediaId], state.progress < 1.0 else { continue }
                restoreSinglePlaceholder(state: state, listener: listener)
            }
        }
    }
}

// MARK: - Internal Implementation

extension TUIAlbumPickerMediaSendManager {
    private func createPlaceholdersForAllMedia(_ medias: [AlbumMedia], sessionKey: ObjectIdentifier) {
        guard let session = pickerSessions[sessionKey], let listener = session.listener else { return }

        for media in medias {
            let state = MediaState()
            state.mediaType = media.mediaType
            state.asset = media.asset
            state.placeholderCreating = true
            session.mediaStates[media.id] = state
            session.mediaOrder.append(media.id)
            mediaToSession[media.id] = sessionKey
        }

        createPlaceholdersSequentially(index: 0, medias: medias, sessionKey: sessionKey, listener: listener)
    }

    private func createPlaceholdersSequentially(index: Int, medias: [AlbumMedia],
                                                sessionKey: ObjectIdentifier, listener: TUIChatMediaDataListener)
    {
        guard index < medias.count else { return }
        let media = medias[index]
        guard let session = pickerSessions[sessionKey], let state = session.mediaStates[media.id] else { return }

        requestThumbnail(for: media.asset, mediaId: media.id) { thumbImage, snapshotPath in
            state.thumbnailPath = snapshotPath
            listener.onProvidePlaceholderVideoSnapshot(snapshotPath, snapImage: thumbImage) { _, cellData in
                state.placeholder = cellData
                cellData.videoTranscodingProgress = CGFloat(state.progress)
            }
            self.createPlaceholdersSequentially(index: index + 1, medias: medias, sessionKey: sessionKey, listener: listener)
        }
    }

    private func requestThumbnail(for asset: PHAsset?, mediaId: UInt64, completion: @escaping (UIImage, String) -> Void) {
        guard let asset = asset else {
            DispatchQueue.main.async { completion(Self.placeholderImage(), "") }
            return
        }
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: Self.kThumbnailSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            let thumbImage = image ?? Self.placeholderImage()
            DispatchQueue.global(qos: .userInitiated).async {
                let snapshotPath = self.saveThumbnail(thumbImage, mediaId: mediaId)
                DispatchQueue.main.async {
                    completion(thumbImage, snapshotPath)
                }
            }
        }
    }

    private static func placeholderImage() -> UIImage {
        let size = kThumbnailSize
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        UIColor.lightGray.setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }

    private func saveThumbnail(_ image: UIImage, mediaId: UInt64) -> String {
        let name = "\(TUITool.genSnapshotName(nil) ?? "")_\(mediaId).jpg"
        let path = "\(TUISwift.tuiKit_Video_Path())\(name)"
        FileManager.default.createFile(atPath: path, contents: image.jpegData(compressionQuality: 0.6), attributes: nil)
        return path
    }

    private func restoreSinglePlaceholder(state: MediaState, listener: TUIChatMediaDataListener) {
        guard let thumbnailPath = state.thumbnailPath else { return }
        let thumbImage = UIImage(contentsOfFile: thumbnailPath) ?? UIImage()

        state.placeholder = nil
        state.placeholderCreating = true

        listener.onProvidePlaceholderVideoSnapshot(thumbnailPath, snapImage: thumbImage) { _, cellData in
            state.placeholder = cellData
            cellData.videoTranscodingProgress = CGFloat(state.progress)
        }
    }

    // MARK: Media Processing

    private func handleMediaProcessing(media: AlbumMedia, progress: Float, sessionKey: ObjectIdentifier) {
        switch media.mediaType {
        case .image:
            handleImageProcessing(media: media, progress: progress, sessionKey: sessionKey)
        case .video:
            handleVideoProcessing(media: media, progress: progress, sessionKey: sessionKey)
        @unknown default:
            break
        }
    }

    private func handleImageProcessing(media: AlbumMedia, progress: Float, sessionKey: ObjectIdentifier) {
        guard progress >= 1.0, let path = media.mediaPath else { return }
        guard let session = pickerSessions[sessionKey], let listener = session.listener else { return }
        let state = session.mediaStates[media.id]

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int) ?? 0
        let isGIF = path.lowercased().hasSuffix(".gif")
        let maxSize = isGIF ? Self.kMaxGIFSizeBytes : Self.kMaxImageSizeBytes
        if fileSize > maxSize {
            listener.onProvideImageError(TUISwift.timCommonLocalizableString("TUIKitImageSizeCheckLimited"))
            cleanupMedia(mediaId: media.id)
            return
        }

        listener.onProvideImage(path, placeHolderCellData: state?.placeholder)
        cleanupMedia(mediaId: media.id)
    }

    private func handleVideoProcessing(media: AlbumMedia, progress: Float, sessionKey: ObjectIdentifier) {
        guard let session = pickerSessions[sessionKey] else { return }
        guard let listener = session.listener else { return }

        let state = session.mediaStates[media.id] ?? MediaState()
        state.progress = progress
        session.mediaStates[media.id] = state

        createPlaceholderIfNeeded(media: media, state: state, listener: listener)
        state.placeholder?.videoTranscodingProgress = CGFloat(progress)

        if progress >= 1.0, let videoPath = media.mediaPath {
            sendVideo(media: media, videoPath: videoPath, state: state, listener: listener)
        }
    }

    private func createPlaceholderIfNeeded(media: AlbumMedia, state: MediaState, listener: TUIChatMediaDataListener) {
        guard let thumbnailPath = media.videoThumbnailPath,
              state.placeholder == nil, !state.placeholderCreating else { return }

        state.placeholderCreating = true
        state.thumbnailPath = thumbnailPath
        let thumbImage = UIImage(contentsOfFile: thumbnailPath) ?? UIImage()
        listener.onProvidePlaceholderVideoSnapshot(thumbnailPath, snapImage: thumbImage) { _, cellData in
            state.placeholder = cellData
            cellData.videoTranscodingProgress = CGFloat(state.progress)
        }
    }

    private func sendVideo(media: AlbumMedia, videoPath: String, state: MediaState, listener: TUIChatMediaDataListener) {
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoPath)[.size] as? Int) ?? 0
        if fileSize > Self.kMaxVideoSizeBytes {
            listener.onProvideVideoError(TUISwift.timCommonLocalizableString("TUIKitFileSizeCheckLimited"))
            cleanupMedia(mediaId: media.id)
            return
        }

        state.placeholder?.videoTranscodingProgress = 1.0
        let placeholderCellData = state.placeholder

        let duration = max(Int(media.duration), 1)
        let localVideoPath = Self.copyFileToVideoPath(sourcePath: videoPath)
        var localSnapshotPath = Self.copyFileToVideoPath(sourcePath: media.videoThumbnailPath)
        if localSnapshotPath.isEmpty {
            localSnapshotPath = Self.generateVideoSnapshot(videoPath: localVideoPath)
        }

        cleanupMedia(mediaId: media.id)
        listener.onProvideVideo(localVideoPath, snapshot: localSnapshotPath, duration: duration, placeHolderCellData: placeholderCellData)
    }

    private func cleanupMedia(mediaId: UInt64) {
        if let sessionKey = mediaToSession[mediaId] {
            pickerSessions[sessionKey]?.mediaStates.removeValue(forKey: mediaId)
        }
        mediaToSession.removeValue(forKey: mediaId)
    }

    private func dismissAlbumPicker(_ vc: UIViewController, completion: (() -> Void)? = nil) {
        TUITool.applicationKeywindow()?.endEditing(true)
        vc.presentingViewController?.dismiss(animated: true) {
            completion?()
        }
    }

    private static func copyFileToVideoPath(sourcePath: String?) -> String {
        guard let sourcePath = sourcePath else { return "" }
        let fileName = (sourcePath as NSString).lastPathComponent
        let localPath = "\(TUISwift.tuiKit_Video_Path())\(fileName)"
        if !FileManager.default.fileExists(atPath: localPath) {
            try? FileManager.default.copyItem(atPath: sourcePath, toPath: localPath)
        }
        return localPath
    }

    private static func generateVideoSnapshot(videoPath: String) -> String {
        let snapshotName = "\(TUITool.genSnapshotName(nil) ?? "")_\(arc4random()).png"
        let snapshotPath = "\(TUISwift.tuiKit_Video_Path())\(snapshotName)"
        let url = URL(fileURLWithPath: videoPath)
        let asset = AVURLAsset(url: url)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 1920, height: 1920)
        let time = CMTimeMakeWithSeconds(0.5, preferredTimescale: 30)
        var actualTime = CMTime()
        if let cgImage = try? gen.copyCGImage(at: time, actualTime: &actualTime) {
            let image = UIImage(cgImage: cgImage)
            FileManager.default.createFile(atPath: snapshotPath, contents: image.pngData(), attributes: nil)
        } else {
            FileManager.default.createFile(atPath: snapshotPath, contents: Self.placeholderImage().pngData(), attributes: nil)
        }
        return snapshotPath
    }
}

// MARK: - Private Types

private class PickerSession {
    let albumVC: UIViewController
    var listener: TUIChatMediaDataListener?
    let conversationID: String?
    var mediaOrder: [UInt64] = []
    var mediaStates: [UInt64: MediaState] = [:]

    init(albumVC: UIViewController, listener: TUIChatMediaDataListener, conversationID: String?) {
        self.albumVC = albumVC
        self.listener = listener
        self.conversationID = conversationID
    }
}

private class MediaState {
    var mediaType: AlbumMediaType = .image
    var asset: PHAsset?
    var placeholder: TUIMessageCellData?
    var placeholderCreating: Bool = false
    var thumbnailPath: String?
    var progress: Float = 0
}

private class TUIAlbumPickerViewController: UIViewController, AlbumPickerDelegate {
    var onPickConfirmHandler: (([AlbumMedia], String?) -> Void)?
    var onMediaProcessingHandler: ((AlbumMedia, Float, Bool) -> Void)?
    var onMediaProcessedHandler: (() -> Void)?
    var onCancelHandler: (() -> Void)?
    private var albumPickerView: AlbumPickerView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if albumPickerView == nil {
            let pickerView = AlbumPickerView(frame: view.bounds)
            pickerView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            var config = AlbumPickerConfig()
            config.maxOutputFileSizeInMB = 100
            config.maxVideoDurationInSeconds = 600
            config.language = Self.currentAlbumPickerLanguage()
            var theme = AlbumPickerTheme()
            theme.currentPrimaryColor = TUISwift.timCommonDynamicColor("primary_theme_color", defaultColor: "#147AFF")
            pickerView.delegate = self
            pickerView.initialize(config: config, theme: theme)
            view.addSubview(pickerView)
            self.albumPickerView = pickerView
        }
    }

    private static func currentAlbumPickerLanguage() -> AlbumPickerLanguage {
        let language = TUIGlobalization.getPreferredLanguage() ?? "en"
        switch language {
        case "zh-Hans":
            return .zhHans
        case "zh-Hant":
            return .zhHant
        case "ar":
            return .ar
        default:
            return .en
        }
    }

    func onPickConfirm(pickedAlbumMedias: [AlbumMedia], textMessage: String?) {
        onPickConfirmHandler?(pickedAlbumMedias, textMessage)
    }

    func onMediaProcessing(albumMedia: AlbumMedia, progress: Float, error: Bool) {
        onMediaProcessingHandler?(albumMedia, progress, error)
    }

    func onMediaProcessed() {
        onMediaProcessedHandler?()
    }

    func onCancel() {
        onCancelHandler?()
    }
}
