//
//  Camera.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import Foundation
import PDFKit

struct UploadResponse: Codable {
    let message: String
    let file_path: String
}

class DocumentUploader {
    private let baseURL = "API_UPLOAD_BASE_URL"
    
    func convertImagesToPDF(_ images: [NSImage]) -> Data? {
        let pdfDocument = PDFDocument()
        
        for (index, image) in images.enumerated() {
            guard let pdfPage = PDFPage(image: image) else {
                print("Failed to create PDFPage for image \(index + 1)")
                continue
            }
            pdfDocument.insert(pdfPage, at: index)
        }
        
        return pdfDocument.dataRepresentation()
    }
    
   
    func uploadPDF(_ pdfData: Data, userId: String) async throws -> String {
        let filename = "document_\(Int(Date().timeIntervalSince1970)).pdf"
        
        print("Starting PDF upload for user: \(userId)")
        print("PDF data size: \(pdfData.count) bytes")
        
        let base64Data = pdfData.base64EncodedString()
        print("Base64 string length: \(base64Data.count)")
        
        let uploadBody: [String: String] = [
            "filename": filename,
            "data": base64Data
        ]
        
        guard let apiURL = URL(string: "\(baseURL)/\(userId)") else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(uploadBody)
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("Response status code: \(httpResponse.statusCode)")
        print("Response data: \(String(data: data, encoding: .utf8) ?? "")")
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(UploadResponse.self, from: data)
        return result.file_path
    }
}

import Foundation
import AVFoundation
import Combine
import UniformTypeIdentifiers

class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let userId: String
    private let completionHandler: (Bool, Error?) -> Void
    private weak var camera: Camera?
    
    init(userId: String, camera: Camera, completionHandler: @escaping (Bool, Error?) -> Void) {
        self.userId = userId
        self.completionHandler = completionHandler
        self.camera = camera
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error)")
            completionHandler(false, error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("Could not get image data")
            completionHandler(false, NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get image data"]))
            return
        }
        
        guard let image = NSImage(data: imageData) else {
            print("Failed to create NSImage from data")
            completionHandler(false, NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create NSImage from data"]))
            return
        }
        
        print("Successfully captured image. Size: \(imageData.count) bytes")
        
        DispatchQueue.main.async {
            self.camera?.capturedImages.append(image)
        }
        
        saveImageLocally(imageData)
        
        completionHandler(true, nil)
    }
    
    private func saveImageLocally(_ imageData: Data) {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Int(Date().timeIntervalSince1970)
        let fileName = "captured_image_\(timestamp).jpg"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try imageData.write(to: fileURL)
            print("Image saved locally at: \(fileURL.path)")
        } catch {
            print("Failed to save image locally: \(error)")
        }
    }
}

@MainActor
class Camera: ObservableObject {
    enum CameraError: Error {
        case captureDeviceNotFound
        case captureSessionConfigurationFailed
        case notAuthorized
    }
    
    private let session = AVCaptureSession()
    private var activeVideoInput: AVCaptureDeviceInput?
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDiscoverySession: AVCaptureDevice.DiscoverySession!
    
    @Published private(set) var videoDevices = [Device]()
    @Published var selectedVideoDevice = Device.invalid
    @Published var lastCaptureStatus: String = ""
    @Published private(set) var isAuthorized = false
    
    @Published var capturedImages: [NSImage] = []
    @Published var uploadProgress: Double = 0.0
    
    private var cancellables = Set<AnyCancellable>()
    private var photoCaptureDelegate: PhotoCaptureDelegate?
    
    func clearCapturedImages() {
        capturedImages.removeAll()
    }
    
    func captureImage(userId: String) {
        guard session.isRunning else {
            lastCaptureStatus = "Error: Camera session not running"
            return
        }

        guard photoOutput.connections.first?.isEnabled == true,
              photoOutput.connections.first?.isActive == true else {
            lastCaptureStatus = "Error: Photo output not properly configured"
            return
        }

        print("Initiating photo capture...")
        lastCaptureStatus = "Capturing..."

        let settings = AVCapturePhotoSettings()
        settings.isHighResolutionPhotoEnabled = true

        let delegate = PhotoCaptureDelegate(userId: userId, camera: self) { success, error in
            if success {
                self.lastCaptureStatus = "Capture successful"
            } else {
                self.lastCaptureStatus = "Error: \(error?.localizedDescription ?? "Unknown error")"
            }
            self.photoCaptureDelegate = nil
        }

        self.photoCaptureDelegate = delegate

        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    lazy var preview: CameraPreview = {
        CameraPreview(session: session)
    }()
    
    init() {
        setupDeviceDiscovery()
        
        $selectedVideoDevice.dropFirst().sink { [weak self] device in
            self?.selectDevice(device)
        }.store(in: &cancellables)
    }
    
    func start() async throws {
        try await authorize()
        try setup()
        startSession()
        lastCaptureStatus = "Camera ready"
    }
    
    private func authorize() async throws {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isAuthorized = true
            
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            if !isAuthorized {
                throw CameraError.notAuthorized
            }
            
        case .denied, .restricted:
            isAuthorized = false
            throw CameraError.notAuthorized
            
        @unknown default:
            isAuthorized = false
            throw CameraError.notAuthorized
        }
    }
    
    private func setup() throws {
        setupDeviceDiscovery()
        
        session.beginConfiguration()
        
        session.sessionPreset = .photo
        
        let videoCaptureDevice = try AVCaptureDevice.default(for: .video) ??
            videoDiscoverySession.devices.first ??
            { throw CameraError.captureDeviceNotFound }()
        
        activeVideoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        if session.canAddInput(activeVideoInput!) {
            session.addInput(activeVideoInput!)
        } else {
            throw CameraError.captureSessionConfigurationFailed
        }
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        } else {
            throw CameraError.captureSessionConfigurationFailed
        }
        
        session.commitConfiguration()
        
        print("Camera configuration:")
        print("Session preset: \(session.sessionPreset.rawValue)")
        print("Photo output enabled: \(photoOutput.isHighResolutionCaptureEnabled)")
        print("Available capture types: \(photoOutput.availablePhotoCodecTypes)")
    }
    
    private func setupDeviceDiscovery() {
        videoDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        
        videoDiscoverySession.publisher(for: \.devices).sink { [weak self] devices in
            self?.videoDevices = devices.map { Device(id: $0.uniqueID, name: $0.localizedName) }
        }.store(in: &cancellables)
    }
    
    private func startSession() {
        Task.detached(priority: .userInitiated) {
            self.session.startRunning()
            await MainActor.run {
                self.lastCaptureStatus = self.session.isRunning ? "Camera running" : "Failed to start camera"
            }
        }
    }
    
    func selectDevice(_ device: Device) {
        guard let captureDevice = videoDiscoverySession.devices.first(where: { $0.uniqueID == device.id }),
              let currentInput = activeVideoInput,
              captureDevice != currentInput.device else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        do {
            let newInput = try AVCaptureDeviceInput(device: captureDevice)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                activeVideoInput = newInput
            }
        } catch {
            session.addInput(currentInput)
        }
        
        session.commitConfiguration()
    }
}

struct Device: Hashable, Identifiable {
    static let invalid = Device(id: "-1", name: "No camera available")
    let id: String
    let name: String
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}
