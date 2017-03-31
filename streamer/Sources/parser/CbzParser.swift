//
//  CbzParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/31/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public class CbzParser {

    public func parse(fileAtPath path: String) throws /*-> Epub*/ {
        // Generate the `Container` for `fileAtPath`
        var container = try generateContainerFrom(fileAtPath: path)
    }

    /// Generate a Container instance for the file at `fileAtPath`. It handles
    /// 2 cases, epub files and unwrapped epub directories.
    ///
    /// - Parameter path: The absolute path of the file.
    /// - Returns: The generated Container.
    /// - Throws: `EpubParserError.missingFile`.
    fileprivate func generateContainerFrom(fileAtPath path: String) throws -> Container {
        var isDirectory: ObjCBool = false
        var container: Container?

        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) else {
            throw EpubParserError.missingFile(path: path)
        }
        if isDirectory.boolValue {
            container = ContainerEpubDirectory(directory: path)
        } else {
            container = ContainerEpub(path: path)
        }
        guard let containerUnwrapped = container else {
            throw EpubParserError.missingFile(path: path)
        }
        return containerUnwrapped
    }
}
