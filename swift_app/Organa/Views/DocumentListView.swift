//
//  DocumentListView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//
import SwiftUI

struct DocumentListView: View {
    @StateObject private var documentManager = DocumentManager()
    @Binding var selectedDocument: DocumentListItem?
    let userId: String
    
    @State private var showingGroupsView = false
    @State private var documentToAssign: DocumentListItem? = nil
    @State private var assignmentSuccessMessage: String? = nil
    @State private var assignmentErrorMessage: String? = nil
    @State private var showingAssignmentAlert = false
    
    var body: some View {
        VStack {
            if documentManager.isLoading {
                ProgressView("Loading documents...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = documentManager.errorMessage {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Button("Retry") {
                        documentManager.fetchDocumentList(userId: userId)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if documentManager.documentList.isEmpty {
                Text("No documents found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(documentManager.documentList, id: \.id) { document in
                    DocumentRowWithActions(
                        document: document,
                        onAssignGroup: {
                            documentToAssign = document
                            showingGroupsView = true
                        }
                    )
                }
                .listStyle(InsetListStyle())
            }
        }
        .navigationTitle("Documents")
        .onAppear {
            documentManager.fetchDocumentList(userId: userId)
        }
        .sheet(isPresented: $showingGroupsView) {
            NavigationView {
                GroupsView(
                    selectedDocument: $documentToAssign,
                    userId: userId,
                    mode: .assignDocument

                ) { success, error in
                    handleAssignmentResult(success: success, error: error)
                    showingGroupsView = false
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }

        .alert(isPresented: $showingAssignmentAlert) {
            createAssignmentAlert()
        }
    }
    
    private func handleAssignmentResult(success: Bool, error: Error?) {
        if success {
            assignmentSuccessMessage = "Document assigned successfully."
            assignmentErrorMessage = nil
        } else if let error = error {
            assignmentSuccessMessage = nil
            assignmentErrorMessage = error.localizedDescription
        }
        showingGroupsView = false
        showingAssignmentAlert = true
        
        if success {
            documentManager.fetchDocumentList(userId: userId)
        }
    }
    
    private func createAssignmentAlert() -> Alert {
        if let successMessage = assignmentSuccessMessage {
            return Alert(
                title: Text("Success"),
                message: Text(successMessage),
                dismissButton: .default(Text("OK"))
            )
        } else if let errorMessage = assignmentErrorMessage {
            return Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        } else {
            return Alert(
                title: Text("Unknown"),
                message: Text("An unexpected error occurred."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}
