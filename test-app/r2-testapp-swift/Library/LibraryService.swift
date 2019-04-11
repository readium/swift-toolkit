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
import Kingfisher


struct Location {
    let absolutePath: String
    let relativePath: String
    let format: Publication.Format
}

protocol LibraryServiceDelegate: AnyObject {
    
    func reloadLibrary(with downloadTask: URLSessionDownloadTask?, canceled:Bool)
    
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
            url = repository.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
        
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
                format: Publication.Format(file: url)
            )
            guard let (publication, container) = lightParsePublication(for: location.absolutePath, isAbsolute: true) else {
                showInfoAlert(title: "Error", message: "The publication isn't valid.")
                try? FileManager.default.removeItem(at: url)
                return false
            }
          
            var image:Data?
            if let cover = publication.coverLink{
              image = try? container.data(relativePath: cover.href)
            }

            let book = Book(fileName: location.relativePath,
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
              
              let duplicatePublicationAlert = UIAlertController(title: "The publication already exists",
                                                             message: "Would you like to add it anyways?",
                                                             preferredStyle: UIAlertController.Style.alert)
              let addAction = UIAlertAction(title: "Add", style: .default, handler: { alert in
                
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
              let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { alert in
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
    
    fileprivate func lightParseSamplePublications() {
        // Parse publication from documents folder.
        let locations = locationsFromSamples()
        
        // Load the publications.
        for location in locations {
            guard let (publication, container) = lightParsePublication(for: location.absolutePath, isAbsolute: true) else {
                print("Error loading publication \(location.relativePath).")
              continue
            }
          
          var image:Data?
          if let cover = publication.coverLink{
            image = try? container.data(relativePath: cover.href)
          }

          let book = Book(fileName: location.relativePath,
                          title: publication.metadata.title,
                          author: publication.metadata.authors
                            .map { $0.name }
                            .joined(separator: ", "),
                          identifier: publication.metadata.identifier!,
                          cover: image)
           _ = try! BooksDatabase.shared.books.insert(book: book)
      }
    }
  
    internal func serve(publication: Publication, with container:Container, for path: String) {
      publicationServer.remove(at: path)
      do {
          try publicationServer.add(publication, with: container, at: path)
        } catch {
          print("error on adding \(error)")
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
                          relativePath: url.lastPathComponent,
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
        print("Error parsing publication at path '\(location.relativePath)': \(error)")
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
                    print(url.absoluteString)
                }
            }
        }

        /// Find the types associated to the files, or unknown.
        return sampleUrls.map { url in
            return Location(
                absolutePath: url.path,
                relativePath: url.lastPathComponent,
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
                print("Error while deleting file in Documents.")
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
