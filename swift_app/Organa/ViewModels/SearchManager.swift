//
//  SearchManager.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

//
//  SearchManager.swift
//  Organa
//

import Foundation

struct APIErrorResponse: Codable {
    let error: String
}

class SearchManager: ObservableObject {
    @Published var searchResults: [SearchResultItem] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    private let baseURL = "API_SEARCH_BASE_URL"
    
    func performSearch(userId: String, query: String, limit: Int = 5, threshold: Double = 0.4) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.errorMessage = "Search query cannot be empty."
            return
        }
        
        isLoading = true
        errorMessage = nil
        searchResults = []
        
        let fullPath = "\(baseURL)/\(userId)"
        var urlComponents = URLComponents(string: fullPath)
        
        urlComponents?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "threshold", value: "\(threshold)")
        ]
        
        guard let url = urlComponents?.url else {
            self.errorMessage = "Invalid search URL."
            self.isLoading = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("Request URL: \(url.absoluteString)")
        print("Path: \(url.path)")
        print("Query: \(url.query ?? "no query")")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self?.errorMessage = "No data received from search API."
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("Response status code: \(httpResponse.statusCode)")
                }
                
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Received JSON: \(jsonString)")
                }
                
                do {
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                        self?.errorMessage = errorResponse.error
                        return
                    }
                    
                    let decoder = JSONDecoder()
                    if let searchResponse = try? decoder.decode(SearchResponse.self, from: data) {
                        self?.searchResults = searchResponse.results
                    } else {
                        let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                        if let bodyString = json?["body"] as? String,
                           let bodyData = bodyString.data(using: .utf8),
                           let searchResponse = try? decoder.decode(SearchResponse.self, from: bodyData) {
                            self?.searchResults = searchResponse.results
                        } else {
                            throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
                        }
                    }
                } catch {
                    self?.errorMessage = "Failed to decode search results: \(error.localizedDescription)"
                    print("Decoding error details: \(error)")
                }
            }
        }.resume()
    }
}
