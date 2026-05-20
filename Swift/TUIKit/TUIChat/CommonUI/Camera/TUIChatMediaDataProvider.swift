import AVFoundation
import Foundation
import MobileCoreServices
import Photos
import SDWebImage
import TIMCommon
import UIKit
import AlbumPicker

protocol TUIChatMediaDataProtocol: AnyObject {
    func selectPhoto()
    func takePicture()
    func takeVideo()
    func selectFile()
}

protocol TUIChatMediaDataListener: NSObjectProtocol {
    func onProvideImage(_ imageUrl: String, placeHolderCellData: TUIMessageCellData?)
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
    func onProvideImage(_ imageUrl: String, placeHolderCellData: TUIMessageCellData?) {}
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

class TUIChatMediaDataProvider: NSObject, UINavigationControllerDelegate, UIDocumentPickerDelegate, TUICameraViewControllerDelegate {
    weak var presentViewController: UIViewController?
    weak var listener: TUIChatMediaDataListener?
    var conversationID: String?

    // MARK: - Public API
    func restorePlaceholdersIfNeeded() {
        guard let listener = listener, let conversationID = conversationID, !conversationID.isEmpty else { return }
        TUIAlbumPickerMediaSendManager.shared.restorePlaceholders(via: listener, conversationID: conversationID)
    }

    func selectPhoto() {
        guard let presentViewController = presentViewController, let listener = listener else { return }
        TUIAlbumPickerMediaSendManager.shared.pickAlbumMedia(from: presentViewController, listener: listener, conversationID: conversationID)
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
            self.listener?.onProvideImage(path, placeHolderCellData: nil)
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
        gen.maximumSize = CGSize(width: 1920, height: 1920)
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
        gen.maximumSize = CGSize(width: 1920, height: 1920)
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
        gen.maximumSize = CGSize(width: 1920, height: 1920)
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
