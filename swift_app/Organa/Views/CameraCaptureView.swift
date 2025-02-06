//
//  CameraCaptureView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import SwiftUI
import AVFoundation

struct CameraCaptureView: View {
    @StateObject private var camera = Camera()
    @Environment(\.dismiss) private var dismiss
    let userId: String
    
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                camera.preview
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        Task {
                            do {
                                try await camera.start()
                            } catch {
                                print("Camera start failed: \(error)")
                                alertMessage = "Failed to start camera: \(error.localizedDescription)"
                                showingAlert = true
                            }
                        }
                    }
    
                VStack {
                    Picker("Camera", selection: $camera.selectedVideoDevice) {
                        ForEach(camera.videoDevices, id: \.id) { device in
                            Text(device.name).tag(device)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .padding()
    
                    Spacer()
    
                    Button(action: {
                        camera.captureImage(userId: userId)
                    }) {
                        Image(systemName: "camera")
                            .font(.title)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.bottom, 8)
    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom)
                }
                .frame(width: 150)
                .background(.ultraThinMaterial)
            }
            .ignoresSafeArea()
    
            Divider()
    
            if !camera.capturedImages.isEmpty {
                VStack {
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack {
                            ForEach(camera.capturedImages.indices, id: \.self) { index in
                                Image(nsImage: camera.capturedImages[index])
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 150, height: 200)
                                    .cornerRadius(8)
                                    .shadow(radius: 4)
                                    .padding(4)
                            }
                        }
                        .padding()
                    }
    
                    if camera.uploadProgress > 0.0 && camera.uploadProgress < 1.0 {
                        ProgressView(value: camera.uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding([.leading, .trailing], 20)
                    }
    
                    HStack {
                        Button(action: {
                            submitCapturedImages()
                        }) {
                            Text("Submit")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding()
                        .disabled(camera.uploadProgress > 0.0 && camera.uploadProgress < 1.0)
    
                        Button(action: {
                            camera.clearCapturedImages()
                        }) {
                            Text("Clear")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        .padding()
                        .disabled(camera.uploadProgress > 0.0 && camera.uploadProgress < 1.0)
                    }
                }
            }
        }
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }

    private func submitCapturedImages() {
        guard !camera.capturedImages.isEmpty else {
            alertMessage = "No images to submit."
            showingAlert = true
            return
        }

        camera.lastCaptureStatus = "Submitting images..."
        camera.uploadProgress = 0.0

        Task {
            do {
                let uploader = DocumentUploader()
                
                guard let pdfData = uploader.convertImagesToPDF(camera.capturedImages) else {
                    throw NSError(domain: "CameraCaptureView", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert images to PDF"])
                }
                
                let filePath = try await uploader.uploadPDF(pdfData, userId: userId)
                print("PDF uploaded to: \(filePath)")
                
                camera.lastCaptureStatus = "Images submitted successfully."
                camera.uploadProgress = 1.0
                camera.clearCapturedImages()
                alertMessage = "Images submitted successfully."
                showingAlert = true
                dismiss()
            } catch {
                camera.lastCaptureStatus = "Submission failed: \(error.localizedDescription)"
                camera.uploadProgress = 0.0
                print("Error submitting images: \(error)")
                showingAlert = true
            }
        }
    }
}
