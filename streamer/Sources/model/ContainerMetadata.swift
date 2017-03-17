//
//  RootFile.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

// TODO: support multiple renditions in the future, hence multiple rootFiles?

/// RootFile (as called in Go).
/// Contains meta-informations about the Container containing the EPUB.
public struct ContainerMetadata {

    /// For Epub : Path to the Epub file. (previously epubFilePath)
    /// For EpubDirectory : The root directory path. (Previously rootPath)
    public var rootPath: String

    /// Path to the OPF file (rootFile).
    public var rootFilePath: String

    /// The mimetype of the container.
    public var mimetype: String

    // The Epub version of the Epub Payload.
    public var epubVersion: Double?

    // MARK: - Public methods.

    init(rootPath: String,
         rootFilePath: String = "",
         mimetype: String = "",
         epubVersion: Double? = nil) {
        self.rootPath = rootPath
        self.rootFilePath = rootFilePath
        self.mimetype = mimetype
        self.epubVersion = epubVersion
    }
}
