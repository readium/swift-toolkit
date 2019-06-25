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
            loadSamplePublications()
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
    func movePublicationToLibrary(from sourceURL: URL, downloadTask: URLSessionDownloadTask? = nil) -> Bool {
        let repository = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let url = repository.appendingPathComponent("\(UUID().uuidString).\(sourceURL.pathExtension)")

        /// Copy the Publication to documents.
        do {
            // Necessary to read URL exported from the Files app, for example.
            _ = sourceURL.startAccessingSecurityScopedResource()
            defer {
                sourceURL.stopAccessingSecurityScopedResource()
            }
            
            try FileManager.default.copyItem(at: sourceURL, to: url)
            let dateAttribute = [FileAttributeKey.modificationDate: Date()]
            try FileManager.default.setAttributes(dateAttribute, ofItemAtPath: url.path)
            
        } catch {
            delegate?.libraryService(self, presentError: LibraryError.importFailed(error))
            return false
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
                        
                        self.addPublication(at: destinationFile, downloadTask: publication.downloadTask)
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
            return addPublication(at: url, downloadTask: downloadTask)
        }
    }
    
    @discardableResult
    func addPublication(at url: URL, downloadTask: URLSessionDownloadTask? = nil) -> Bool {
        guard let (publication, container) = parsePublication(at: url) else {
            delegate?.libraryService(self, presentError: LibraryError.publicationIsNotValid)
            try? FileManager.default.removeItem(at: url)
            return false
        }
        
        let image: Data? = publication.coverLink
            .flatMap { try? container.data(relativePath: $0.href) }
        
        let book = Book(
            href: url.isFileURL ? url.lastPathComponent : url.absoluteString,
            title: publication.metadata.title,
            author: publication.metadata.authors
                .map { $0.name }
                .joined(separator: ", "),
            identifier: publication.metadata.identifier!,
            cover: image
        )
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
    
    /// Complementary parsing of the publication.
    /// Will parse Nav/ncx + mo (files that are possibly encrypted)
    /// using the DRM object of the publication.container.
    func loadDRM(for book: Book, completion: @escaping (CancellableResult<DRM?>) -> Void) {
        
        guard let filename = book.fileName, let (container, parsingCallback) = items[filename] else {
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
    
    fileprivate func loadSamplePublications() {
        // Load the publications.
        for url in urlsFromSamples() {
            let filename = url.lastPathComponent
            guard let (publication, container) = parsePublication(at: url) else {
                log(.error, "Error loading publication \(filename).")
                continue
            }
            
            let image: Data? = publication.coverLink
                .flatMap { try? container.data(relativePath: $0.href) }
            
            let book = Book(
                href: filename,
                title: publication.metadata.title,
                author: publication.metadata.authors
                    .map { $0.name }
                    .joined(separator: ", "),
                identifier: publication.metadata.identifier!,
                cover: image
            )
            _ = try! BooksDatabase.shared.books.insert(book: book)
        }
    }
    
    func preparePresentation(of publication: Publication, book: Book, with container: Container) {
        // If the book is a webpub, it means it is loaded remotely from a URL, and it doesn't need to be added to the publication server.
        if publication.format != .webpub {
            publicationServer.removeAll()
            do {
                try publicationServer.add(publication, with: container, at: book.href)
            } catch {
                log(.error, error)
            }
        }
    }
    
    func parsePublication(for book: Book) -> PubBox? {
        if let filename = book.fileName {
            return parsePublication(atPath: filename)
        } else if let url = book.url {
            return parsePublication(at: url)
        } else {
            return nil
        }
    }
    
    func parsePublication(atPath path: String) -> PubBox? {
        let path: String = {
            // Relative to Documents/ or the App bundle?
            if !path.hasPrefix("/") {
                let documents = try! FileManager.default.url(
                    for: .documentDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
    
                let files = FileManager.default
                
                let documentPath = documents.appendingPathComponent(path).path
                if files.fileExists(atPath: documentPath) {
                    return documentPath
                }
                if let bundlePath = Bundle.main.path(forResource: path, ofType: nil),
                    files.fileExists(atPath: bundlePath)
                {
                    return bundlePath
                }
            }
            
            return path
        }()
        
        return parsePublication(at: URL(fileURLWithPath: path))
    }
    
    func parsePublication(at url: URL) -> PubBox? {
        do {
            guard let (pubBox, parsingCallback) = try Publication.parse(at: url) else {
                return nil
            }
            let (publication, container) = pubBox
            items[url.lastPathComponent] = (container, parsingCallback)
            return (publication, container)
            
        } catch {
            log(.error, "Error parsing publication at '\(url.absoluteString)': \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Get the paths out of the application Documents/inbox directory.
    fileprivate func urlsFromSamples() -> [URL] {
        return ["epub", "cbz", "pdf"].flatMap { ext in
            ["1", "2", "3", "4", "5", "6"].compactMap { name in
                Bundle.main.path(forResource: name, ofType: ext)
                    .map { URL(fileURLWithPath: $0) }
            }
        }
    }
    
    func remove(_ book: Book) {
        // Remove item from Database.
        _ = try! BooksDatabase.shared.books.delete(book)
        
        if let filename = book.fileName {
            // Removes file from documents directory.
            removeFromDocumentsDirectory(fileName: filename)
            // Removes publication from publicationServer.
            publicationServer.remove(at: filename)
        }
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

