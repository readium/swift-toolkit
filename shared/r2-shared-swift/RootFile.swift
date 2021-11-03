//
//  RootFile.swift
//  r2-shared-swift
//
//  Created by Alexandre Camilleri on 3/3/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// RootFile (as called in Go).
/// Contains meta-informations about the Container containing the EPUB.
public struct RootFile {

    /// For Epub : Path to the Epub file. (previously epubFilePath)
    /// For EpubDirectory : The root directory path. (Previously rootPath)
    public var rootPath: String

    /// Path to the OPF file (rootFile).
    public var rootFilePath: String

    /// The mimetype.
    public var mimetype: String

    // The container version.
    public var version: Double?

    // MARK: - Public methods.

    public init(rootPath: String, rootFilePath: String = "",
         mimetype: String = "", version: Double? = nil)
    {
        self.rootPath = rootPath
        self.rootFilePath = rootFilePath
        self.mimetype = mimetype
        self.version = version
    }
}
