//
//  Document.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/4/24.
//

import SwiftUI

struct Document: Codable {
    let docId: String
    let originalBucketKey: String?
    let processedBucketKey: String?
    let extractedTextBucketKey: String?
    let status: String
    let uploadDate: String?
    let processedDate: String?
    let extractionDate: String?
    let processedData: String?
    let originalData: String?
    let extractedTextData: String?

    enum CodingKeys: String, CodingKey {
        case docId = "doc_id"
        case originalBucketKey
        case processedBucketKey
        case extractedTextBucketKey
        case status
        case uploadDate = "upload_date"
        case processedDate = "processed_date"
        case extractionDate = "extraction_date"
        case processedData
        case originalData
        case extractedTextData
    }
    
    var decodedProcessedData: Data? {
        guard let processedData = processedData,
              let data = Data(base64Encoded: processedData) else { return nil }
        return data
    }
    
    var decodedOriginalData: Data? {
        guard let originalData = originalData,
              let data = Data(base64Encoded: originalData) else { return nil }
        return data
    }
    
    var decodedExtractedText: String? {
        guard let extractedTextData = extractedTextData,
              let data = Data(base64Encoded: extractedTextData),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text
    }
}
