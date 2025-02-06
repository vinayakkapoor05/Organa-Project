//
//  DocumentManager.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import SwiftUI
import Combine

import SwiftUI
import Combine

class DocumentManager: ObservableObject {
    @Published var documentList: [DocumentListItem] = []
    @Published var currentDocument: Document?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let baseURL = "API_BASE_URL"
    
    func fetchDocumentList(userId: String) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: baseURL + "documents/" + userId) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received"
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString)
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode(DocumentListResponse.self, from: data)
                    self?.documentList = response.documents
                } catch {
                    self?.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func fetchDocument(documentId: String) {
        isLoading = true
        errorMessage = nil
        
        guard let url = URL(string: baseURL + "document/" + documentId) else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }
        
        print("🔍 Fetching document with URL: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.errorMessage = "No HTTP response received"
                    return
                }
                
                
                guard httpResponse.statusCode == 200, let data = data else {
                    if let data = data, let errorMessage = String(data: data, encoding: .utf8) {
                        self?.errorMessage = "Error: \(errorMessage)"
                    } else {
                        self?.errorMessage = "Unexpected server error (Status code: \(httpResponse.statusCode))"
                    }
                    return
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print(jsonString)
                }
                
                do {
                    let decoder = JSONDecoder()
                    
                    let document = try decoder.decode(Document.self, from: data)
                    self?.currentDocument = document
                    
                } catch {
                    self?.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

