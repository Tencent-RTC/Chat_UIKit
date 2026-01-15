//  Created by Tencent on 2023/06/09.
//  Copyright © 2023 Tencent. All rights reserved.

import AVFoundation

class TUICameraManager: NSObject {
    
    // MARK: - Switch Camera
    func switchCamera(session: AVCaptureSession, oldInput: AVCaptureDeviceInput, newInput: AVCaptureDeviceInput) -> AVCaptureDeviceInput {
        session.beginConfiguration()
        session.removeInput(oldInput)
        if session.canAddInput(newInput) {
            session.addInput(newInput)
        } else {
            if session.canAddInput(oldInput) {
                session.addInput(oldInput)
            }
        }
        session.commitConfiguration()
        
        return session.inputs.contains(newInput) ? newInput : oldInput
    }
    
    // MARK: - Zoom
    func zoom(device: AVCaptureDevice, factor: CGFloat) -> Error? {
        if device.activeFormat.videoMaxZoomFactor > factor && factor >= 1.0 {
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: factor, withRate: 4.0)
                device.unlockForConfiguration()
            } catch {
                return error
            }
        } else {
            return self.error(text: "Unsupported zoom factor", code: 2000)
        }
        return nil
    }
    
    // MARK: - Focus
    func focus(device: AVCaptureDevice, point: CGPoint) -> Error? {
        let supported = device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus)
        if supported {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
            } catch {
                return error
            }
        } else {
            return self.error(text: "Device does not support focus", code: 2001)
        }
        return nil
    }
    
    // MARK: - Expose
    private var cameraAdjustingExposureContext = 0
    func expose(device: AVCaptureDevice, point: CGPoint) -> Error? {
        let supported = device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.continuousAutoExposure)
        if supported {
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = .continuousAutoExposure
                if device.isExposureModeSupported(.locked) {
                    device.addObserver(self, forKeyPath: "adjustingExposure", options: .new, context: &cameraAdjustingExposureContext)
                }
                device.unlockForConfiguration()
            } catch {
                return error
            }
        } else {
            return self.error(text: "Device does not support exposure", code: 2002)
        }
        return nil
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &cameraAdjustingExposureContext {
            if let device = object as? AVCaptureDevice, !device.isAdjustingExposure, device.isExposureModeSupported(.locked) {
                device.removeObserver(self, forKeyPath: "adjustingExposure", context: &cameraAdjustingExposureContext)
                DispatchQueue.main.async {
                    do {
                        try device.lockForConfiguration()
                        device.exposureMode = .locked
                        device.unlockForConfiguration()
                    } catch {
                        print(error)
                    }
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - Auto focus, exposure
    func resetFocusAndExposure(device: AVCaptureDevice) -> Error? {
        let focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
        let exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
        let canResetFocus = device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode)
        let canResetExposure = device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode)
        let centerPoint = CGPoint(x: 0.5, y: 0.5)
        do {
            try device.lockForConfiguration()
            if canResetFocus {
                device.focusMode = focusMode
                device.focusPointOfInterest = centerPoint
            }
            if canResetExposure {
                device.exposureMode = exposureMode
                device.exposurePointOfInterest = centerPoint
            }
            device.unlockForConfiguration()
        } catch {
            return error
        }
        return nil
    }
    
    // MARK: - Flash
    func flashMode(device: AVCaptureDevice) -> AVCaptureDevice.FlashMode {
        return device.flashMode
    }
    
    func changeFlash(device: AVCaptureDevice, mode: AVCaptureDevice.FlashMode) -> Error? {
        if !device.hasFlash {
            return self.error(text: "Flash is not supported", code: 2003)
        }
        if torchMode(device: device) == .on {
            _ = setTorch(device: device, mode: .off)
        }
        return setFlash(device: device, mode: mode)
    }
    
    func setFlash(device: AVCaptureDevice, mode: AVCaptureDevice.FlashMode) -> Error? {
        if device.isFlashModeSupported(mode) {
            do {
                try device.lockForConfiguration()
                device.flashMode = mode
                device.unlockForConfiguration()
            } catch {
                return error
            }
        } else {
            return self.error(text: "Flash is not supported", code: 2003)
        }
        return nil
    }
    
    // MARK: - Flashlight
    func torchMode(device: AVCaptureDevice) -> AVCaptureDevice.TorchMode {
        return device.torchMode
    }
    
    func changeTorch(device: AVCaptureDevice, mode: AVCaptureDevice.TorchMode) -> Error? {
        if !device.hasTorch {
            return self.error(text: "Flashlight not supported", code: 2004)
        }
        if flashMode(device: device) == .on {
            _ = setFlash(device: device, mode: .off)
        }
        return setTorch(device: device, mode: mode)
    }
    
    func setTorch(device: AVCaptureDevice, mode: AVCaptureDevice.TorchMode) -> Error? {
        if device.isTorchModeSupported(mode) {
            do {
                try device.lockForConfiguration()
                device.torchMode = mode
                device.unlockForConfiguration()
            } catch {
                return error
            }
        } else {
            return self.error(text: "Flashlight not supported", code: 2004)
        }
        return nil
    }
    
    // MARK: -
    private func error(text: String, code: Int) -> NSError {
        let desc = [NSLocalizedDescriptionKey: text]
        let error = NSError(domain: "com.tui.camera", code: code, userInfo: desc)
        return error
    }
} 
