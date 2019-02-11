//
//  AppDelegate.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 6/12/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Shared
import R2Streamer
import PromiseKit
import CryptoSwift

struct Location {
    let absolutePath: String
    let relativePath: String
    let type: PublicationType
}

public enum PublicationType: String {
    case epub = "epub"
    case cbz = "cbz"
    case unknown = "unknown"
    
    init(rawString: String?) {
        self = PublicationType(rawValue: rawString ?? "") ?? .unknown
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    weak var libraryViewController: LibraryViewController!
    var publicationServer: PublicationServer!
    
    var cbzParser: CbzParser!
    
    /// Publications waiting to be added to the PublicationServer (first opening).
    /// publication identifier : data
    var items = [String: (PubBox, PubParsingCallback)]()
    
    var drmLibraryServices = [DrmLibraryService]()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        #if LCP
        drmLibraryServices.append(LcpLibraryService())
        #endif
        
        /// Init R2.
        // Set logging minimum level.
        R2StreamerEnableLog(withMinimumSeverityLevel: .debug)
        // Init R2 Publication server.
        guard let publicationServer = PublicationServer() else {
            print("Error while instanciating R2 Publication Server.")
            return false
        }
        self.publicationServer = publicationServer
        // Init parser. // To be made static soon.
        cbzParser = CbzParser()
        
        // Parse publications (just the OPF and Encryption for now)
        lightParseSamplePublications()
        lightParsePublications()
        
        return true
    }
    
    /// Called when the user open a file outside of the application and open it
    /// with the application.
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        guard url.isFileURL else {
            showInfoAlert(title: "Error", message: "The document isn't valid.")
            return false
        }
        return addPublicationToLibrary(url: url, needUIUpdate: true)
    }
    
    func showInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "OK", style: .cancel)
        
        alert.addAction(dismissButton)
        alert.title = title
        alert.message = message
        
        guard let rootViewController = self.window?.rootViewController else {return}
        if let _  = rootViewController.presentedViewController {
            rootViewController.dismiss(animated: true) {
                rootViewController.present(alert, animated: true)
            }
        } else {
            rootViewController.present(alert, animated: true)
        }
    }

    func reload(downloadTask: URLSessionDownloadTask?) {
        // Update library publications.
        
        guard let theDownloadTask = downloadTask else {
            libraryViewController?.insertNewItemWithUpdatedDataSource()
            return
        }
        libraryViewController?.reloadWith(downloadTask: theDownloadTask)
    }
    
}

extension AppDelegate {
    
    internal func addPublicationToLibrary(url sourceUrl: URL, needUIUpdate:Bool) -> Bool {
        
        var url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        url.appendPathComponent(sourceUrl.lastPathComponent)
        
        if FileManager().fileExists(atPath: url.path) {
            showInfoAlert(title: "Error", message: "File already exist")
            return false
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
            let location = Location(absolutePath: url.path,
                                    relativePath: url.lastPathComponent,
                                    type: getTypeForPublicationAt(url: url))
            guard lightParsePublication(at: location) else {
                showInfoAlert(title: "Error", message: "The publication isn't valid.")
                try? FileManager.default.removeItem(at: url)
                return false
            }
            
            if needUIUpdate {
                reload(downloadTask: downloadTask)
            }
            return true
        }
        
        if let drmService = drmLibraryServices.first(where: { $0.canFulfill(url) }) {
            drmService.fulfill(url) { result in
                try? FileManager.default.removeItem(at: url)
                
                switch result {
                case .success((let publicationUrl, let downloadTask)):
                    addPublication(url: publicationUrl, downloadTask: downloadTask)
                case .failure(let error):
                    self.showInfoAlert(title: "Error", message: error?.localizedDescription ?? "Error fulfilling DRM \(drmService.brand.rawValue)")
                case .cancelled:
                    break
                }
            }
            return true
            
        } else {
            return addPublication(url: url, downloadTask: nil)
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
        let publication: Publication
        let container: Container
        
        do {
            switch location.type {
            case .epub:
                let parseResult = try EpubParser.parse(fileAtPath: location.absolutePath)
                publication = parseResult.0.publication
                container = parseResult.0.associatedContainer
                
                guard let id = publication.metadata.identifier else {
                    return false
                }
                items[id] = (parseResult.0, parseResult.1)
            case .cbz:
                print("disabled")
                let parseResult = try cbzParser.parse(fileAtPath: location.absolutePath)
                
                publication = parseResult.publication
                container = parseResult.associatedContainer
            case .unknown:
                return false
            }
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
            let publicationType = getTypeForPublicationAt(url: fileUrl)
            
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
        
        for sample in samples {
            if let path = Bundle.main.path(forResource: sample, ofType: "epub") {
                let url = URL.init(fileURLWithPath: path)
                
                sampleUrls.append(url)
                print(url.absoluteString)
            }
        }
      
        for sample in samples {
          if let path = Bundle.main.path(forResource: sample, ofType: "cbz") {
            let url = URL.init(fileURLWithPath: path)
            
            sampleUrls.append(url)
            print(url.absoluteString)
          }
        }

        /// Find the types associated to the files, or unknown.
        let locations = sampleUrls.map({ url -> Location in
            let publicationType = getTypeForPublicationAt(url: url)
            
            return Location(absolutePath: url.path, relativePath: "sample", type: publicationType)
        })
        return locations
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
    
    /// Find the type (epub/cbz for now) of the publication at url.
    ///
    /// - Parameter url: The location of the publication file.
    /// - Returns: The type associated to this publication.
    internal func getTypeForPublicationAt(url: URL) -> PublicationType {
        let fileName = url.lastPathComponent
        let fileType = fileName.contains(".") ? fileName.components(separatedBy: ".").last : ""
        var publicationType = PublicationType.unknown
        
        // If directory.
        if fileType!.isEmpty {
            let mimetypePath = url.appendingPathComponent("mimetype").path
            if let mimetype = try? String(contentsOfFile: mimetypePath, encoding: String.Encoding.utf8) {
                switch mimetype {
                case EpubConstant.mimetype:
                    publicationType = PublicationType.epub
                case EpubConstant.mimetypeOEBPS:
                    publicationType = PublicationType.epub
                case CbzConstant.mimetype:
                    publicationType = PublicationType.cbz
                default:
                    publicationType = PublicationType.unknown
                }
            }
        } else /* Determine type with file extension */ {
            publicationType = PublicationType(rawValue: fileType!) ?? PublicationType.unknown
        }
        return publicationType
    }
    
}

extension AppDelegate: LibraryViewControllerDelegate {
    
    
    /// Complementary parsing of the publication.
    /// Will parse Nav/ncx + mo (files that are possibly encrypted)
    /// using the DRM object of the publication.container.
    ///
    /// - Parameters:
    ///   - id: <#id description#>
    ///   - completion: <#completion description#>
    /// - Throws: <#throws value description#>
    func loadPublication(withId id: String?, completion: @escaping (Drm?, Error?) -> Void) throws {
        guard let id = id, let item = items[id] else {
            print("Error no id")
            return
        }
        let parsingCallback = item.1
        guard let drm = item.0.associatedContainer.drm else {
            // No DRM, so the parsing callback can be directly called.
            try parsingCallback(nil)
            completion(nil, nil)
            return
        }
        
        guard let drmService = drmLibraryServices.first(where: { $0.brand == drm.brand }),
            let url = URL(string: item.0.associatedContainer.rootFile.rootPath)
        else {
            self.showInfoAlert(title: "Error", message: "DRM not supported \(drm.brand)")
            completion(nil, nil)
            return
        }
        
        drmService.loadPublication(at: url, drm: drm) { result in
            switch result {
            case .success(let drm):
                /// Update container.drm to drm and parse the remaining elements.
                try? parsingCallback(drm)
                completion(drm, nil)
                
            case .failure(let error):
                if let error = error as? LocalizedError {
                    self.showInfoAlert(title: "Error", message: error.localizedDescription)
                }
                completion(nil, error)
                
            case .cancelled:
                completion(nil, NSError.cancelledError())
            }
        }
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
        libraryViewController?.publications = publicationServer.publications
    }
    
}
