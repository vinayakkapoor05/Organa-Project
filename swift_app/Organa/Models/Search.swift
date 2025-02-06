//
//  Search.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//

import Foundation

struct SearchResultItem: Codable {
    let docId: String
    let filePath: String
    let extractedTextPath: String
    let similarityScore: Double

    enum CodingKeys: String, CodingKey {
        case docId = "doc_id"

        case filePath = "file_path"
        case extractedTextPath = "extracted_text_path"
        case similarityScore = "similarity_score"
    }
}

struct SearchResponse: Codable {

    let query: String
    let results: [SearchResultItem]
    let totalResults: Int

    enum CodingKeys: String, CodingKey {

        case query
        case results
        case totalResults = "total_results"
    }
}
