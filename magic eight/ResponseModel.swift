//
//  ResponseModel.swift
//  magic eight
//
//  Created by Charlie Kubal on 12/1/25.
//

import Foundation

struct Response: Codable, Identifiable {
    let id: UUID
    let text: String
    let type: ResponseType
    
    enum ResponseType: String, Codable {
        case positive
        case neutral
        case negative
    }
    
    init(text: String, type: ResponseType) {
        // Use deterministic ID based on text hash for better performance
        // Same text + type always generates same UUID (no random generation overhead)
        let combined = "\(text)|\(type.rawValue)"
        let hash = combined.hashValue
        // Create deterministic UUID from hash
        var uuidBytes = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: hash) { bytes in
            for (index, byte) in bytes.enumerated() where index < 8 {
                uuidBytes[index] = byte
            }
        }
        // Fill remaining with type hash
        let typeHash = type.rawValue.hashValue
        withUnsafeBytes(of: typeHash) { bytes in
            for (index, byte) in bytes.enumerated() where index < 8 {
                uuidBytes[index + 8] = byte
            }
        }
        self.id = UUID(uuid: (uuidBytes[0], uuidBytes[1], uuidBytes[2], uuidBytes[3],
                               uuidBytes[4], uuidBytes[5], uuidBytes[6], uuidBytes[7],
                               uuidBytes[8], uuidBytes[9], uuidBytes[10], uuidBytes[11],
                               uuidBytes[12], uuidBytes[13], uuidBytes[14], uuidBytes[15]))
        self.text = text
        self.type = type
    }
}

// Remote response structure (without id)
struct RemoteResponse: Codable {
    let text: String
    let type: Response.ResponseType
}

struct ResponseData: Codable {
    let responses: [RemoteResponse]
}

enum ResponseSetCategory: String, CaseIterable {
    case styles = "styles"
    case generations = "generations"
    case techEras = "tech eras"
    case popCulture = "pop culture"
}

struct ResponseSet: Identifiable {
    let id: String
    let name: String
    let emoji: String
    let category: ResponseSetCategory
    let responses: [Response]
}

// Remote response set structure
struct RemoteResponseSet: Codable {
    let id: String
    let name: String
    let responses: [RemoteResponse]
}

struct RemoteResponseData: Codable {
    let sets: [RemoteResponseSet]
}

