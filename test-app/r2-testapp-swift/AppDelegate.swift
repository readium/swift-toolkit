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
import PromiseKit
import CryptoSwift

#if LCP
import ReadiumLCP
import R2LCPClient
#endif

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

        let publications = items.flatMap() { $0.value.0.publication }.sorted { (pA, pB) -> Bool in
            pA.metadata.title < pB.metadata.title
        }
        
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
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        guard url.isFileURL else {
            showInfoAlert(title: "Error", message: "The document isn't valid.")
            return false
        }
        switch url.pathExtension {
        case "lcpl":
            #if LCP
            // Retrieve publication using the LCPL.
            firstly {
                try publication(at: url)
                }.then { publicationUrl -> Void in
                    /// Parse publication. (tomove?)
                    if self.lightParsePublication(at: Location(absolutePath: publicationUrl.path,
                                                               relativePath: "",
                                                               type: .epub)) {
                        self.showInfoAlert(title: "Success", message: "LCP Publication added to library.")
                        self.reload()
                    } else {
                        self.showInfoAlert(title: "Error", message: "The LCP Publication couldn't be loaded.")
                    }
                }.catch { error in
                    print("Error -- \(error.localizedDescription)")
                    self.showInfoAlert(title: "Error", message: error.localizedDescription)
            }
            #endif
        default:
            /// Move Publication to documents.
            var documentsUrl = try! FileManager.default.url(for: .documentDirectory,
                                                            in: .userDomainMask,
                                                            appropriateFor: nil,
                                                            create: true)
            documentsUrl.appendPathComponent(url.lastPathComponent)
            do {
                try FileManager.default.moveItem(at: url, to: documentsUrl)
            } catch {
                showInfoAlert(title: "Error", message: "Couldn't retrieve the protected epub from the server \(error)")
                return false
            }
            /// Add the publication to the publication server.
            let location = Location(absolutePath: documentsUrl.path,
                                    relativePath: documentsUrl.lastPathComponent,
                                    type: getTypeForPublicationAt(url: url))
            if !lightParsePublication(at: location) {
                showInfoAlert(title: "Error", message: "The publication isn't valid.")
                return false
            } else {
                showInfoAlert(title: "Success", message: "Publication added to library.")
                reload()
            }
        }
        return true
    }

    fileprivate func showInfoAlert(title: String, message: String) {
        let alert = UIAlertController(title: "", message: "", preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "OK", style: .cancel)

        alert.addAction(dismissButton)
        alert.title = title
        alert.message = message

        // Present alert.
//        if alert.isBeingPresented  {
//            alert.dismiss(animated: false, completion: {
//                self.window?.rootViewController?.present(self.alert, animated: false)
//            })
//        } else {
            window?.rootViewController?.dismiss(animated: false, completion: nil)
            window?.rootViewController?.present(alert, animated: true)
//        }
    }

    fileprivate func reload() {
        // Update library publications.
        libraryViewController?.publications = publicationServer.publications
        // Redraw cells
        libraryViewController?.collectionView?.reloadData()
        libraryViewController?.collectionView?.backgroundView = nil
    }

}

extension AppDelegate {

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

  #if LCP
    /// Process a LCP License Document (LCPL).
    /// Fetching Status Document, updating License Document, Fetching Publication,
    /// and moving the (updated) License Document into the publication archive.
    ///
    /// - Parameters:
    ///   - path: The path of the License Document (LCPL).
    ///   - completion: The handler to be called on completion.
    internal func publication(at url: URL) throws -> Promise<URL> {
        showInfoAlert(title: "Downloading", message: "The publication is being fetched in the background and will be available soon.")
        /// Here we use a lcpLicense, and that's avoidable.
        /// Normally the streamer scan for DRM
        let lcpLicense = try LcpLicense.init(withLicenseDocumentAt: url)

        return firstly {
            /// 3.1/ Fetch the status document.
            /// 3.2/ Validate the status document.
            return lcpLicense.fetchStatusDocument()
            }.then { _ -> Promise<Void> in
                /// 3.3/ Check that the status is "ready" or "active".
                try lcpLicense.checkStatus()
                /// 3.4/ Check if the license has been updated. If it is the case,
                //       the app must:
                /// 3.4.1/ Fetch the updated license.
                /// 3.4.2/ Validate the updated license. If the updated license
                ///        is not valid, the app must keep the current one.
                /// 3.4.3/ Replace the current license by the updated one in the
                ///        EPUB archive.
                return lcpLicense.updateLicenseDocument()
            }.then { _ -> Promise<URL> in
                /// 4/ Check the rights.
                try lcpLicense.areRightsValid()
                /// 5/ Register the device / license if needed.
                lcpLicense.register()
                /// 6/ Fetch the publication.
                return lcpLicense.fetchPublication()
            }.then { publicationUrl -> Promise<URL> in
                /// Move the license document in the publication.
                try LcpLicense.moveLicense(from: lcpLicense.archivePath,
                                           to: publicationUrl)
                return Promise(value: publicationUrl)
        }
    }
  #endif
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
    func loadPublication(withId id: String?, completion: @escaping (Drm?) -> Void) throws {
        guard let id = id, let item = items[id] else {
            print("Error no id")
            return
        }
        let parsingCallback = item.1
        guard let drm = item.0.associatedContainer.drm else {
            // No DRM, so the parsing callback can be directly called.
            try parsingCallback(nil)
            completion(nil)
            return
        }
        let publicationPath = item.0.associatedContainer.rootFile.rootPath
      #if LCP
        // Drm handling.
        switch drm.brand {
        case .lcp:
            try handleLcpPublication(atPath: publicationPath,
                                     with: drm,
                                     parsingCallback: parsingCallback,
                                     completion)
        }
      #endif
    }
  
  #if LCP
    /// Handle the processing of a publication protected with a LCP DRM.
    ///
    /// - Parameters:
    ///   - publicationPath: The path of the publication.
    ///   - drm: The drm object associated with the Publication.
    ///   - completion: The completion handler.
    /// - Throws: .
    func handleLcpPublication(atPath publicationPath: String, with drm: Drm,
                              parsingCallback: @escaping PubParsingCallback,
                              _ completion: @escaping (Drm?) -> Void) throws
    {
        guard let epubUrl = URL.init(string: publicationPath) else {
            print("URL error")
            return
        }

        let session = try LcpSession.init(protectedEpubUrl: epubUrl)

        // Fonction used in the async code below.
        func validatePassphrase(passphraseHash: String) -> Promise<LcpLicense> {
            return firstly {
                // Get Certificat Revocation List. from "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl"
                return Promise<String> { fulfill, reject in
                    guard let url = URL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl") else {
                        reject(LcpError.crlFetching)
                        return
                    }

                    let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
                        guard let httpResponse = response as? HTTPURLResponse else {
                            if let error = error { reject(error) }
                            return
                        }
                        if error == nil {
                            switch httpResponse.statusCode {
                            case 200:
                                // update the status document
                                if let data = data {
                                    let pem = "-----BEGIN X509 CRL-----\(data.base64EncodedString())-----END X509 CRL-----";

                                    fulfill(pem)
                                }
                            default:
                                reject(LcpError.crlFetching)
                            }
                        }
                    })
                    task.resume()
                }
                }.then { pemCrl -> Promise<LcpLicense> in
                    // Get a decipherer object for the given passphrase,
                    // also checking that it's not revoqued using the crl.
                    return session.resolve(using: passphraseHash, pemCrl: pemCrl)
            }
        }

        // Fonction used in the async code below.
        func promptPassphrase(reason:String? = nil) -> Promise<String> {
            let hint = session.getHint()

            return firstly {
                self.promptPassphrase(hint, reason: reason)
                }.then { clearPassphrase -> Promise<String?> in
                    let passphraseHash = clearPassphrase.sha256()

                    return session.checkPassphrases([passphraseHash])
                }.then { validPassphraseHash -> Promise<String> in
                    guard let validPassphraseHash = validPassphraseHash else {
                        throw LcpError.unknown
                    }
                    try session.storePassphrase(validPassphraseHash)
                    return Promise(value: validPassphraseHash)
            }
        }
        
        //https://stackoverflow.com/questions/30523285/how-do-i-create-an-inline-recursive-closure-in-swift
        // Quick fix for error catch, because it's using Promise and there are so many func(closure) with captured values, there will be alot trouble to make them as seprated funcions. That's a dirty fix, shoud be refactored later all together.
        var catchError:((Error) -> Void)!
        catchError = { error in
            
            guard let lcpClientError = error as? LCPClientError else {
                self.showInfoAlert(title: "Error", message: error.localizedDescription)
                completion(nil)
                return
            }
            
            let askPassphrase = { (reason: String) -> Void in
                firstly {
                    return promptPassphrase(reason: reason)
                    }.then { passphraseHash -> Promise<LcpLicense> in
                        return validatePassphrase(passphraseHash: passphraseHash)
                    }.then { lcpLicense -> Void in
                        
                        var drm = drm
                        drm.license = lcpLicense
                        drm.profile = session.getProfile()
                        /// Update container.drm to drm and parse the remaining elements.
                        try? parsingCallback(drm)
                        // Tell the caller than we done.
                        completion(drm)
                    }.catch(execute: catchError)
            }
            
            switch lcpClientError {
            case .userKeyCheckInvalid:
                askPassphrase("LCP Passphrase updated")
            case .noValidPassphraseFound:
                askPassphrase("Wrong LCP Passphrase")
            default:
                self.showInfoAlert(title: "Error", message: error.localizedDescription)
                completion(nil)
                return
            }
        }

        // get passphrase from DB, if not found prompt user, validate, go on
        firstly {
            // 1/ Validate the license structure (Nothing yet)
            try session.validateLicense()
            }.then { _ in
                // 2/ Get the passphrase associated with the license
                // 2.1/ Check if a passphrase hash has already been stored for the license.
                // 2.2/ Check if one or more passphrase hash associated with
                //      licenses from the same provider have been stored.
                //      + calls the r2-lcp-client library  to validate it.
                try session.passphraseFromDb()
            }.then { passphraseHash -> Promise<String> in
                switch passphraseHash {
                // In case passphrase from db isn't found/valid.
                case nil:
                    // 3/ Display the hint and ask the passphrase to the user.
                    //      + calls the r2-lcp-client library  to validate it.
                    return promptPassphrase()
                // Passphrase from db was already ok.
                default:
                    return Promise(value: passphraseHash!)
                }
            }.then { passphraseHash -> Promise<LcpLicense> in
                return validatePassphrase(passphraseHash: passphraseHash)
            }.then { lcpLicense -> Void in
                var drm = drm

                drm.license = lcpLicense
                drm.profile = session.getProfile()
                /// Update container.drm to drm and parse the remaining elements.
                try? parsingCallback(drm)
                // Tell the caller than we done.
                completion(drm)
            }.catch(execute: catchError)
    }
    
    // Ask a passphrase to the user and verify it
    fileprivate func promptPassphrase(_ hint: String, reason: String? = nil) -> Promise<String>
    {
        return Promise<String> { fullfil, reject in
            
            let title = reason ?? "LCP Passphrase"
            let alert = UIAlertController(title: title,
                                          message: hint, preferredStyle: .alert)
            let dismissButton = UIAlertAction(title: "Cancel", style: .cancel)
            let confirmButton = UIAlertAction(title: "Submit", style: .default) { (_) in
                let passphrase = alert.textFields?[0].text

                if let passphrase = passphrase {
                    fullfil(passphrase)
                } else {
                    reject(LcpError.emptyPassphrase)
                }
            }

            //adding textfields to our dialog box
            alert.addTextField { (textField) in
                textField.placeholder = "Passphrase"
                textField.isSecureTextEntry = true
            }

            alert.addAction(dismissButton)
            alert.addAction(confirmButton)
            // Present alert.
            window!.rootViewController!.present(alert, animated: true)
        }
    }
  #endif
  
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

    //        func getDrm(for publication: Publication) -> Drm? {
    //            // Find associated container.
    //            guard let pubBox = publicationServer.pubBoxes.values.first(where: {
    //                $0.publication.metadata.identifier == publication.metadata.identifier
    //            }) else {
    //                return nil
    //            }
    //            return pubBox.associatedContainer.drm
    //        }
}

