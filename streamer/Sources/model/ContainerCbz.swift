//
//  CbzContainer.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/31/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

// Logger injection.
extension ContainerCbz: Loggable {}

public class ContainerCbz: CbzContainer, ZipArchiveContainer {
    public var rootFile: RootFile

    /// The zip archive object containing the Epub.
    var zipArchive: ZipArchive

    /// Public failable initializer for the Container protocol.
    ///
    /// - Parameter path: Path to the archive file.
    public init?(path: String) {
        guard let arc = ZipArchive(url: URL(fileURLWithPath: path)) else {
            return nil
        }
        rootFile = RootFile.init(rootPath: path, mimetype: "application/x-cbz")
        zipArchive = arc
        /// Generate file list.
        do {
            try zipArchive.buildFilesList()
        } catch {
            log(level: .error, "zipArchive error generating file List")
            return nil
        }
    }

    public func getFilesList() -> [String] {
        let archivedFilesList = zipArchive.fileInfos.map({
            URL(fileURLWithPath: $0.key).lastPathComponent
        }).sorted()

        return archivedFilesList
    }
}
