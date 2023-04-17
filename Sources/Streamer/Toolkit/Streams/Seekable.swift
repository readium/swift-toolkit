//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Reference point for offset in seekable streams.
public enum SeekWhence {
    /// The beginning of the file.
    case startOfFile
    /// The end of the file.
    case endOfFile
    /// the current position in the file.
    case currentPosition
}

/// Protocol for seekable resources.
public protocol Seekable {
    /// The total length of the data.
    var length: UInt64 { get }
    /// The current offset in the data
    var offset: UInt64 { get }

    /// Set the current position in the data stream.
    ///
    /// - Parameters:
    ///   - offset: The offset to seek to.
    ///   - whence: Specifies the beginning, the end or the current position as
    ///             the reference point for `offset`.
    /// - Throws: Defined in the override.
    func seek(offset: Int64, whence: SeekWhence) throws
}

/// Base (abstract) class for seekable input streams
open class SeekableInputStream: InputStream, Seekable {
    public var length: UInt64 { fatalError("This getter must be overriden") }

    public var offset: UInt64 { fatalError("This getter must be overriden") }

    public func seek(offset: Int64, whence: SeekWhence) throws {
        setProperty(offset, forKey: Stream.PropertyKey.fileCurrentOffsetKey)
        fatalError("This getter must be overriden")
    }

    override public init(data: Data = Data()) {
        super.init(data: data)
    }
}
