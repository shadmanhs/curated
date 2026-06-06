import AVFoundation
import UIKit

final class CameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var capturedFrame: Data?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var continuation: CheckedContinuation<Data, Error>?

    /// Called on each captured video frame (JPEG data). Set by the live view.
    var onFrame: ((Data) -> Void)?
    private var isStreamingFrames = false
    private var lastFrameTime: Date = .distantPast
    private let frameInterval: TimeInterval = 0.5 // ~2 fps
    private let frameQueue = DispatchQueue(label: "com.curated.camera.frames")

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted { self?.setupSession() }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        // Video data output for continuous frame streaming
        videoOutput.setSampleBufferDelegate(self, queue: frameQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func startStreaming() {
        isStreamingFrames = true
    }

    func stopStreaming() {
        isStreamingFrames = false
        onFrame = nil
    }

    /// Capture a single frame as JPEG data.
    func captureFrame() async throws -> Data {
        if continuation != nil {
            throw CameraError.captureBusy
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func flipCamera() {
        let currentPosition = (session.inputs.first as? AVCaptureDeviceInput)?.device.position ?? .back
        let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back

        session.beginConfiguration()
        if let currentInput = session.inputs.first {
            session.removeInput(currentInput)
        }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            return
        }
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
    }

    func restartSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            self.session.startRunning()
        }
    }

    func stopSession() {
        stopStreaming()
        session.stopRunning()
    }
}

// MARK: - Video Frame Streaming

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isStreamingFrames, let onFrame else { return }

        let now = Date()
        guard now.timeIntervalSince(lastFrameTime) >= frameInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.4) else { return }

        onFrame(jpegData)
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            continuation?.resume(throwing: error)
            continuation = nil
            return
        }
        guard let data = photo.fileDataRepresentation() else {
            continuation?.resume(throwing: CameraError.noData)
            continuation = nil
            return
        }
        DispatchQueue.main.async { self.capturedFrame = data }
        continuation?.resume(returning: data)
        continuation = nil
    }
}

enum CameraError: Error, LocalizedError {
    case noData
    case notAuthorized
    case captureBusy

    var errorDescription: String? {
        switch self {
        case .noData: return "No image data captured"
        case .notAuthorized: return "Camera access not authorized"
        case .captureBusy: return "A capture is already in progress"
        }
    }
}
