//
//  SearchView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

import SwiftUI

struct SearchView: View {
    let userId: String
    @StateObject private var searchManager = SearchManager()
    @State private var query: String = ""

    var body: some View {
        VStack {
            HStack {
                TextField("Enter search query...", text: $query, onCommit: {
                    performSearch()
                })
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

                Button(action: {
                    performSearch()
                }) {
                    Image(systemName: "magnifyingglass")
                }
                .padding()
            }

            if searchManager.isLoading {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = searchManager.errorMessage {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Button("Retry") {
                        performSearch()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchManager.searchResults.isEmpty && !query.isEmpty {
                Text("No matching documents found.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchManager.searchResults, id: \.filePath) { result in
                    NavigationLink(destination: DocumentDetailView(documentId: result.docId)) { 
                        SearchResultRowView(searchResult: result)
                    }
                }
                .listStyle(InsetListStyle())
            }
        }
        .navigationTitle("Search Documents")
        .padding(.top)
    }

    private func performSearch() {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else {
            return
        }
        searchManager.performSearch(userId: userId, query: trimmedQuery)
    }
}

import SwiftUI

struct SearchResultRowView: View {
    let searchResult: SearchResultItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("File: \(searchResult.filePath)")
                .font(.headline)
            Text("Extracted Text Path: \(searchResult.extractedTextPath)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(String(format: "Similarity: %.2f", searchResult.similarityScore))
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}
