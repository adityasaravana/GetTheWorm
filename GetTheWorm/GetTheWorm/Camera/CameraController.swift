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
    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
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
        let session = session
        Task.detached {
            session.stopRunning()
        }
        status = .idle
    }

    func capture() async -> UIImage? {
        guard status == .running else { return nil }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
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
            self.captureContinuation?.resume(returning: image)
            self.captureContinuation = nil
        }
    }
}
