//
//  ContainerCbzDirectory.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/3/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// CBZ Container for CBZs unzipped in a directory.
public class ContainerCbzDirectory: CbzContainer, DirectoryContainer {

    /// Struct containing meta information about the Container.
    public var rootFile: RootFile

    // MARK: - Public methods.

    /// Public failable initializer for the EpubDirectoryContainer class.
    ///
    /// - Parameter dirPath: The root directory path.
    public init?(directory path: String) {
        // FIXME: useless check probably. Always made before hand.
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        rootFile = RootFile.init(rootPath: path)
    }

    public func getFilesList() -> [String] {
        guard let path =  rootFile.rootPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: path) else
        {
            return []
        }
        guard let list = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: []) else {
            return []
        }
        return list.map({ $0.path.lastPathComponent })
    }
}
