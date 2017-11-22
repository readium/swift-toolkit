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
            firstly {
                // Retrieve publication using the LCPL.
                try publication(forLicenseAt: url)
                }.then { publicationUrl -> Void in
                    /// Parse publication. (tomove?)
                    if self.lightParsePublication(at: Location(absolutePath: publicationUrl.path,
                                                               relativePath: "",
                                                               type: .epub)) {
                        self.showInfoAlert(title: "Success", message: "LCP Publication added to library.")
                    } else {
                        self.showInfoAlert(title: "Error", message: "The LCP Publication couldn't be loaded.")
                    }
                }.catch { error in
                    self.showInfoAlert(title: "Error", message: error.localizedDescription)
            }
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
                print(error)
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
    
    /// Process a LCP License Document (LCPL).
    /// Fetching Status Document, updating License Document, Fetching Publication,
    /// and moving the (updated) License Document into the publication archive.
    ///
    /// - Parameters:
    ///   - path: The path of the License Document (LCPL).
    ///   - completion: The handler to be called on completion.
    internal func publication(forLicenseAt url: URL) throws -> Promise<URL> {
        let lcp = try Lcp.init(withLicenseDocumentAt: url)

        showInfoAlert(title: "Downloading", message: "The publication is being fetched in the background and will be available soon.")
        return firstly {
            /// 3.1/ Fetch the status document.
            /// 3.2/ Validate the status document.
            return lcp.fetchStatusDocument()
            }.then { _ -> Promise<Void> in
                /// 3.3/ Check that the status is "ready" or "active".
                guard lcp.getStatus() == StatusDocument.Status.ready
                    || lcp.getStatus() == StatusDocument.Status.active else {
                        /// If this is not the case (revoked, returned, cancelled,
                        /// expired), the app will notify the user and stop there.
                        throw LcpError.licenseStatus
                }
                /// 3.4/ Check if the license has been updated. If it is the case,
                //       the app must:
                /// 3.4.1/ Fetch the updated license.
                /// 3.4.2/ Validate the updated license. If the updated license
                ///        is not valid, the app must keep the current one.
                /// 3.4.3/ Replace the current license by the updated one in the
                ///        EPUB archive.
                return lcp.updateLicenseDocument()
            }.then { _ -> Promise<URL> in
                /// 4/ Check the rights.
                guard lcp.areRightsValid() else {
                    throw LcpError.invalidRights
                }
                /// 5/ Register the device / license if needed.
                lcp.register()
                /// 6/ Fetch the publication.
                return lcp.fetchPublication()
            }.then { publicationUrl -> Promise<URL> in
                /// Move the license document in the publication.
                try Lcp.moveLicense(from: lcp.licensePath, to: publicationUrl)
                return Promise(value: publicationUrl)
            }
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
    func loadPublication(withId id: String?, completion: @escaping () -> Void) throws {
        guard let id = id, let item = items[id] else {
            print("Error no id")
            return
        }
        let parsingCallback = item.1
        guard var drm = item.0.associatedContainer.drm else {
            // No DRM, so the parsing callback can be directly called.
            try parsingCallback(nil)
            completion()
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

            let session = try LcpSession.init(protectedEpubUrl: epubUrl)

            // get passphrase from DB, if not found prompt user, validate, go on
            firstly {
                // 1/ Validate the license structure
                try session.validateLicense()
                }.then { _ in
                    // 2/ Get the passphrase associated with the license
                    // 2.1/ Check if a passphrase hash has already been stored for the license.
                    // 2.2/ Check if one or more passphrase hash associated with
                    //      licenses from the same provider have been stored.
                    //      + calls the r2-lcp-client library  to validate it.
                    try session.passphraseFromDb()
                }.then { passphraseHash -> Promise<String> in

                    /// When passphrase is here should be commented.

                    switch passphraseHash {
                    // In case passphrase from db isn't found/valid.
                    case nil:
                        // 3/ Display the hint and ask the passphrase to the user.
                        //      + calls the r2-lcp-client library  to validate it.
                        let hint = session.getHint()

                        return firstly {
                            self.promptPassphrase(hint)
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
                    // Passphrase from db was already ok.
                    default:
                        return Promise(value: passphraseHash!)
                    }
                }.then { validPassphraseHash -> Promise<DeciphererLcp> in
                    firstly {
                        //                        // Get Certificat Revocation List. from "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl"
                        //                        return Promise<String> { fulfill, reject in
                        //                            guard let url = URL(string: "http://crl.edrlab.telesec.de/rl/EDRLab_CA.crl") else {
                        //                                reject(LcpError.crlFetching)
                        //                                return
                        //                            }
                        //                            var urlRequest = URLRequest.init(url: url)
                        //
                        //                            url
                        //                            URLSession.shared.dataTask(with: url, completionHandler: <#T##(Data?, URLResponse?, Error?) -> Void#>)
                        //                        }
                        return Promise(value: "-----BEGIN X509 CRL-----MIICrTCBljANBgkqhkiG9w0BAQQFADBnMQswCQYDVQQGEwJGUjEOMAwGA1UEBxMFUGFyaXMxDzANBgNVBAoTBkVEUkxhYjESMBAGA1UECxMJTENQIFRlc3RzMSMwIQYDVQQDExpFRFJMYWIgUmVhZGl1bSBMQ1AgdGVzdCBDQRcNMTcwOTI2MTM1NTE1WhcNMjcwOTI0MTM1NTE1WjANBgkqhkiG9w0BAQQFAAOCAgEA27f50xnlaKGUdqs6u6rDWsR75z+tZrH4J2aA5E9I/K5fNe20FftQZb6XNjVQTNvawoMW0q+Rh9dVjDnV5Cfwptchu738ZQr8iCOLQHvIM6wqQj7XwMqvyNaaeGMZxfRMGlx7T9DOwvtWFCc5X0ikYGPPV19CFf1cas8x9Y3LE8GmCtX9eUrotWLKRggG+qRTCri/SlaoicfzqhViiGeLdW8RpG/Q6ox+tLHti3fxOgZarMgMbRmUa6OTh8pnxrfnrdtD2PbwACvaEMCpNCZRaSTMRmIxw8UUbUA/JxDIwyISGn3ZRgbFAglYzaX80rSQZr6e0bFlzHl1xZtZ0RazGQWP9vvfH5ESp6FsD98g//VYigatoPz/EKU4cfP+1W/Zrr4jRSBFB37rxASXPBcxL8cerb9nnRbAEvIqxnR4e0ZkhMyqIrLUZ3Jva0fC30kdtp09/KJ22mXKBz85wUQa7ihiSz7pov0R9hpY93fvt++idHBECRNGOeBC4wRtGxpru8ZUa0/KFOD0HXHMQDwVcIa/72T0okStOqjIOcWflxl/eAvUXwtet9Ht3o9giSl6hAObAeleMJOB37Bq9ASfh4w7d5he8zqfsCGjaG1OVQNWVAGxQQViWVysfcJohny4PIVAc9KkjCFa/QrkNGjrkUiV/PFCwL66iiF666DrXLY=-----END X509 CRL-----")
                        }.then { pemCrl -> Promise<DeciphererLcp> in
                            // Get a decipherer object for the given passphrase,
                            // also checking that it's not revoqued using the crl.
                            return session.resolve(using: validPassphraseHash, pemCrl: pemCrl)
                    }
                }.then { decipherer -> Void in
                    drm.decipherer = decipherer
                    
                    drm.profile = session.getProfile()
                    
                    /// Parse the remaining stuff
                    try? parsingCallback(drm)
                    // Tell the caller than we done.
                    completion()
                }.catch { error in
                    print("Error: \(error)")
                    //throw LcpError.unknown
            }
        }
    }
    
    // Ask a passphrase to the user and verify it
    fileprivate func promptPassphrase(_ hint: String) -> Promise<String>
    {
        //return Promise(value: "motdepasse")
        return Promise<String> { fullfil, reject in
            let alert = UIAlertController(title: "LCP Passphrase",
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

//    func getDrm(for publication: Publication) -> Drm? {
//        // Find associated container.
//        guard let pubBox = publicationServer.pubBoxes.values.first(where: {
//            $0.publication.metadata.identifier == publication.metadata.identifier
//        }) else {
//            return nil
//        }
//        return pubBox.associatedContainer.drm
//    }
}

