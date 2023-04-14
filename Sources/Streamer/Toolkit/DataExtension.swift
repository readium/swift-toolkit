//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension Data {
    static func reading(_ stream: InputStream, bufferSize: Int = 32768) throws -> Data {
        if let dataStream = stream as? DataInputStream {
            return dataStream.data
        }

        var data = Data()
        stream.open()
        defer {
            stream.close()
        }

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer {
            buffer.deallocate()
        }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read < 0 {
                throw stream.streamError ?? NSError()
            } else if read == 0 {
                break // EOF
            }
            data.append(buffer, count: read)
        }

        return data
    }
}
