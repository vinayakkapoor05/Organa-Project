//
//  DocumentDetailView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//
import SwiftUI

import SwiftUI
import PDFKit

struct DocumentDetailView: View {
    @StateObject private var documentManager = DocumentManager()
    let documentId: String
    
    var body: some View {
        VStack {
            if documentManager.isLoading {
                ProgressView("Loading document...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = documentManager.errorMessage {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Button("Retry") {
                        documentManager.fetchDocument(documentId: documentId)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let document = documentManager.currentDocument {
                ScrollView {
                    VStack(spacing: 20) {
                        GroupBox {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Status: \(document.status)")
                                    .font(.headline)
                                if let uploadDate = document.uploadDate {
                                    Text("Uploaded: \(uploadDate)")
                                }
                                if let processedDate = document.processedDate {
                                    Text("Processed: \(processedDate)")
                                }
                                if let extractionDate = document.extractionDate {
                                    Text("Text Extracted: \(extractionDate)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        
                        if let pdfData = document.decodedProcessedData {
                            GroupBox {
                                Text("Processed Document")
                                    .font(.headline)
                                PDFKitView(data: pdfData)
                                    .frame(height: 500)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        
                        if let originalData = document.decodedOriginalData {
                            GroupBox {
                                Text("Original Document")
                                    .font(.headline)
                                PDFKitView(data: originalData)
                                    .frame(height: 500)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                        }
                        
                        if let extractedText = document.decodedExtractedText {
                            GroupBox {
                                VStack(alignment: .leading) {
                                    Text("Extracted Text")
                                        .font(.headline)
                                    Text(extractedText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            } else {
                Text("Document not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Document \(documentId)")
        .onAppear {
            documentManager.fetchDocument(documentId: documentId)
        }
    }
}

