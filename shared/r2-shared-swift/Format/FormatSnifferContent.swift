//
//  FormatSnifferContent.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/04/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Provides an access to a file's content to sniff its format.
protocol FormatSnifferContent {
    
    /// Reads the whole content as raw bytes.
    func read() -> Data?
    
    /// Raw bytes stream of the content.
    ///
    /// A byte stream can be useful when sniffers only need to read a few bytes at the beginning of
    /// the file.
    func stream() -> InputStream?

}

/// Used to sniff a local file.
final class FormatSnifferFileContent: FormatSnifferContent, Loggable {

    let file: URL
    
    init(file: URL) {
        assert(file.isFileURL || file.scheme == nil)
        self.file = file
    }
    
    func read() -> Data? {
        // We only read files smaller than 100KB to avoid going out of memory.
        guard let length = length, length < 100000 else {
            return nil
        }
        return try? Data(contentsOf: file)
    }

    func stream() -> InputStream? {
        return InputStream(url: file)
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
final class FormatSnifferDataContent: FormatSnifferContent {
    
    lazy var data: Data = getData()
    private let getData: () -> Data
    
    init(data: @escaping () -> Data) {
        self.getData = data
    }
    
    func read() -> Data? {
        return data
    }
    
    func stream() -> InputStream? {
        return InputStream(data: data)
    }

}
