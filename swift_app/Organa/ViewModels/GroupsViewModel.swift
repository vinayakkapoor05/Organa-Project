//
//  GroupsViewModel.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

import Foundation

class GroupsViewModel: ObservableObject {
    @Published var groups: [Group] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingCreateGroup = false
    
    func fetchGroups(userId: String) {
        isLoading = true
        APIClient.shared.listGroups(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let groups):
                    self?.groups = groups
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func assignDocumentToGroup(groupId: String, documentId: String, completion: @escaping (Bool, Error?) -> Void) {
        guard !groupId.isEmpty, !documentId.isEmpty else {
            completion(false, NSError(domain: "GroupsViewModel",
                                      code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Invalid group or document ID"]))
            return
        }
        
        APIClient.shared.assignDocumentToGroup(groupId: groupId, documentId: documentId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    completion(true, nil)
                case .failure(let error):
                    print("Document Assignment Error: \(error.localizedDescription)")
                    completion(false, error)
                }
            }
        }
    }
}

