//
//  Copyright 2024 Readium Foundation. All rights reserved.
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

//    convenience init(file: URL) throws {
//        try self.init(writer: DatabaseQueue(path: file.path))
//    }

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
    
    func observe<T>(_ query: @escaping (GRDB.Database) throws -> T) -> AnyPublisher<T, Never> {
        ValueObservation.tracking(query)
            .publisher(in: writer)
            .assertNoFailure()
            .eraseToAnyPublisher()
    }

//    private init(writer: DatabaseWriter = DatabaseQueue()) throws {
//        self.writer = writer
//
//        try writer.write { db in
//            try db.create(table: "book", ifNotExists: true) { t in
//                t.autoIncrementedPrimaryKey("id")
//                t.column("identifier", .text)
//                t.column("title", .text).notNull()
//                t.column("authors", .text)
//                t.column("type", .text).notNull()
//                t.column("path", .text).notNull()
//                t.column("coverPath", .text)
//                t.column("locator", .text)
//                t.column("progression", .integer).notNull().defaults(to: 0)
//                t.column("created", .datetime).notNull()
//                t.column("preferencesJSON", .text)
//            }
//
//            try db.create(table: "bookmark", ifNotExists: true) { t in
//                t.autoIncrementedPrimaryKey("id")
//                t.column("bookId", .integer).references("book", onDelete: .cascade).notNull()
//                t.column("locator", .text)
//                t.column("progression", .double).notNull()
//                t.column("created", .datetime).notNull()
//            }
//
//            try db.create(table: "highlight", ifNotExists: true) { t in
//                t.column("id", .text).primaryKey()
//                t.column("bookId", .integer).references("book", onDelete: .cascade).notNull()
//                t.column("locator", .text)
//                t.column("progression", .double).notNull()
//                t.column("color", .integer).notNull()
//                t.column("created", .datetime).notNull()
//            }
//
//            // create an index to make sorting by progression faster
//            try db.create(index: "index_highlight_progression", on: "highlight", columns: ["bookId", "progression"], ifNotExists: true)
//            try db.create(index: "index_bookmark_progression", on: "bookmark", columns: ["bookId", "progression"], ifNotExists: true)
//        }
//    }

//    func read<T>(_ query: @escaping (GRDB.Database) throws -> T) async throws -> T {
//        try await withCheckedThrowingContinuation { cont in
//            writer.asyncRead { db in
//                do {
//                    let db = try db.get()
//                    try cont.resume(returning: query(db))
//                } catch {
//                    cont.resume(throwing: error)
//                }
//            }
//        }
//    }

//    @discardableResult
//    func write<T>(_ updates: @escaping (GRDB.Database) throws -> T) async throws -> T {
//        try await withCheckedThrowingContinuation { cont in
//            writer.asyncWrite(
//                { try updates($0) },
//                completion: { _, result in
//                    cont.resume(with: result)
//                }
//            )
//        }
//    }

//    func observe<T>(_ query: @escaping (GRDB.Database) throws -> T) -> AnyPublisher<T, Error> {
//        ValueObservation.tracking(query)
//            .publisher(in: writer)
//            .eraseToAnyPublisher()
//    }
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
        try self.init(rawValue: decoder.singleValueContainer().decode(Int64.self))!
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
