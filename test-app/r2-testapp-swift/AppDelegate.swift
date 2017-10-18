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

    /// TODO: make it static like the epub parser.
    var cbzParser: CbzParser!

    /// Publications waiting to be added to the PublicationServer (first opening).
    /// publication identifier : data
    var items = [String: (PubBox, PubParsingCallback)]()

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
        // Init parser. // To be made static soon.
        cbzParser = CbzParser()

        // Parse publications (just the OPF and Encryption for now)
        lightParseSamplePublications()
        lightParsePublications()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)

        let publications = items.flatMap() { $0.value.0.publication }
        guard let libraryVC = LibraryViewController(publications) else {
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
                if self.lightParsePublication(at: Location(absolutePath: path,
                                                           relativePath: "inbox",
                                                           type: .epub)) {
                    self.showInfoAlert(title: "Success", message: "LCP Publication added to library.")
                } else {
                    self.showInfoAlert(title: "Error", message: "The LCP Publication couldn't be loaded.")
                }
            })
        default:
            /// Add the publication to the publication server.
            let location = Location(absolutePath: url.path,
                                    relativePath: url.lastPathComponent,
                                    type: getTypeForPublicationAt(url: url))
            if !lightParsePublication(at: location) {
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

    fileprivate func lightParsePublications() {
        // Parse publication from documents folder.
        let locations = locationsFromInboxDirectory()

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
    /// - Parameter locations: The array of loations, containing the informations
    ///                        to add the publications to the server.
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
            }
        }

        /// Find the types associated to the files, or unknown.
        let locations = sampleUrls.map({ url -> Location in
            let publicationType = getTypeForPublicationAt(url: url)

            return Location(absolutePath: url.path, relativePath: "sample", type: publicationType)
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

    ///
    ///
    /// - Parameter id: <#id description#>
    /// - Throws: <#throws value description#>
    func loadPublication(withId id: String?) throws {
        guard let id = id, let item = items[id] else {
            print("Error no id")
            return
        }
        let parsingCallback = item.1
        guard let drm = item.0.protectedBy else {
            // No DRM, so the parsing callback can be directly called.
            try parsingCallback(nil)
            return
        }
        // Drm handling.
        switch drm.brand {
        case .lcp:
            let epubPath = item.0.associatedContainer.rootFile.rootPath
            guard let epubUrl = URL.init(string: epubPath) else {
                print("URL error")
                return
            }
            let lcpUtils = LcpUtils()

//            func completion(drm: Drm, error: Error?, hint: String?) {
//                guard error == nil else {
//                    if (error as? LcpError) == LcpError.passphraseNeeded,
//                        let hint = hint
//                    {
//                        // This time ask the passphrase to the user.
//                        promptPassphrase(hint, { passphrase in
//                            try lcpUtils.resolve(drm: drm,
//                                                 forLicenseOf: epubUrl,
//                                                 providedPassphrase: passphrase,
//                                                 completion: completion)
//                        })
//                    } else {
//                        print(error!.localizedDescription)
//                        return
//                    }
//                }
//                /// Parse the remaining stuff (could be made async),
//                /// but first need the drm from above to be completed.
//                try? parsingCallback(drm)
//            }
//
//            // First call we don't give passphrase (to check if any in the LCP base)
//            try lcpUtils.resolve(drm: drm,
//                             forLicenseOf: epubUrl,
//                             providedPassphrase: nil,
//                             completion: completion)
        }
    }

    fileprivate func promptPassphrase(_ hint: String, _ confirmHandler: @escaping (String?) -> Void)
    {
        let alert = UIAlertController(title: "LCP Passphrase",
                                      message: hint, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "Cancel", style: .cancel)
        let confirmButton = UIAlertAction(title: "Submit", style: .default) { (_) in
            let passphrase = alert.textFields?[0].text

            confirmHandler(passphrase)
        }
        //adding textfields to our dialog box
        alert.addTextField { (textField) in
            textField.placeholder = "Passphrase"
        }

        alert.addAction(dismissButton)
        alert.addAction(confirmButton)
        // Present alert.
        window!.rootViewController!.present(alert, animated: true)
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
            
            removeFromInboxDirectory(fileName: filename)
        }
        // Remove publication from publicationServer.
        publicationServer.remove(publication)
        libraryViewController?.publications = publicationServer.publications
    }
}

