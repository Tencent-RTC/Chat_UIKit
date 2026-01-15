import AVFoundation
import Foundation
import MobileCoreServices
import Photos
import PhotosUI
import SDWebImage
import TIMCommon
import UIKit

typealias TUIChatMediaDataProviderResultCallback = (Bool, String?, String?) -> Void

protocol TUIChatMediaDataProtocol: AnyObject {
    func selectPhoto()
    func takePicture()
    func takeVideo()
    func selectFile()
}

protocol TUIChatMediaDataListener: NSObjectProtocol {
    func onProvideImage(_ imageUrl: String)
    func onProvideImageError(_ errorMessage: String)

    func onProvideVideo(_ videoUrl: String, snapshot: String, duration: Int, placeHolderCellData: TUIMessageCellData?)
    func onProvidePlaceholderVideoSnapshot(_ snapshotUrl: String, snapImage: UIImage, completion: ((Bool, TUIMessageCellData) -> Void)?)
    func onProvideVideoError(_ errorMessage: String)

    func onProvideFile(_ fileUrl: String, filename: String, fileSize: Int)
    func onProvideFileError(_ errorMessage: String)

    func currentConversatinID() -> String
    func isPageAppears() -> Bool
    func sendPlaceHolderUIMessage(cellData: TUIMessageCellData)
    func sendMessage(_ message: V2TIMMessage, placeHolderCellData: TUIMessageCellData)
}

extension TUIChatMediaDataListener {
    func onProvideImage(_ imageUrl: String) {}
    func onProvideImageError(_ errorMessage: String) {}

    func onProvideVideo(_ videoUrl: String, snapshot: String, duration: Int, placeHolderCellData: TUIMessageCellData?) {}
    func onProvidePlaceholderVideoSnapshot(_ snapshotUrl: String, snapImage: UIImage, completion: ((Bool, TUIMessageCellData) -> Void)?) {}
    func onProvideVideoError(_ errorMessage: String) {}

    func onProvideFile(_ fileUrl: String, filename: String, fileSize: Int) {}
    func onProvideFileError(_ errorMessage: String) {}

    func currentConversatinID() -> String { return "" }
    func isPageAppears() -> Bool { return false }
    func sendPlaceHolderUIMessage(cellData: TUIMessageCellData) {}
    func sendMessage(_ message: V2TIMMessage, placeHolderCellData: TUIMessageCellData) {}
}

class TUIChatMediaDataProvider: NSObject, PHPickerViewControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIDocumentPickerDelegate, TUICameraViewControllerDelegate {
    weak var presentViewController: UIViewController?
    weak var listener: TUIChatMediaDataListener?
    var conversationID: String?

    // MARK: - Public API

    func selectPhoto() {
        DispatchQueue.main.async {
            if #available(iOS 14.0, *) {
                var configuration = PHPickerConfiguration()
                configuration.filter = PHPickerFilter.any(of: [.images, .videos])
                configuration.selectionLimit = 9
                let picker = PHPickerViewController(configuration: configuration)
                picker.delegate = self
                picker.modalPresentationStyle = .fullScreen
                picker.view.backgroundColor = .white
                self.presentViewController?.present(picker, animated: true, completion: nil)
            } else {
                if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
                    let picker = UIImagePickerController()
                    picker.sourceType = .photoLibrary
                    picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: .photoLibrary) ?? []
                    picker.delegate = self
                    self.presentViewController?.present(picker, animated: true, completion: nil)
                }
            }
        }
    }

    func takePicture() {
        let actionBlock: () -> Void = { [weak self] in
            guard let self = self else { return }
            let vc = TUICameraViewController()
            vc.type = .photo
            vc.delegate = self
            if let navigationController = self.presentViewController?.navigationController {
                navigationController.pushViewController(vc, animated: true)
            } else {
                self.presentViewController?.present(vc, animated: true, completion: nil)
            }
        }
        if TUIUserAuthorizationCenter.isEnableCameraAuthorization {
            DispatchQueue.main.async {
                actionBlock()
            }
        } else {
            if !TUIUserAuthorizationCenter.isEnableCameraAuthorization {
                TUIUserAuthorizationCenter.cameraStateActionWithPopCompletion(completion: {
                    DispatchQueue.main.async {
                        actionBlock()
                    }
                })
            }
        }
    }

    func takeVideo() {
        weak var weakSelf = self
        let actionBlock: () -> Void = {
            let vc = TUICameraViewController()
            vc.type = .video
            vc.videoMinimumDuration = 1.5
            vc.delegate = weakSelf
            if TUIChatConfig.shared.maxVideoRecordDuration > 0 {
                vc.videoMaximumDuration = TUIChatConfig.shared.maxVideoRecordDuration
            }
            if let navigationController = weakSelf?.presentViewController?.navigationController {
                navigationController.pushViewController(vc, animated: true)
            } else {
                weakSelf?.presentViewController?.present(vc, animated: true, completion: nil)
            }
        }

        if TUIUserAuthorizationCenter.isEnableMicroAuthorization && TUIUserAuthorizationCenter.isEnableCameraAuthorization {
            DispatchQueue.main.async {
                actionBlock()
            }
        } else {
            if !TUIUserAuthorizationCenter.isEnableMicroAuthorization {
                TUIUserAuthorizationCenter.microStateActionWithPopCompletion(completion: {
                    if TUIUserAuthorizationCenter.isEnableCameraAuthorization {
                        DispatchQueue.main.async {
                            actionBlock()
                        }
                    }
                })
            }
            if !TUIUserAuthorizationCenter.isEnableCameraAuthorization {
                TUIUserAuthorizationCenter.cameraStateActionWithPopCompletion(completion: {
                    if TUIUserAuthorizationCenter.isEnableMicroAuthorization {
                        DispatchQueue.main.async {
                            actionBlock()
                        }
                    }
                })
            }
        }
    }

    func selectFile() {
        let picker = UIDocumentPickerViewController(documentTypes: [kUTTypeData as String], in: .open)
        picker.delegate = self
        self.presentViewController?.present(picker, animated: true, completion: nil)
    }

    // MARK: - Private Do task

    private func handleImagePick(succ: Bool, message: String?, imageData: Data?) {
        var imageFormatExtensionMap: [SDImageFormat: String]? = nil
        if imageFormatExtensionMap == nil {
            imageFormatExtensionMap = [
                .undefined: "",
                .JPEG: "jpeg",
                .PNG: "png",
                .GIF: "gif",
                .TIFF: "tiff",
                .webP: "webp",
                .HEIC: "heic",
                .HEIF: "heif",
                .PDF: "pdf",
                .SVG: "svg",
                .BMP: "bmp",
                .RAW: "raw"
            ]
        }

        DispatchQueue.main.async {
            guard let imageData = imageData, succ else {
                self.listener?.onProvideImageError(message ?? "")
                return
            }

            guard let image = UIImage(data: imageData) else { return }
            var data = image.jpegData(compressionQuality: 1.0)
            var path = TUISwift.tuiKit_Image_Path() + TUITool.genImageName(nil)

            if let extensionName = imageFormatExtensionMap?[image.sd_imageFormat], !extensionName.isEmpty {
                path = (path as NSString).appendingPathExtension(extensionName) ?? path
            }

            var imageFormatSizeMax = 28 * 1024 * 1024

            if image.sd_imageFormat == .GIF {
                imageFormatSizeMax = 10 * 1024 * 1024
            }

            if imageData.count > imageFormatSizeMax {
                self.listener?.onProvideFileError(TUISwift.timCommonLocalizableString("TUIKitImageSizeCheckLimited"))
                return
            }

            if image.sd_imageFormat != .GIF {
                var newImage = image
                let imageOrientation = image.imageOrientation
                let aspectRatio = min(1920 / image.size.width, 1920 / image.size.height)
                let aspectWidth = image.size.width * aspectRatio
                let aspectHeight = image.size.height * aspectRatio
                UIGraphicsBeginImageContext(CGSize(width: aspectWidth, height: aspectHeight))
                image.draw(in: CGRect(x: 0, y: 0, width: aspectWidth, height: aspectHeight))
                newImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                UIGraphicsEndImageContext()
                data = newImage.jpegData(compressionQuality: 0.75)
            }

            FileManager.default.createFile(atPath: path, contents: data, attributes: nil)
            self.listener?.onProvideImage(path)
        }
    }

    private func transcodeIfNeed(succ: Bool, message: String?, videoUrl: URL?) {
        if !succ || videoUrl == nil {
            self.handleVideoPick(succ: false, message: message, videoUrl: nil)
            return
        }

        if videoUrl?.pathExtension.lowercased() == "mp4" {
            self.handleVideoPick(succ: succ, message: message, videoUrl: videoUrl)
            return
        }

        let tempPath = NSTemporaryDirectory()
        let urlName = videoUrl?.deletingPathExtension()
        let newUrl = URL(string: "file://\(tempPath)\(urlName?.lastPathComponent.removingPercentEncoding ?? "").mp4")

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: newUrl?.path ?? "") {
            do {
                try fileManager.removeItem(atPath: newUrl?.path ?? "")
            } catch {
                assertionFailure("removeItemFail: \(error.localizedDescription)")
                return
            }
        }

        // mov to mp4
        let avAsset = AVURLAsset(url: videoUrl!)
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = newUrl
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true

        // intercept FirstTime VideoPicture
        let opts: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        let urlAsset = AVURLAsset(url: videoUrl!, options: opts)
        _ = Int(urlAsset.duration.value) / Int(urlAsset.duration.timescale)
        let gen = AVAssetImageGenerator(asset: urlAsset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 192, height: 192)
        var actualTime = CMTime()
        let time = CMTimeMakeWithSeconds(0.5, preferredTimescale: 30)
        let imageRef = try? gen.copyCGImage(at: time, actualTime: &actualTime)
        let image = UIImage(cgImage: imageRef!)

        DispatchQueue.main.async {
            if self.listener != nil && ((self.listener?.responds(to: Selector(("onProvidePlaceholderVideoSnapshot")))) != nil) {
                self.listener?.onProvidePlaceholderVideoSnapshot("", snapImage: image) { _, placeHolderCellData in
                    exportSession?.exportAsynchronously {
                        switch exportSession?.status {
                        case .failed:
                            print("Export session failed")
                        case .cancelled:
                            print("Export canceled")
                        case .completed:
                            print("Successful!")
                            self.handleVideoPick(succ: succ, message: message, videoUrl: newUrl, placeHolderCellData: placeHolderCellData)
                        default:
                            break
                        }
                    }

                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        if exportSession?.status == .exporting {
                            print("exportSession.progress:\(exportSession?.progress ?? 0)")
                            placeHolderCellData.videoTranscodingProgress = CGFloat(exportSession?.progress ?? 0)
                        }
                    }
                }
            } else {
                exportSession?.exportAsynchronously {
                    switch exportSession?.status {
                    case .completed:
                        print("Successful!")
                        self.handleVideoPick(succ: succ, message: message, videoUrl: newUrl)
                    default:
                        break
                    }
                }
            }
        }
    }

    private func transcodeIfNeed(succ: Bool, message: String?, videoUrl: URL?, placeHolderCellData: TUIMessageCellData?) {
        if !succ || videoUrl == nil {
            self.handleVideoPick(succ: false, message: message, videoUrl: nil)
            return
        }

        if videoUrl?.pathExtension.lowercased() == "mp4" {
            self.handleVideoPick(succ: succ, message: message, videoUrl: videoUrl)
            return
        }

        let tempPath = NSTemporaryDirectory()
        let urlName = videoUrl?.deletingPathExtension()
        let newUrl = URL(string: "file://\(tempPath)\(urlName?.lastPathComponent.removingPercentEncoding ?? "").mp4")

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: newUrl?.path ?? "") {
            do {
                try fileManager.removeItem(atPath: newUrl?.path ?? "")
            } catch {
                assertionFailure("removeItemFail: \(error.localizedDescription)")
                return
            }
        }

        // mov to mp4
        let avAsset = AVURLAsset(url: videoUrl!)
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)
        exportSession?.outputURL = newUrl
        exportSession?.outputFileType = .mp4
        exportSession?.shouldOptimizeForNetworkUse = true

        // intercept FirstTime VideoPicture
        let opts: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        let urlAsset = AVURLAsset(url: videoUrl!, options: opts)
        _ = Int(urlAsset.duration.value) / Int(urlAsset.duration.timescale)
        let gen = AVAssetImageGenerator(asset: urlAsset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 192, height: 192)
        var _: NSError?
        var actualTime = CMTime()
        let time = CMTimeMakeWithSeconds(0.5, preferredTimescale: 30)
        let imageRef = try? gen.copyCGImage(at: time, actualTime: &actualTime)
        _ = UIImage(cgImage: imageRef!)

        DispatchQueue.main.async {
            if self.listener != nil && ((self.listener?.responds(to: Selector(("onProvidePlaceholderVideoSnapshot")))) != nil) {
                exportSession?.exportAsynchronously {
                    switch exportSession?.status {
                    case .failed:
                        print("Export session failed")
                    case .cancelled:
                        print("Export canceled")
                    case .completed:
                        print("Successful!")
                        self.handleVideoPick(succ: succ, message: message, videoUrl: newUrl, placeHolderCellData: placeHolderCellData)
                    default:
                        break
                    }
                }

                Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                    if exportSession?.status == .exporting {
                        print("exportSession.progress:\(exportSession?.progress ?? 0)")
                        placeHolderCellData?.videoTranscodingProgress = CGFloat(exportSession?.progress ?? 0)
                    }
                }
            } else {
                exportSession?.exportAsynchronously {
                    switch exportSession?.status {
                    case .completed:
                        print("Successful!")
                        self.handleVideoPick(succ: succ, message: message, videoUrl: newUrl)
                    default:
                        break
                    }
                }
            }
        }
    }

    private func handleVideoPick(succ: Bool, message: String?, videoUrl: URL?) {
        self.handleVideoPick(succ: succ, message: message, videoUrl: videoUrl, placeHolderCellData: nil)
    }

    private func handleVideoPick(succ: Bool, message: String?, videoUrl: URL?, placeHolderCellData: TUIMessageCellData?) {
        if !succ || videoUrl == nil {
            self.listener?.onProvideVideoError(message ?? "")
            return
        }

        let videoData = try? Data(contentsOf: videoUrl!)
        let videoPath = "\(TUISwift.tuiKit_Video_Path())\(TUITool.genVideoName(nil) ?? "")_\(arc4random()).mp4"
        FileManager.default.createFile(atPath: videoPath, contents: videoData, attributes: nil)

        let opts: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        let urlAsset = AVURLAsset(url: videoUrl!, options: opts)
        let duration = Int(urlAsset.duration.value) / Int(urlAsset.duration.timescale)
        let gen = AVAssetImageGenerator(asset: urlAsset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 192, height: 192)
        var _: NSError?
        var actualTime = CMTime()
        let time = CMTimeMakeWithSeconds(0.5, preferredTimescale: 30)
        let imageRef = try? gen.copyCGImage(at: time, actualTime: &actualTime)
        let image = UIImage(cgImage: imageRef!)

        let imageData = image.pngData()
        let imagePath = "\(TUISwift.tuiKit_Video_Path())\(TUITool.genSnapshotName(nil) ?? "")_\(arc4random())"
        FileManager.default.createFile(atPath: imagePath, contents: imageData, attributes: nil)

        self.listener?.onProvideVideo(videoPath, snapshot: imagePath, duration: duration, placeHolderCellData: placeHolderCellData)
    }

    // MARK: - PHPickerViewControllerDelegate

    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        DispatchQueue.main.async {
            picker.dismiss(animated: true, completion: nil)
            TUITool.applicationKeywindow()?.endEditing(true)
        }

        if results.isEmpty {
            return
        }

        for result in results {
            self._dealPHPickerResultFinishPicking(result)
        }
    }

    @available(iOS 14.0, *)
    private func _dealPHPickerResultFinishPicking(_ result: PHPickerResult) {
        let itemProvider = result.itemProvider
        if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
            itemProvider.loadDataRepresentation(forTypeIdentifier: kUTTypeImage as String) { [weak self] data, error in
                guard let self else { return }
                DispatchQueue.main.async {
                    let succ = error == nil
                    let message = error?.localizedDescription
                    self.handleImagePick(succ: succ, message: message, imageData: data)
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeMPEG4 as String) {
            itemProvider.loadDataRepresentation(forTypeIdentifier: kUTTypeMovie as String) { [weak self] data, _ in
                guard let self else { return }
                DispatchQueue.main.async {
                    let fileName = "temp.mp4"
                    let tempPath = NSTemporaryDirectory()
                    let filePath = tempPath + fileName
                    if FileManager.default.isDeletableFile(atPath: filePath) {
                        try? FileManager.default.removeItem(atPath: filePath)
                    }
                    let newUrl = URL(fileURLWithPath: filePath)
                    let flag = FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil)
                    self.transcodeIfNeed(succ: flag, message: flag ? nil : "video not found", videoUrl: newUrl)
                }
            }
        } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
            if self.listener != nil && ((self.listener?.responds(to: Selector(("onProvidePlaceholderVideoSnapshot")))) != nil) {
                self.listener?.onProvidePlaceholderVideoSnapshot("", snapImage: UIImage()) { _, placeHolderCellData in
                    itemProvider.loadDataRepresentation(forTypeIdentifier: kUTTypeMovie as String) { [weak self] data, _ in
                        guard let self else { return }
                        DispatchQueue.main.async {
                            let dateNow = Date()
                            let timeSp = "\(Int(dateNow.timeIntervalSince1970 * 1000))"
                            let fileName = "\(timeSp)_temp.mov"
                            let tempPath = NSTemporaryDirectory()
                            let filePath = tempPath + fileName
                            if FileManager.default.isDeletableFile(atPath: filePath) {
                                try? FileManager.default.removeItem(atPath: filePath)
                            }
                            let newUrl = URL(fileURLWithPath: filePath)
                            let flag = FileManager.default.createFile(atPath: filePath, contents: data, attributes: nil)
                            self.transcodeIfNeed(succ: flag, message: flag ? nil : "movie not found", videoUrl: newUrl, placeHolderCellData: placeHolderCellData)
                        }
                    }
                }
            }
        } else {
            let typeIdentifier = result.itemProvider.registeredTypeIdentifiers.first
            itemProvider.loadFileRepresentation(forTypeIdentifier: typeIdentifier ?? "") { url, _ in
                DispatchQueue.main.async {
                    if let url = url, let data = try? Data(contentsOf: url) {
                        _ = UIImage(data: data)

                        /**
                         * Can't get url when typeIdentifier is public.jepg on emulator:
                         * There is a separate JEPG transcoding issue that only affects the simulator (63426347), please refer to
                         * https://developer.apple.com/forums/thread/658135 for more information.
                         */
                    }
                }
            }
        }
    }

    // MARK: - UIImagePickerController

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.delegate = nil
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            let mediaType = info[.mediaType] as? String
            if mediaType == kUTTypeImage as String {
                var url: URL?
                if #available(iOS 11.0, *) {
                    url = info[.imageURL] as? URL
                } else {
                    url = info[.referenceURL] as? URL
                }

                var succ = true
                var imageData: Data?
                var errorMessage: String?
                if let url = url {
                    succ = true
                    imageData = try? Data(contentsOf: url)
                } else {
                    succ = false
                    errorMessage = "image not found"
                }
                self.handleImagePick(succ: succ, message: errorMessage, imageData: imageData)
            } else if mediaType == kUTTypeMovie as String {
                var url = info[.mediaURL] as? URL
                if let url = url {
                    self.transcodeIfNeed(succ: true, message: nil, videoUrl: url)
                    return
                }

                var asset: PHAsset?
                if #available(iOS 11.0, *) {
                    asset = info[.phAsset] as? PHAsset
                }
                if let asset = asset {
                    self.originURL(with: asset) { success, URL in
                        self.transcodeIfNeed(succ: success, message: success ? nil : "origin url with asset not found", videoUrl: URL)
                    }
                    return
                }

                url = info[.referenceURL] as? URL
                if let url = url {
                    self.originURL(withReferenceURL: url) { success, URL in
                        self.transcodeIfNeed(succ: success, message: success ? nil : "origin url with asset not found", videoUrl: URL)
                    }
                    return
                }

                self.transcodeIfNeed(succ: false, message: "not support the video", videoUrl: nil)
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    // Get the original file path based on UIImagePickerControllerReferenceURL
    private func originURL(withReferenceURL URL: URL, completion: @escaping (Bool, URL?) -> Void) {
        let queryInfo = self.dictionary(withURLQuery: URL.query ?? "")
        var fileName = "temp.mp4"
        if queryInfo.keys.contains("id") && queryInfo.keys.contains("ext") {
            fileName = "\(queryInfo["id"] ?? "").\(queryInfo["ext"]?.lowercased() ?? "")"
        }
        let tempPath = NSTemporaryDirectory()
        let filePath = tempPath + fileName
        if FileManager.default.isDeletableFile(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }
        let newUrl = Foundation.URL(fileURLWithPath: filePath)

        let fetchResult = PHAsset.fetchAssets(withALAssetURLs: [URL], options: nil)
        guard let asset = fetchResult.firstObject else {
            completion(false, nil)
            return
        }
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first else {
            completion(false, nil)
            return
        }
        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        guard let fileHandle = FileHandle(forWritingAtPath: filePath) else {
            try? FileManager.default.removeItem(atPath: filePath)
            completion(false, nil)
            return
        }

        PHAssetResourceManager.default().requestData(for: resource, options: options, dataReceivedHandler: { data in
            if #available(iOS 13.4, *) {
                try? fileHandle.write(contentsOf: data)
            } else {
                fileHandle.write(data)
            }
        }, completionHandler: { error in
            if #available(iOS 13.0, *) {
                try? fileHandle.close()
            } else {
                fileHandle.closeFile()
            }

            if let error = error {
                print("Error loading asset data: \(error.localizedDescription)")
                try? FileManager.default.removeItem(atPath: filePath)
                completion(false, nil)
                return
            }

            let flag = FileManager.default.fileExists(atPath: filePath)
            if !flag {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            completion(flag, newUrl)
        })
    }

    private func originURL(with asset: PHAsset, completion: @escaping (Bool, URL?) -> Void) {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else {
            completion(false, nil)
            return
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = false
        let fileName = "temp.mp4"
        let tempPath = NSTemporaryDirectory()
        let filePath = tempPath + fileName

        if FileManager.default.isDeletableFile(atPath: filePath) {
            try? FileManager.default.removeItem(atPath: filePath)
        }

        FileManager.default.createFile(atPath: filePath, contents: nil, attributes: nil)
        guard let fileHandle = FileHandle(forWritingAtPath: filePath) else {
            try? FileManager.default.removeItem(atPath: filePath)
            completion(false, nil)
            return
        }

        let newUrl = URL(fileURLWithPath: filePath)
        var hasError = false

        PHAssetResourceManager.default().requestData(for: resources.first!, options: options, dataReceivedHandler: { data in
            guard !hasError else { return }

            if data.isEmpty {
                hasError = true
                return
            }

            if #available(iOS 13.4, *) {
                do {
                    try fileHandle.write(contentsOf: data)
                } catch {
                    hasError = true
                }
            } else {
                fileHandle.write(data)
            }
        }, completionHandler: { error in
            if #available(iOS 13.0, *) {
                try? fileHandle.close()
            } else {
                fileHandle.closeFile()
            }

            if error != nil || hasError {
                try? FileManager.default.removeItem(atPath: filePath)
                completion(false, nil)
                return
            }

            let flag = FileManager.default.fileExists(atPath: filePath)
            if !flag {
                try? FileManager.default.removeItem(atPath: filePath)
            }
            completion(flag, newUrl)
        })
    }

    private func dictionary(withURLQuery query: String) -> [String: String] {
        let components = query.components(separatedBy: "&")
        var dict = [String: String]()
        for item in components {
            let subs = item.components(separatedBy: "=")
            if subs.count == 2 {
                dict[subs.first!] = subs.last!
            }
        }
        return dict
    }

    // MARK: - TUICameraViewControllerDelegate

    func cameraViewController(_ controller: TUICameraViewController, didFinishPickingMediaWithVideoURL url: URL) {
        self.transcodeIfNeed(succ: true, message: nil, videoUrl: url)
    }

    func cameraViewController(_ controller: TUICameraViewController, didFinishPickingMediaWithImageData data: Data) {
        self.handleImagePick(succ: true, message: nil, imageData: data)
    }

    func cameraViewControllerDidCancel(_ controller: TUICameraViewController) {}

    func cameraViewControllerDidPictureLib(_ controller: TUICameraViewController, finishCallback: @escaping () -> Void) {
        self.selectPhoto()
        finishCallback()
    }

    // MARK: - UIDocumentPickerDelegate

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { [weak self] newURL in
            guard let self = self else { return }
            let fileData = try? Data(contentsOf: newURL, options: .mappedIfSafe)
            var fileName = url.lastPathComponent
            var filePath = TUISwift.tuiKit_File_Path() + fileName
            if fileData?.count ?? 0 > 1000000000 || fileData?.count == 0 || fileData == nil {
                let ac = UIAlertController(title: TUISwift.timCommonLocalizableString("TUIKitFileSizeCheckLimited"), message: nil, preferredStyle: .alert)
                ac.addAction(UIAlertAction(title: TUISwift.timCommonLocalizableString("Confirm"), style: .default, handler: nil))
                self.presentViewController?.present(ac, animated: true, completion: nil)
                return
            }
            if FileManager.default.fileExists(atPath: filePath) {
                var i = 0
                let arrayM = FileManager.default.subpaths(atPath: TUISwift.tuiKit_File_Path()) ?? []
                for sub in arrayM {
                    if (sub as NSString).pathExtension == (fileName as NSString).pathExtension && (sub as NSString).deletingPathExtension.contains((fileName as NSString).deletingPathExtension) {
                        i += 1
                    }
                }
                if i > 0 {
                    fileName = fileName.replacingOccurrences(of: (fileName as NSString).deletingPathExtension, with: "\((fileName as NSString).deletingPathExtension)(\(i))")
                    filePath = TUISwift.tuiKit_File_Path() + fileName
                }
            }

            FileManager.default.createFile(atPath: filePath, contents: fileData, attributes: nil)
            if FileManager.default.fileExists(atPath: filePath) {
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: filePath)[.size] as? UInt64) ?? 0
                if self.listener != nil && ((self.listener?.responds(to: Selector(("onProvideFile")))) != nil) {
                    self.listener?.onProvideFile(filePath, filename: fileName, fileSize: Int(fileSize))
                }
            } else {
                if self.listener != nil && ((self.listener?.responds(to: Selector(("onProvideFileError")))) != nil) {
                    self.listener?.onProvideFileError("file not found")
                }
            }
        }
        url.stopAccessingSecurityScopedResource()
        controller.dismiss(animated: true, completion: nil)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        controller.dismiss(animated: true, completion: nil)
    }
}
