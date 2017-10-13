//
//  LcpUtils.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import PromiseKit
import ZIPFoundation
import R2Shared

public typealias PassphrasePrompter = (_ hint: String,
    _ comfirmHandler: @escaping (String?) -> Void) -> Void

public class LcpUtils {
    public init () {}

    /// This function aim at returning 
    ///
    /// - Parameters:
    ///   - drm: The partialy completed DRM.
    ///   - passphrasePrompter: The callback to prompt the user for it's passphrase.
    ///   - then: The code to be exected on success.
    /// - Returns: The filled DRM.
    public func resolve(drm: Drm,
                        forLicenseAt url: URL,
                        passphrasePrompter: @escaping PassphrasePrompter,
                        completion: @escaping (Drm?, Error?) -> Void)
    {
        let lcp: Lcp

        do {
            lcp = try Lcp.init(withLicenseDocumentAt: url)
        } catch {
            completion(nil, error)
            return
        }

        completion(nil, nil) // TMP

        // 1/ Validate the license structure
        // --- Cyril block.

        // 2/ Get the passphrase associated with the license
        let db = LCPDatabase.shared


        /// 2.1/ Check if a passphrase hash has already been stored for the license.
        // - let passphrase = try? db.transactions.passphrase(forLicense: lcp.license.id)
        // - lcp.license.encryption.userKey.keyCheck
        // - call cyrille lib, returns passphrase is success, error else.
        //----  if error  then ->
        /// 2.2/ Check if one or more passphrase hash associated with licenses
        ///      from the same provider have been stored.
        // - let passphrases = try? db.transactions.passphrases(forProvider: lcp.license.provider)
        // - lcp.license.encryption.userKey.keyCheck
        // - cal cyrille lib, returns passphrase if success, error else.

        /// 2.3/ Display the hint and ask the passphrase to the user.
        //        let hint = lcp.license.getHint()
        //        return Promise<String> { fulfill, reject in
        //            passphrasePrompter(hint, { passphrase in
        //                guard let passphrase = passphrase else {
        //                    reject(LcpError.emptyPassphrase)
        //                    return
        //                }
        //                fulfill(passphrase)
        //            })
        //        }

//        firstly {
//
//
//            }.then { passphrase in
//
//            }.then { passphrase -> Promise<Void> in
//                return
//        }

        /// 2.4/ Store the passphrase hash + license id tuple securely.
        // 3/ Validate the license integrity
        /// 3.1/ r2-lcp-client library (C++) with the passphrase hash, the license and CRL as parameters.
        // 4/ Check the license status

    }

    /// Process a LCP License Document (LCPL).
    /// Fetching Status Document, updating License Document, Fetching Publication,
    /// and moving the (updated) License Document into the publication archive.
    ///
    /// - Parameters:
    ///   - path: The path of the License Document (LCPL).
    ///   - completion: The handler to be called on completion.
    public func publication(forLicenseAt url: URL, completion: @escaping (URL?, Error?) -> Void) {
        let lcp: Lcp

        do {
            lcp = try Lcp.init(withLicenseDocumentAt: url)
        } catch {
            completion(nil, error)
            return
        }

        // BLOCK CYRILLE ---

        firstly {
            /// 3.1/ Fetch the status document.
            /// 3.2/ Validate the status document.
            return lcp.fetchStatusDocument()
            }.then { _ -> Promise<Void> in
                /// 3.3/ Check that the status is "ready" or "active".
                guard lcp.status?.status == StatusDocument.Status.ready
                    || lcp.status?.status == StatusDocument.Status.active else {
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
            }.then { publicationUrl -> Void in
                /// Move the license document in the publication.
                try self.moveLicense(from: lcp.licensePath, to: publicationUrl)
                completion(publicationUrl, nil)
            }.catch { error in
                completion(nil, error)
        }
    }

    /// Moves the license.lcpl file from the Documents/Inbox/ to the Zip archive
    /// META-INF folder.
    ///
    /// - Parameters:
    ///   - licenseUrl: The url of the license.lcpl file on the file system.
    ///   - publicationUrl: The url of the publication archive
    /// - Throws: ``.
    internal func moveLicense(from licenseUrl: URL, to publicationUrl: URL) throws {
        guard let archive = Archive(url: publicationUrl, accessMode: .update) else  {
            return
        }
        // Create local META-INF folder to respect the zip file hierachy.
        let fileManager = FileManager.default
        var urlMetaInf = licenseUrl.deletingLastPathComponent()

        urlMetaInf.appendPathComponent("META-INF", isDirectory: true)
        try fileManager.createDirectory(at: urlMetaInf, withIntermediateDirectories: true, attributes: nil)

        // Move license in the META-INF local folder.
        try fileManager.moveItem(at: licenseUrl, to: urlMetaInf.appendingPathComponent("license.lcpl"))
        // Copy META-INF/license.lcpl to archive.
        try archive.addEntry(with: urlMetaInf.lastPathComponent.appending("/license.lcpl"),
                             relativeTo: urlMetaInf.deletingLastPathComponent())
        // Delete META-INF/license.lcpl from inbox.
        try fileManager.removeItem(at: urlMetaInf)

    }
}











