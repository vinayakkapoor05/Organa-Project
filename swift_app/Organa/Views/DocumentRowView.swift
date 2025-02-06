//
//  DocumentRowView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

import SwiftUI

struct DocumentRowView: View {
    let document: DocumentListItem
    let similarityScore: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Document \(document.id)")
                .font(.headline)
            
            Text("Status: \(document.status.isEmpty ? "N/A" : document.status)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let uploadDate = document.uploadDateFormatted {
                Text("Uploaded: \(uploadDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let similarity = similarityScore {
                Text(String(format: "Similarity: %.2f", similarity))
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

extension DocumentListItem {
    var uploadDateFormatted: String? {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: uploadDate) else { return nil }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date)
    }
}

struct DocumentRowWithActions: View {
    let document: DocumentListItem
    let onAssignGroup: () -> Void
    
    var body: some View {
        HStack {
            DocumentRowView(document: document, similarityScore: nil)
            Spacer()
            Button(action: onAssignGroup) {
                Image(systemName: "folder.badge.plus")
                    .foregroundColor(.blue)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Assign to Group")
        }
        .background(
            NavigationLink(destination: DocumentDetailView(documentId: document.id)) {
                EmptyView()
            }
            .opacity(0)
        )
    }
}
