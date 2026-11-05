//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension FileHandle {
    /// Streams the bytes at the given `range` of the file, in chunks of at
    /// most `chunkSize` bytes.
    ///
    /// The bytes are read at their position in the file, without moving the
    /// offset of the file handle. Overlapping streams on the same handle are
    /// therefore independent.
    ///
    /// A range overlapping the end of the file is clamped. The cancellation of
    /// the task is checked between two chunks.
    @concurrent func stream(
        range: Range<UInt64>,
        chunkSize: Int = 256 * 1024,
        consume: @Sendable (Data) -> Void
    ) async -> ReadResult<Void> {
        precondition(chunkSize > 0)

        let descriptor = fileDescriptor
        let range = range.clamped(to: 0 ..< UInt64(off_t.max))
        var position = range.lowerBound

        while position < range.upperBound {
            guard !Task.isCancelled else {
                return .failure(.cancelled)
            }

            var chunk = Data(count: Int(min(UInt64(chunkSize), range.upperBound - position)))
            let (count, code) = chunk.withUnsafeMutableBytes { buffer in
                let count = pread(descriptor, buffer.baseAddress, buffer.count, off_t(position))
                return (count, errno)
            }

            guard count >= 0 else {
                if code == EINTR {
                    continue
                }
                let error = POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
                return .failure(.wrap(error) ?? .access(.fileSystem(.io(error))))
            }
            guard count > 0 else {
                // Reached the end of the file.
                break
            }

            chunk.count = count
            consume(chunk)
            position += UInt64(count)
        }

        return .success(())
    }
}
