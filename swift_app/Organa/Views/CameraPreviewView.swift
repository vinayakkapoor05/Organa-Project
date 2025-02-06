//
//  CameraPreviewView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import SwiftUI
import AVFoundation

struct CameraPreview: NSViewRepresentable {
    private let session: AVCaptureSession
    
    init(session: AVCaptureSession) {
        self.session = session
    }
    
    func makeNSView(context: Context) -> CaptureVideoPreview {
        CaptureVideoPreview(session: session)
    }
    
    func updateNSView(_ nsView: CaptureVideoPreview, context: Context) {}
    
    class CaptureVideoPreview: NSView {
        private let previewLayer: AVCaptureVideoPreviewLayer
        
        init(session: AVCaptureSession) {
            self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
            super.init(frame: .zero)
            self.wantsLayer = true
            self.layer = previewLayer
            self.previewLayer.videoGravity = .resizeAspectFill
        }
        
        override func layout() {
            super.layout()
            previewLayer.frame = self.bounds
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}
