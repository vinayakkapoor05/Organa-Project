//
//  APIClient.swift
//  Organa
//
//  Created by Vinayak Kapoor on 12/7/24.
//


import Foundation

class APIClient {
    static let shared = APIClient()
    private let baseURL = "API_BASE_URL_HERE"
    
    private init() {}
    
    func createGroup(userId: String, groupName: String, description: String, completion: @escaping (Result<Group, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/groups/create/\(userId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "group_name": groupName,
            "description": description
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let groupResponse = try decoder.decode(GroupResponse.self, from: data)
                let group = Group(
                    id: groupResponse.group_id,
                    name: groupResponse.group_name,
                    description: groupResponse.description,
                    createdAt: ISO8601DateFormatter().date(from: groupResponse.created_at) ?? Date()
                )
                completion(.success(group))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func listGroups(userId: String, completion: @escaping (Result<[Group], Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/groups/list/\(userId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        let request = URLRequest(url: url)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(APIError.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let listResponse = try decoder.decode(GroupListResponse.self, from: data)
                let groups = listResponse.groups.map { group in
                    Group(
                        id: group.group_id,
                        name: group.group_name,
                        description: group.description,
                        createdAt: ISO8601DateFormatter().date(from: group.created_at) ?? Date()
                    )
                }
                completion(.success(groups))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
    
    func assignDocumentToGroup(groupId: String, documentId: String, completion: @escaping (Result<GroupAssignment, Error>) -> Void) {
        guard let url = URL(string: "\(baseURL)/groups/assign/\(groupId)") else {
            completion(.failure(APIError.invalidURL))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body: [String: Any] = [
            "doc_id": documentId
        ]
        
        print("Assigning Document Request:")
        print("URL: \(url)")
        print("Body: \(body)")
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("Response Status Code: \(httpResponse.statusCode)")
            }
            
            if let error = error {
                print("Network Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion(.failure(APIError.noData))
                return
            }
            
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw Response: \(rawResponse)")
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let assignResponse = try decoder.decode(GroupAssignResponse.self, from: data)
                let assignment = GroupAssignment(
                    id: assignResponse.assignment_id,
                    documentId: documentId,
                    groupId: groupId,
                    assignedAt: ISO8601DateFormatter().date(from: assignResponse.assigned_at) ?? Date()
                )
                completion(.success(assignment))
            } catch {
                print("Decoding Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    enum APIError: Error {
        case invalidURL
        case noData
    }
    
    struct GroupResponse: Codable {
        let group_id: String
        let group_name: String
        let description: String
        let created_at: String
    }
    
    struct GroupListResponse: Codable {
        let user_id: String
        let groups: [GroupResponse]
    }
    
    struct GroupAssignResponse: Codable {
        let message: String
        let assignment_id: String
        let assigned_at: String
    }
}
