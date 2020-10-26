//
//  File.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// Represents a path on the file system.
///
/// Used to cache the `Format` to avoid computing it at different locations.
public final class File: Loggable {
    
    /// File URL on the file system.
    public let url: URL
    
    /// Last path component, or filename.
    public var name: String { url.lastPathComponent }
    
    /// Indicates whether the path points to a directory.
    ///
    /// This can be used to open exploded publication archives.
    /// *Warning*: This should not be called from the UI thread.
    public lazy var isDirectory: Bool = {
        warnIfMainThread()
        return (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }()

    private let mediaTypeHint: String?
    private let knownFormat: Format?
    
    /// Creates a `File` from a file `url`.
    ///
    /// Providing a known `mediaType` will improve performances when sniffing the file format.
    public init(url: URL, mediaType: String? = nil) {
        self.url = url
        self.mediaTypeHint = mediaType
        self.knownFormat = nil
    }

    /// Creates a `File` from a file `url`.
    ///
    /// Providing a known `format` will improve performances when sniffing the file format.
    public init(url: URL, format: Format?) {
        self.url = url
        self.mediaTypeHint = nil
        self.knownFormat = format
    }

    /// Sniffed format of this file.
    ///
    /// *Warning*: This should not be called from the UI thread.
    public lazy var format: Format? = {
        warnIfMainThread()
        if let format = knownFormat {
            return format
        } else {
            return Format.of(url, mediaType: mediaTypeHint)
        }
    }()

}
