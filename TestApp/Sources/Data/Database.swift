//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB
import SwiftUI

/// Database migration to be performed when updating the app.
protocol DatabaseMigration {
    /// Schema version for this migration.
    var version: Int { get }
    
    /// Applies the migration.
    func run(on db: GRDB.Database) throws
}

final class Database {
    
    convenience init(file: URL, migrations: [DatabaseMigration]) throws {
        try self.init(writer: try DatabaseQueue(path: file.path), migrations: migrations)
    }
    
    private let writer: DatabaseWriter
    
    private init(writer: DatabaseWriter = DatabaseQueue(), migrations: [DatabaseMigration]) throws {
        self.writer = writer
        
        try run(migrations)
    }
    
    /// Runs the database migrations on `Database` initialization.
    private func run(_ migrations: [DatabaseMigration]) throws {
        try writer.write { db in
            let currentVersion = try Int64.fetchOne(db, sql: "PRAGMA user_version") ?? 0
            
            try migrations
                .filter { $0.version > currentVersion }
                .sorted { $0.version < $1.version }
                .forEach { try run($0, on: db) }
        }
    }
    
    private func run(_ migration: DatabaseMigration, on db: GRDB.Database) throws {
        try migration.run(on: db)
        try db.execute(sql: "PRAGMA user_version = \(migration.version)")
    }
    
    func read<T>(_ value: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            writer.asyncRead { result in
                do {
                    try continuation.resume(returning: value(result.get()))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    @discardableResult
    func write<T>(_ updates: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await withUnsafeThrowingContinuation { continuation in
            writer.asyncWrite(updates) { _, result in
                continuation.resume(with: result)
            }
        }
    }
    
    func writePublisher<T>(_ updates: @escaping (GRDB.Database) throws -> T) -> AnyPublisher<T, Error> {
        writer.writePublisher(updates: updates)
            .eraseToAnyPublisher()
    }
    
    func observe<T>(_ query: @escaping (GRDB.Database) throws -> T) -> AnyPublisher<T, Error> {
        ValueObservation.tracking(query)
            .publisher(in: writer)
            .eraseToAnyPublisher()
    }
}

extension Database {
    /// Provides a read-only access to the database
    var databaseReader: DatabaseReader {
        writer
    }
}

/// Protocol for a database entity id.
///
/// Using this instead of regular integers makes the code safer, because we can only give ids of the
/// right model in APIs. It also helps self-document APIs.
protocol EntityId: Codable, Hashable, RawRepresentable, ExpressibleByIntegerLiteral, CustomStringConvertible, DatabaseValueConvertible where RawValue == Int64 {}

extension EntityId {
    
    // MARK: - ExpressibleByIntegerLiteral
    
    init(integerLiteral value: Int64) {
        self.init(rawValue: value)!
    }
    
    // MARK: - Codable
    
    init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(Int64.self))!
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
    // MARK: - CustomStringConvertible
    
    var description: String {
        "\(Self.self)(\(rawValue))"
    }
    
    // MARK: - DatabaseValueConvertible
    
    var databaseValue: DatabaseValue { rawValue.databaseValue }
    
    static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        Int64.fromDatabaseValue(dbValue).map(Self.init)
    }
}
