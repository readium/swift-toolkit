//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import GRDB
import ReadiumShared

final class Database {
    convenience init(file: URL) throws {
        try self.init(writer: DatabaseQueue(path: file.path))
    }

    private let writer: DatabaseWriter

    private init(writer: DatabaseWriter) throws {
        self.writer = writer

        var migrator = DatabaseMigrator()
        migrator.registerMigration("initial") { db in
            try db.create(table: "book") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("identifier", .text)
                t.column("title", .text).notNull()
                t.column("authors", .text)
                t.column("type", .text).notNull()
                t.column("url", .text).notNull()
                t.column("coverPath", .text)
                t.column("locator", .text)
                t.column("progression", .integer).notNull().defaults(to: 0)
                t.column("created", .datetime).notNull()
                t.column("preferencesJSON", .text)
            }

            try db.create(table: "bookmark") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bookId", .integer).references("book", onDelete: .cascade).notNull()
                t.column("locator", .text)
                t.column("progression", .double).notNull()
                t.column("created", .datetime).notNull()
            }

            try db.create(table: "highlight") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("bookId", .integer).references("book", onDelete: .cascade).notNull()
                t.column("locator", .text)
                t.column("progression", .double).notNull()
                t.column("color", .integer).notNull()
                t.column("created", .datetime).notNull()
            }

            // create an index to make sorting by progression faster
            try db.create(index: "index_highlight_progression", on: "highlight", columns: ["bookId", "progression"], ifNotExists: true)
            try db.create(index: "index_bookmark_progression", on: "bookmark", columns: ["bookId", "progression"], ifNotExists: true)
        }

        try migrator.migrate(writer)
    }

    func read<T>(_ query: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            writer.asyncRead { db in
                do {
                    let db = try db.get()
                    try cont.resume(returning: query(db))
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }

    @discardableResult
    func write<T>(_ updates: @escaping (GRDB.Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            writer.asyncWrite(
                { try updates($0) },
                completion: { _, result in
                    cont.resume(with: result)
                }
            )
        }
    }

    func observe<T>(_ query: @escaping (GRDB.Database) throws -> T) -> AnyPublisher<T, Error> {
        ValueObservation.tracking(query)
            .publisher(in: writer)
            .eraseToAnyPublisher()
    }
}

/// Protocol for a database entity id.
///
/// Using this instead of regular integers makes the code safer, because we can only give ids of the
/// right model in APIs. It also helps self-document APIs.
protocol EntityId: Codable, Hashable, RawRepresentable, ExpressibleByIntegerLiteral, CustomStringConvertible, DatabaseValueConvertible where RawValue == Int64 {}

extension EntityId {
    var string: String {
        String(rawValue)
    }

    init?(string: String) {
        guard let rawValue = Int64(string) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }
}

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
