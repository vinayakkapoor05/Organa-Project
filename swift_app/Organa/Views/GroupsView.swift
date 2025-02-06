import SwiftUI

struct GroupsView: View {
    enum GroupViewMode {
        case assignDocument
        case viewGroupDocuments
    }
    
    @StateObject private var viewModel = GroupsViewModel()
    @Binding var selectedDocument: DocumentListItem?
    let userId: String
    let mode: GroupViewMode
    var onAssignmentComplete: (Bool, Error?) -> Void?
    
    @State private var selectedGroup: Group?
    
    var body: some View {
        VStack {
            if viewModel.isLoading {
                ProgressView("Loading groups...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                VStack {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                    Button("Retry") {
                        viewModel.fetchGroups(userId: userId)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.groups.isEmpty {
                VStack {
                    Text("No groups found")
                    Button("Create Group") {
                        viewModel.showingCreateGroup = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.groups) { group in
                    Button(action: {
                        handleGroupSelection(group: group)
                    }) {
                        GroupRowView(group: group)
                    }
                }
            }
        }
        .navigationTitle(mode == .assignDocument ? "Select Group to Assign" : "Your Groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.showingCreateGroup = true
                }) {
                    Image(systemName: "plus")
                }
                .help("Create New Group")
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    onAssignmentComplete(false, nil)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingCreateGroup) {
            NavigationView {
                CreateGroupView(
                    userId: userId,
                    isPresented: $viewModel.showingCreateGroup,
                    onCreate: { success in
                        if success {
                            viewModel.fetchGroups(userId: userId)
                        }
                    }
                )
            }
            .frame(minWidth: 400, minHeight: 300)
        }
        .onAppear {
            viewModel.fetchGroups(userId: userId)
        }
        .frame(minWidth: 500, minHeight: 400)
    }
    
    private func handleGroupSelection(group: Group) {
        switch mode {
        case .assignDocument:
            assignDocumentToGroup(group: group)
        case .viewGroupDocuments:
            selectedGroup = group
        }
    }
    
    private func assignDocumentToGroup(group: Group) {
        guard mode == .assignDocument else { return }
        
        guard let document = selectedDocument else {
            onAssignmentComplete(false, NSError(domain: "GroupsView",
                                                code: -1,
                                                userInfo: [NSLocalizedDescriptionKey: "No document selected"]))
            return
        }
        
        viewModel.assignDocumentToGroup(groupId: group.id, documentId: document.id) { success, error in
            onAssignmentComplete(success, error)
        }
    }
}
    
struct GroupRowView: View {
    let group: Group
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(group.name)
                    .font(.headline)
                Text(group.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .frame(maxWidth: .infinity)
        .padding()
    }
}
