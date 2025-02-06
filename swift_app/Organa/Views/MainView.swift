//
//  MainView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//
import SwiftUI

struct MainView: View {
    let userId: String
    @Binding var isLoggedIn: Bool
    @State private var selectedDocument: DocumentListItem?
    @State private var showingCamera = false

    var body: some View {
        NavigationSplitView {
            Sidebar(showingCamera: $showingCamera, userId: userId, selectedDocument: $selectedDocument)
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button(action: {
                            isLoggedIn = false
                        }) {
                            Text("Logout")
                                .foregroundColor(.red)
                        }
                    }
                }
        } detail: {
            if let selectedDocument = selectedDocument {
                DocumentDetailView(documentId: selectedDocument.id)
            } else {
                DocumentListView(selectedDocument: $selectedDocument, userId: userId)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView(userId: userId)
        }
    }
}

