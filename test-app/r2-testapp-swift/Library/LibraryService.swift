//
//  LibraryService.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 20.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared
import R2Streamer


struct Location {
    let absolutePath: String
    let relativePath: String
    let type: PublicationType
}

protocol LibraryServiceDelegate: AnyObject {
    
    func reloadLibrary(with downloadTask: URLSessionDownloadTask?)
    
}

final class LibraryService {
    
    weak var delegate: LibraryServiceDelegate?
    
    let publicationServer: PublicationServer

    /// Publications waiting to be added to the PublicationServer (first opening).
    /// publication identifier : data
    var items = [String: (Container, PubParsingCallback)]()
    
    var drmLibraryServices = [DRMLibraryService]()
    
    init(publicationServer: PublicationServer) {
        self.publicationServer = publicationServer
        
        #if LCP
        drmLibraryServices.append(LCPLibraryService())
        #endif

        // Parse publications (just the OPF and Encryption for now)
        lightParseSamplePublications()
        lightParsePublications()
    }

    func showInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "OK", style: .cancel)
        
        alert.addAction(dismissButton)
        alert.title = title
        alert.message = message
        
        guard let rootViewController = UIApplication.shared.delegate?.window??.rootViewController else {
            return
        }
        if let _  = rootViewController.presentedViewController {
            rootViewController.dismiss(animated: true) {
                rootViewController.present(alert, animated: true)
            }
        } else {
            rootViewController.present(alert, animated: true)
        }
    }

    @discardableResult
    internal func addPublicationToLibrary(url sourceUrl: URL, from downloadTask: URLSessionDownloadTask?) -> Bool {
        
        let repository = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        var url = repository.appendingPathComponent(sourceUrl.lastPathComponent)
        if FileManager().fileExists(atPath: url.path) {
            url = repository.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
        }
        
        /// Move Publication to documents.
        do {
            try FileManager.default.moveItem(at: sourceUrl, to: url)
            let dateAttribute = [FileAttributeKey.modificationDate: Date()]
            try FileManager.default.setAttributes(dateAttribute, ofItemAtPath: url.path)
            
        } catch {
            showInfoAlert(title: "Error", message: "Failed importing this publication \(error)")
            return false
        }
        
        @discardableResult
        func addPublication(url: URL, downloadTask: URLSessionDownloadTask?) -> Bool {
            /// Add the publication to the publication server.
            let location = Location(
                absolutePath: url.path,
                relativePath: url.lastPathComponent,
                type: PublicationType(url: url)
            )
            guard lightParsePublication(at: location) else {
                showInfoAlert(title: "Error", message: "The publication isn't valid.")
                try? FileManager.default.removeItem(at: url)
                return false
            }
            
            delegate?.reloadLibrary(with: downloadTask)
            return true
        }
        
        if let drmService = drmLibraryServices.first(where: { $0.canFulfill(url) }) {
            drmService.fulfill(url) { result in
                let fileManager = FileManager.default
                try? fileManager.removeItem(at: url)
                
                switch result {
                case .success(let publication):
                    do {
                        // Moves the fulfilled publication to Documents/
                        let repository = try! fileManager
                            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        var destinationFile = repository
                            .appendingPathComponent(publication.suggestedFilename)
                        if fileManager.fileExists(atPath: destinationFile.path) {
                            destinationFile = repository.appendingPathComponent("\(UUID().uuidString).\(destinationFile.pathExtension)")
                        }
                        try fileManager.moveItem(at: publication.localURL, to: destinationFile)
    
                        addPublication(url: destinationFile, downloadTask: publication.downloadTask)
                    } catch {
                        self.showInfoAlert(title: "Error", message: error.localizedDescription)
                    }
                    
                case .failure(let error):
                    self.showInfoAlert(title: "Error", message: error.localizedDescription)
                case .cancelled:
                    break
                }
            }
            return true
            
        } else {
            return addPublication(url: url, downloadTask: downloadTask)
        }
    }

    /// Complementary parsing of the publication.
    /// Will parse Nav/ncx + mo (files that are possibly encrypted)
    /// using the DRM object of the publication.container.
    ///
    /// - Parameters:
    ///   - id: <#id description#>
    ///   - completion: <#completion description#>
    /// - Throws: <#throws value description#>
    func loadDRM(for publication: Publication, completion: @escaping (CancellableResult<DRM?>) -> Void) {
        guard let id = publication.metadata.identifier, let (container, parsingCallback) = items[id] else {
            completion(.success(nil))
            return
        }
        
        guard let drm = container.drm else {
            // No DRM, so the parsing callback can be directly called.
            do {
                try parsingCallback(nil)
                completion(.success(nil))
            } catch {
                completion(.failure(error))
            }
            return
        }
        
        guard let drmService = drmLibraryServices.first(where: { $0.brand == drm.brand }),
            let url = URL(string: container.rootFile.rootPath)
            else {
                self.showInfoAlert(title: "Error", message: "DRM not supported \(drm.brand)")
                completion(.success(nil))
                return
        }
        
        drmService.loadPublication(at: url, drm: drm) { result in
            switch result {
            case .success(let drm):
                do {
                    /// Update container.drm to drm and parse the remaining elements.
                    try parsingCallback(drm)
                    completion(.success(drm))
                } catch {
                    completion(.failure(error))
                }
            default:
                completion(result)
            }
        }
    }
    
    fileprivate func lightParsePublications() {
        // Parse publication from documents folder.
        let locations = locationsFromDocumentsDirectory()
        
        // Load the publications.
        for location in locations {
            if !lightParsePublication(at: location) {
                print("Error loading publication \(location.relativePath).")
            }
        }
    }
    
    fileprivate func lightParseSamplePublications() {
        // Parse publication from documents folder.
        let locations = locationsFromSamples()
        
        // Load the publications.
        for location in locations {
            if !lightParsePublication(at: location) {
                print("Error loading publication \(location.relativePath).")
            }
        }
    }
    
    /// Load publication at `location` on the server.
    ///
    internal func lightParsePublication(at location: Location) -> Bool {
        let parsers: [PublicationType: PublicationParser.Type] = [
            .cbz: CbzParser.self,
            .epub: EpubParser.self,
            .pdf: PDFParser.self
        ]
        
        guard let parser = parsers[location.type] else {
            return false
        }

        do {
            let (pubBox, parsingCallback) = try parser.parse(fileAtPath: location.absolutePath)
            let (publication, container) = pubBox
            guard let id = publication.metadata.identifier else {
                return false
            }
            items[id] = (container, parsingCallback)
            /// Add the publication to the server.
            try publicationServer.add(publication, with: container)
            
        } catch {
            print("Error parsing publication at path '\(location.relativePath)': \(error)")
            return false
        }
        
        return true
    }
    
    /// Get the locations out of the application Documents directory.
    ///
    /// - Returns: The Locations array.
    fileprivate func locationsFromDocumentsDirectory() -> [Location] {
        let fileManager = FileManager.default
        // Document Directory always exists (hence try!).
        let documentsUrl = try! fileManager.url(for: .documentDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        
        var files: [String]
        
        // Get the array of files from the documents/inbox folder.
        do {
            files = try fileManager.contentsOfDirectory(atPath: documentsUrl.path)
        } catch {
            print("Error while reading content of directory.")
            return []
        }
        /// Find the types associated to the files, or unknown.
        let locations = files.map({ fileName -> Location in
            let fileUrl = documentsUrl.appendingPathComponent(fileName)
            let publicationType = PublicationType(url: fileUrl)
            
            return Location(absolutePath: fileUrl.path, relativePath: fileName, type: publicationType)
        })
        return locations
    }
    
    /// Get the locations out of the application Documents/inbox directory.
    ///
    /// - Returns: The Locations array.
    fileprivate func locationsFromSamples() -> [Location] {
        let samples = ["1", "2", "3", "4", "5", "6"]
        var sampleUrls = [URL]()
        
        for ext in ["epub", "cbz", "pdf"] {
            for sample in samples {
                if let path = Bundle.main.path(forResource: sample, ofType: ext) {
                    let url = URL.init(fileURLWithPath: path)
    
                    sampleUrls.append(url)
                    print(url.absoluteString)
                }
            }
        }

        /// Find the types associated to the files, or unknown.
        let locations = sampleUrls.map({ url -> Location in
            let publicationType = PublicationType(url: url)
            
            return Location(absolutePath: url.path, relativePath: "sample", type: publicationType)
        })
        return locations
    }
    
    func remove(_ publication: Publication) {
        // Find associated container.
        guard let pubBox = publicationServer.pubBoxes.values.first(where: {
            $0.publication.metadata.identifier == publication.metadata.identifier
        }) else {
            return
        }
        // Remove publication from Documents/Inbox folder.
        let path = pubBox.associatedContainer.rootFile.rootPath
        
        if let url = URL(string: path) {
            let filename = url.lastPathComponent
            removeFromDocumentsDirectory(fileName: filename)
        }
        // Remove publication from publicationServer.
        publicationServer.remove(publication)
    }
    
    fileprivate func removeFromDocumentsDirectory(fileName: String) {
        let fileManager = FileManager.default
        // Document Directory always exists (hence `try!`).
        let inboxDirUrl = try! fileManager.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        // Assemble destination path.
        let absoluteUrl = inboxDirUrl.appendingPathComponent(fileName)
        // Check that file don't exist.
        guard !fileManager.fileExists(atPath: absoluteUrl.path) else {
            do {
                try fileManager.removeItem(at: absoluteUrl)
            } catch {
                print("Error while deleting file in Documents.")
            }
            return
        }
    }

}
