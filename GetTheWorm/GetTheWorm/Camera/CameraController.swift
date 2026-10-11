//
//  CameraController.swift
//  GetTheWorm
//
//  Live capture only. There is deliberately no photo-library path — a saved
//  grass picture on your camera roll would defeat the entire app.
//

import AVFoundation
import UIKit

@Observable
final class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    enum Status {
        case idle
        case running
        case denied
        case unavailable
    }

    var status: Status = .idle
    /// True when the back camera's torch is lighting the preview. Pre-dawn
    /// lawns are black on screen without it.
    private(set) var isTorchOn = false
    var hasTorch: Bool { device?.hasTorch ?? false }
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    func start() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            status = .denied
            return
        }
        if !isConfigured {
            guard configureSession() else {
                status = .unavailable
                return
            }
            isConfigured = true
        }
        let session = session
        await Task.detached(priority: .userInitiated) {
            session.startRunning()
        }.value
        status = .running
    }

    func stop() {
        setTorch(on: false)
        let session = session
        Task.detached {
            session.stopRunning()
        }
        status = .idle
    }

    func toggleTorch() {
        setTorch(on: !isTorchOn)
    }

    private func setTorch(on: Bool) {
        guard let device, device.hasTorch, device.isTorchAvailable || !on else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = on
        } catch {
            isTorchOn = false
        }
    }

    func capture() async -> UIImage? {
        guard status == .running else { return nil }
        let settings = AVCapturePhotoSettings()
        // Force the flash when the user has lit the torch (they're clearly in
        // the dark); otherwise let the camera decide.
        let wantedFlash: AVCaptureDevice.FlashMode = isTorchOn ? .on : .auto
        if photoOutput.supportedFlashModes.contains(wantedFlash) {
            settings.flashMode = wantedFlash
        }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureSession() -> Bool {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input),
            session.canAddOutput(photoOutput)
        else { return false }
        session.addInput(input)
        session.addOutput(photoOutput)
        self.device = device
        return true
    }

    // MARK: AVCapturePhotoCaptureDelegate

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async {
            // Firing the flash switches the torch off. Re-light it so the
            // preview stays visible for a retry after a failed verdict.
            if self.isTorchOn {
                self.setTorch(on: true)
            }
            self.captureContinuation?.resume(returning: image)
            self.captureContinuation = nil
        }
    }
}
