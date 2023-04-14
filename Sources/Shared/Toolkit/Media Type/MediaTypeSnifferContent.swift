//
//  Copyright 2023 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides an access to a file's content to sniff its media type.
protocol MediaTypeSnifferContent {
    /// Reads the whole content as raw bytes.
    func read() -> Data?

    /// Raw bytes stream of the content.
    ///
    /// A byte stream can be useful when sniffers only need to read a few bytes at the beginning of
    /// the file.
    func stream() -> InputStream?
}

/// Used to sniff a local file.
final class FileMediaTypeSnifferContent: MediaTypeSnifferContent, Loggable {
    let file: URL

    init?(file: URL) {
        guard file.isFileURL || file.scheme == nil else {
            return nil
        }

        self.file = file
    }

    func read() -> Data? {
        // We only read files smaller than 5MB to avoid going out of memory.
        guard let length = length, length < 5 * 1000 * 1000 else {
            return nil
        }
        return try? Data(contentsOf: file)
    }

    func stream() -> InputStream? {
        InputStream(url: file)
    }

    private lazy var length: Int? = {
        do {
            return try file.resourceValues(forKeys: [.fileSizeKey]).fileSize
        } catch {
            log(.error, error)
            return nil
        }
    }()
}

/// Used to sniff a bytes array.
final class DataMediaTypeSnifferContent: MediaTypeSnifferContent {
    lazy var data: Data = getData()
    private let getData: () -> Data

    init(data: @escaping () -> Data) {
        getData = data
    }

    func read() -> Data? {
        data
    }

    func stream() -> InputStream? {
        InputStream(data: data)
    }
}
