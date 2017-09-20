//
//  AppDelegate.swift
//  r2-navigator-launcher
//
//  Created by Alexandre Camilleri on 6/12/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//

import UIKit
import R2Shared
import R2Streamer
import ReadiumLCP

struct Location {
    let absolutePath: String
    let relativePath: String
    let type: PublicationType
}

public enum PublicationType: String {
    case epub = "epub"
    case cbz = "cbz"
    case unknown = "unknown"
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    weak var libraryViewController: LibraryViewController!

    var publicationServer: PublicationServer!
    var epubParser: EpubParser!
    var cbzParser: CbzParser!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        /// Init R2.
        // Set logging minimum level.
        R2StreamerEnableLog(withMinimumSeverityLevel: .debug)
        // Init R2 Publication server.
        guard let publicationServer = PublicationServer() else {
            print("Error while instanciating R2 Publication Server.")
            return false
        }
        self.publicationServer = publicationServer
        // Init parsers.
        epubParser = EpubParser()
        cbzParser = CbzParser()

        loadPublications()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)

        guard let libraryVC = LibraryViewController(publicationServer.publications) else {
            print("Error instanciating the LibraryVC.")
            return false
        }
        libraryVC.delegate = self
        libraryViewController = libraryVC
        let navigationController = UINavigationController(rootViewController: libraryViewController)

        window!.rootViewController = navigationController
        window?.makeKeyAndVisible()

        navigationController.navigationBar.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        navigationController.navigationBar.barTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        return true
    }

    /// Called when the user open a file outside of the application and open it
    /// with the application.
    func application(_ application: UIApplication, open url: URL,
                     sourceApplication: String?, annotation: Any) -> Bool
    {
        guard url.isFileURL else {
            showInfoAlert(title: "Error", message: "The document isn't valid.")
            return false
        }
        switch url.pathExtension {
        case "lcpl":
            let lcpUtils = LcpUtils()

            // Retrieve publication using the LCPL.
            lcpUtils.publication(forLicenseAt: url, completion: { publicationUrl, error in
                guard let path = publicationUrl?.path else {
                    return
                }
                /// parse publication (TOMOVE)
                /// (should be light parsing and lib upgrade instead)
                do {
                    let pubBox = try self.epubParser.parse(fileAtPath: path)

                    try self.publicationServer.add(pubBox.publication, with: pubBox.associatedContainer)

                    self.showInfoAlert(title: "Success", message: "LCP Publication added to library.")
                } catch {
                    self.showInfoAlert(title: "Error", message: error.localizedDescription)
                    return
                }
            })
        default:
            /// Add the publication to the publication server.
            let location = Location(absolutePath: url.path,
                                    relativePath: url.lastPathComponent,
                                    type: getTypeForPublicationAt(url: url))
            if !loadPublication(at: location) {
                showInfoAlert(title: "Error", message: "The publication isn't valid.")
                return false
            } else {
                showInfoAlert(title: "Success", message: "Publication added to library.")
            }
        }
        return true
    }

    fileprivate func showInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "OK", style: .cancel)

        alert.addAction(dismissButton)
        // Update library publications.
        libraryViewController?.publications = publicationServer.publications
        // Redraw cells
        libraryViewController?.collectionView?.reloadData()
        libraryViewController?.collectionView?.backgroundView = nil
        // Present alert.
        window!.rootViewController!.present(alert, animated: true)
    }

}

extension AppDelegate {

    fileprivate func loadPublications() {
        // Parse publication from documents folder.
        let locations = locationsFromInboxDirectory()

        // Load the publications.
        for location in locations {
            if !loadPublication(at: location) {
                print("Error loading publication \(location.relativePath).")
            }
        }
    }

    /// Load publication at `location` on the server.
    ///
    /// - Parameter locations: The array of loations, containing the informations
    ///                        to add the publications to the server.
    internal func loadPublication(at location: Location) -> Bool {
        do {
            let parseResult: PubBox

            switch location.type {
            case .epub:
                parseResult = try epubParser.parse(fileAtPath: location.absolutePath)
            case .cbz:
                parseResult = try cbzParser.parse(fileAtPath: location.absolutePath)
            case .unknown:
                return false
            }
            print(parseResult.publication.manifestCanonical)
            /// Add.
            try publicationServer.add(parseResult.publication, with: parseResult.associatedContainer)
        } catch {
            print("Error parsing publication at path '\(location.relativePath)': \(error)")
            return false
        }
        return true
    }

    /// Get the locations out of the application Documents/inbox directory.
    ///
    /// - Returns: The Locations array.
    fileprivate func locationsFromInboxDirectory() -> [Location] {
        let fileManager = FileManager.default
        // Document Directory always exists (hence try!).
        var inboxUrl = try! fileManager.url(for: .documentDirectory,
                                             in: .userDomainMask,
                                             appropriateFor: nil,
                                             create: true)

        inboxUrl.appendPathComponent("Inbox/")

        var files: [String]

        print("\(inboxUrl.path)")
        // Get the array of files from the documents/inbox folder.
        do {
            files = try fileManager.contentsOfDirectory(atPath: inboxUrl.path)
        } catch {
            print("Error while reading content of directory.")
            return []
        }
        /// Find the types associated to the files, or unknown.
        let locations = files.map({ fileName -> Location in
            let fileUrl = inboxUrl.appendingPathComponent(fileName)
            let publicationType = getTypeForPublicationAt(url: fileUrl)

            return Location(absolutePath: fileUrl.path, relativePath: fileName, type: publicationType)
        })
        return locations
    }

    fileprivate func removeFromInboxDirectory(fileName: String) {
        let fileManager = FileManager.default
        // Document Directory always exists (hence `try!`).
        var inboxDirUrl = try! fileManager.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        inboxDirUrl.appendPathComponent("Inbox/")
        // Assemble destination path.
        let absoluteUrl = inboxDirUrl.appendingPathComponent(fileName)
        // Check that file don't exist.
        guard !fileManager.fileExists(atPath: absoluteUrl.path) else {
            do {
                try fileManager.removeItem(at: absoluteUrl)
            } catch {
                print("Error while deleting file in Documents/Inbox")
            }
            return
        }
    }

    /// Try to guess the type (epub/cbz for now) of the publication at url.
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
            
            removeFromInboxDirectory(fileName: filename)
        }
        // Remove publication from publicationServer.
        publicationServer.remove(publication)
        libraryViewController?.publications = publicationServer.publications
    }

}

