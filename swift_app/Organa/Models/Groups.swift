//
//  Groups.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

import Foundation

struct Group: Identifiable, Codable {
    let id: String
    let name: String
    let description: String
    let createdAt: Date
}

struct GroupAssignment: Identifiable, Codable {
    let id: String
    let documentId: String
    let groupId: String
    let assignedAt: Date
}
