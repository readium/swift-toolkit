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
import UIKit
import R2Shared
import R2Streamer
import Kingfisher


struct Location {
    let absolutePath: String
    let fileName: String
    let format: Publication.Format
}

protocol LibraryServiceDelegate: AnyObject {
    
    func reloadLibrary(with downloadTask: URLSessionDownloadTask?, canceled:Bool)
    func libraryService(_ libraryService: LibraryService, presentError error: Error)
    
}

final class LibraryService: Loggable {
    
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
        
        preloadSamples()
        
    }
    
    func preloadSamples() {
        let version = 1
        let VERSION_KEY = "LIBRARY_VERSION"
        let oldversion = UserDefaults.standard.integer(forKey: VERSION_KEY)
        if oldversion < version {
            UserDefaults.standard.set(version, forKey: VERSION_KEY)
            clearDocumentsDir()
            // Parse publications (just the OPF and Encryption for now)
            lightParseSamplePublications()
        }
    }
    
    func present(_ alert: UIAlertController) {
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
        url = repository.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
        
        /// Copy the Publication to documents.
        do {
            // Necessary to read URL exported from the Files app, for example.
            _ = sourceUrl.startAccessingSecurityScopedResource()
            defer {
                sourceUrl.stopAccessingSecurityScopedResource()
            }
            
            try FileManager.default.copyItem(at: sourceUrl, to: url)
            let dateAttribute = [FileAttributeKey.modificationDate: Date()]
            try FileManager.default.setAttributes(dateAttribute, ofItemAtPath: url.path)
            
        } catch {
            delegate?.libraryService(self, presentError: LibraryError.importFailed(error))
            return false
        }
        
        @discardableResult
        func addPublication(url: URL, downloadTask: URLSessionDownloadTask?) -> Bool {
            /// Add the publication to the publication server.
            let location = Location(
                absolutePath: url.path,
                fileName: url.lastPathComponent,
                format: Publication.Format(file: url)
            )
            guard let (publication, container) = lightParsePublication(for: location.absolutePath, isAbsolute: true) else {
                delegate?.libraryService(self, presentError: LibraryError.publicationIsNotValid)
                try? FileManager.default.removeItem(at: url)
                return false
            }
            
            var image:Data?
            if let cover = publication.coverLink{
                image = try? container.data(relativePath: cover.href)
            }
            
            let book = Book(fileName: location.fileName,
                            title: publication.metadata.title,
                            author: publication.metadata.authors
                                .map { $0.name }
                                .joined(separator: ", "),
                            identifier: publication.metadata.identifier!,
                            cover: image)
            if (try! BooksDatabase.shared.books.insert(book: book)) != nil {
                delegate?.reloadLibrary(with: downloadTask, canceled: false)
                return true
                
            } else {
                
                let duplicatePublicationAlert = UIAlertController(
                    title: NSLocalizedString("library_duplicate_alert_title", comment: "Title of the import confirmation alert when the publication already exists in the library"),
                    message: NSLocalizedString("library_duplicate_alert_message", comment: "Message of the import confirmation alert when the publication already exists in the library"),
                    preferredStyle: UIAlertController.Style.alert
                )
                let addAction = UIAlertAction(title: NSLocalizedString("add_button", comment: "Confirmation button to import a duplicated publication"), style: .default, handler: { alert in
                    if (try! BooksDatabase.shared.books.insert(book: book, allowDuplicate: true)) != nil {
                        self.delegate?.reloadLibrary(with: downloadTask, canceled: false)
                        return
                    }
                    else {
                        try? FileManager.default.removeItem(at: url)
                        self.delegate?.reloadLibrary(with: downloadTask, canceled: true)
                        return
                    }
                    
                })
                let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel the confirmation alert"), style: .cancel, handler: { alert in
                    try? FileManager.default.removeItem(at: url)
                    self.delegate?.reloadLibrary(with: downloadTask, canceled: true)
                    return
                })
                
                duplicatePublicationAlert.addAction(addAction)
                duplicatePublicationAlert.addAction(cancelAction)
                present(duplicatePublicationAlert)
                return true
            }
        }
        
        if let drmService = drmLibraryServices.first(where: { $0.canFulfill(url) }) {
            drmService.fulfill(url) { [weak self] result in
                guard let self = self else {
                    return
                }
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
                        self.delegate?.libraryService(self, presentError: error)
                    }
                    
                case .failure(let error):
                    self.delegate?.libraryService(self, presentError: error)
                case .cancelled:
                    break
                }
            }
            return false
            
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
    func loadDRM(for fileName: String, completion: @escaping (CancellableResult<DRM?>) -> Void) {
        
        guard let (container, parsingCallback) = items[fileName] else {
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
            let url = URL(string: container.rootFile.rootPath) else
        {
            delegate?.libraryService(self, presentError: LibraryError.drmNotSupported(drm.brand))
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
    
    fileprivate func lightParseSamplePublications() {
        // Parse publication from documents folder.
        let locations = locationsFromSamples()
        
        // Load the publications.
        for location in locations {
            guard let (publication, container) = lightParsePublication(for: location.absolutePath, isAbsolute: true) else {
                log(.error, "Error loading publication \(location.fileName).")
                continue
            }
            
            var image:Data?
            if let cover = publication.coverLink{
                image = try? container.data(relativePath: cover.href)
            }
            
            let book = Book(fileName: location.fileName,
                            title: publication.metadata.title,
                            author: publication.metadata.authors
                                .map { $0.name }
                                .joined(separator: ", "),
                            identifier: publication.metadata.identifier!,
                            cover: image)
            _ = try! BooksDatabase.shared.books.insert(book: book)
        }
    }
    
    internal func publish(publication: Publication, with container:Container, for path: String) {
        publicationServer.removeAll()
        do {
            try publicationServer.add(publication, with: container, at: path)
        } catch {
            log(.error, error)
        }
    }
    
    internal func lightParsePublication(for path: String, book:Book? = nil, isAbsolute: Bool = false ) -> PubBox? {
        let parsers: [Publication.Format: PublicationParser.Type] = [
            .cbz: CbzParser.self,
            .epub: EpubParser.self,
            .pdf: PDFParser.self
        ]
        
        var url:URL
        if !isAbsolute {
            var locationPath:String?
            let documents = try! FileManager.default.url(for: .documentDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: true)
            
            if (FileManager.default.fileExists(atPath: documents.appendingPathComponent(path).path)) {
                locationPath = documents.appendingPathComponent(path).path
            } else {
                if let absolutePath = Bundle.main.path(forResource: path, ofType: nil) {
                    if (FileManager.default.fileExists(atPath: absolutePath)) {
                        locationPath = absolutePath
                    }
                }
            }
            guard let absolutePath = locationPath else {
                return nil
            }
            url = URL.init(fileURLWithPath: absolutePath)
            
        } else {
            url = URL.init(fileURLWithPath: path)
        }
        
        let location = Location(absolutePath: url.path,
                                fileName: url.lastPathComponent,
                                format: Publication.Format(file: url))
        
        guard let parser = parsers[location.format] else {
            return nil
        }
        
        do {
            let (pubBox, parsingCallback) = try parser.parse(fileAtPath: location.absolutePath)
            let (_, container) = pubBox
            items[url.lastPathComponent] = (container, parsingCallback)
            return pubBox
        } catch {
            log(.error, "Error parsing publication at path '\(location.fileName)': \(error.localizedDescription)")
            return nil
        }
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
                }
            }
        }
        
        /// Find the types associated to the files, or unknown.
        return sampleUrls.map { url in
            return Location(
                absolutePath: url.path,
                fileName: url.lastPathComponent,
                format: Publication.Format(file: url)
            )
        }
    }
    
    func remove(_ book: Book) {
        // Remove item from Database.
        _ = try! BooksDatabase.shared.books.delete(book)
        
        // Remove file from documents directory
        removeFromDocumentsDirectory(fileName: book.fileName)
        
        // Remove publication from publicationServer.
        publicationServer.remove(at: book.fileName)
    }
    
    fileprivate func removeFromDocumentsDirectory(fileName: String) {
        let fileManager = FileManager.default
        // Document Directory always exists (hence `try!`).
        let documents = try! fileManager.url(for: .documentDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)
        // Assemble destination path.
        let absoluteUrl = documents.appendingPathComponent(fileName)
        // Check that file don't exist.
        guard !fileManager.fileExists(atPath: absoluteUrl.path) else {
            do {
                try fileManager.removeItem(at: absoluteUrl)
            } catch {
                log(.error, "Error while deleting file in Documents.")
            }
            return
        }
    }
    
    func clearDocumentsDir() {
        let fileManager = FileManager.default
        let documents = try! fileManager.url(for: .documentDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)
        guard let filePaths = try? fileManager.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil, options: []) else { return }
        for filePath in filePaths {
            try? fileManager.removeItem(at: filePath)
        }
    }
    
}

