//
//  CreateGroupsView.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

import SwiftUI

struct CreateGroupView: View {
    let userId: String
    @Binding var isPresented: Bool
    
    @State private var groupName: String = ""
    @State private var description: String = ""
    @State private var errorMessage: String?
    @State private var showingAlert: Bool = false
    
    var onCreate: (_ success: Bool) -> Void
    
    var body: some View {
        Form {
            Section(header: Text("Group Details")) {
                TextField("Group Name", text: $groupName)
                TextField("Description", text: $description)
            }
        }
        .navigationTitle("Create Group")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    createGroup()
                }
                .disabled(groupName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    
    private func createGroup() {
        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespaces)
        guard !trimmedGroupName.isEmpty else {
            errorMessage = "Group name cannot be empty."
            showingAlert = true
            return
        }
        
        APIClient.shared.createGroup(userId: userId, groupName: trimmedGroupName, description: description) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let group):
                    print("Group created: \(group)")
                    isPresented = false
                    onCreate(true)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    
                }
            }
        }
    }
}
