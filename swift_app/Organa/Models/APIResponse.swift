//
//  APIResponse.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//
struct APIResponse: Codable {
    let statusCode: Int
    let headers: [String: String]
    let body: String
}

struct DocumentListResponse: Codable {
    let documents: [DocumentListItem]
}

struct DocumentListItem: Identifiable, Codable, Hashable {
    let id: String
    let originalDataFile: String
    let uploadDate: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id = "documentid"
        case originalDataFile = "originaldatafile"
        case uploadDate = "upload_date"
        case status
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: DocumentListItem, rhs: DocumentListItem) -> Bool {
        lhs.id == rhs.id
    }
}

