//
//  Sidebar.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//
import SwiftUI

struct Sidebar: View {
    @Binding var showingCamera: Bool
    let userId: String
    @Binding var selectedDocument: DocumentListItem?
    
    @State private var assignmentSuccessMessage: String? = nil
    @State private var assignmentErrorMessage: String? = nil
    @State private var showingAssignmentAlert: Bool = false

    var body: some View {
        List {
            NavigationLink(destination: DocumentListView(selectedDocument: $selectedDocument, userId: userId)) {
                Label("Documents", systemImage: "doc.text")
            }
            NavigationLink(destination: GroupsView(
                selectedDocument: $selectedDocument,
                userId: userId,
                mode: .viewGroupDocuments,
                onAssignmentComplete: { success, error in
                }
            )) {
                Label("Groups", systemImage: "person.3")
            }

            NavigationLink(destination: SearchView(userId: userId)) {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Organa")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingCamera = true }) {
                    Label("Capture Document", systemImage: "camera")
                }
            }
        }
        .alert(isPresented: $showingAssignmentAlert) {
            if let successMessage = assignmentSuccessMessage {
                return Alert(title: Text("Success"), message: Text(successMessage), dismissButton: .default(Text("OK")))
            } else if let errorMessage = assignmentErrorMessage {
                return Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
            } else {
                return Alert(title: Text("Unknown"), message: Text("An unexpected error occurred."), dismissButton: .default(Text("OK")))
            }
        }
    }
}
