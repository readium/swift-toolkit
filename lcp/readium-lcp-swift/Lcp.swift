//
//  Lcp.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import UIKit
import PromiseKit
import SwiftyJSON
import ZIPFoundation

public class Lcp {
    public var licensePath: URL
    var license: LicenseDocument
    var status: StatusDocument?
    
    public init(withLicenseDocumentAt path: URL) throws {
        licensePath = path
        
        guard let data = try? Data.init(contentsOf: path.absoluteURL) else {
            throw LcpError.invalidPath
        }
        guard let license = try? LicenseDocument.init(with: data) else {
            throw LcpError.invalidLcpl
        }
        self.license = license
    }

    public init(withLicenseDocumentIn archive: URL) throws {
        guard let url = URL.init(string: "META-INF/license.lcpl") else {
            throw LcpError.invalidPath
        }
        licensePath = url
        let data = try Lcp.getData(forFile: licensePath, fromArchive: archive)

        guard let license = try? LicenseDocument.init(with: data) else {
            throw LcpError.invalidLcpl
        }
        self.license = license
    }
    
    /// Update the Status Document.
    ///
    /// - Parameter completion:
    public func fetchStatusDocument() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            guard let statusLink = license.link(withRel: LicenseDocument.Rel.status) else {
                reject(LcpError.statusLinkNotFound)
                return
            }
            let task = URLSession.shared.dataTask(with: statusLink.href) { (data, response, error) in
                if let data = data {
                    do {
                        self.status = try StatusDocument.init(with: data)
                    } catch {
                        reject(error)
                    }
                    fulfill()
                } else if let error = error {
                    reject(error)
                } else {
                    reject(LcpError.unknown)
                }
            }
            task.resume()
        }
    }
    
    /// Check that current date is inside the [end - start] right's dates range.
    ///
    /// - Returns: True if valid.
    public func areRightsValid() -> Bool {
        let now = Date.init()
        
        if let start = license.rights.start,
            !(now > start) {
            return false
        }
        if let end = license.rights.end,
            !(now < end) {
            return false
        }
        return true
    }
    
    /// Attemps to register the device for the given license using the Status
    /// document's register Link.
    /// Check if the license has been registered in local DB, and if not
    /// register it then write a row in DB.
    /// Note: This function fail without blocking the flow of LCP process.
    /// If not registered this time, will be the next time.
    public func register() {
        let database = LCPDatabase.shared

        // Check that no existing license with license.id are in the base.
        guard let existingLicense = try? database.licenses.existingLicense(with: license.id),
            !existingLicense else
        {
            return
        }
        // Is the Status document fetched.
        guard let status = status else {
            print(LcpError.noStatusDocument.localizedDescription)
            return
        }
        // Get device ID and Name.
        guard let deviceId = getDeviceId() else {
            print(LcpError.deviceId)
            return
        }
        let deviceName = getDeviceName()
        // get registerUrl.
        guard var registerUrl = status.link(withRel: StatusDocument.Rel.register)?.href else {
            print(LcpError.registerLinkNotFound.localizedDescription)
            return
        }
        // Removing the template {?id,name}
        registerUrl.deleteLastPathComponent()
        registerUrl.appendPathComponent("register")

        var request = URLRequest(url: registerUrl)
        request.httpMethod = "POST"
        request.httpBody = "id=\(deviceId)&name=\(deviceName)".data(using: .utf8)
        // Call registerUrl.
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse  {
                if httpResponse.statusCode == 400 {
                    print(LcpError.registrationFailure.localizedDescription)
                } else if httpResponse.statusCode == 200 {
                    //  5.3/ Store the fact the the device / license has been registered.
                    do {
                        try LCPDatabase.shared.licenses.insert(self.license, with: status.status)
                        return // SUCCESS
                    } catch {
                        print(error.localizedDescription)
                    }
                } else {
                    print(LcpError.unexpectedServerError)
                }
            } else if let error = error {
                print(error.localizedDescription)
            }
        })
        task.resume()
    }

    /// <#Description#>
    public func `return`() {
        // Is the Status document fetched.
        guard let status = status else {
            print(LcpError.noStatusDocument.localizedDescription)
            return
        }
        // Get device ID and Name.
        guard let deviceId = getDeviceId() else {
            print(LcpError.deviceId)
            return
        }
        let deviceName = getDeviceName()
        // get registerUrl.
        guard var returnUrl = status.link(withRel: StatusDocument.Rel.return)?.href else {
            print(LcpError.returnLinkNotFound.localizedDescription)
            return
        }
        // Removing the template return{?end,id,name}
        returnUrl.deleteLastPathComponent()
        returnUrl.appendPathComponent("return")

        var request = URLRequest(url: returnUrl)
        request.httpMethod = "PUT"
        request.httpBody = "id=\(deviceId)&name=\(deviceName)".data(using: .utf8)
        // Call returnUrl.
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse  {
                if error == nil {
                    switch httpResponse.statusCode {
                    case 200:
                        // update the status document
                        if let data = data {
                            do {
                                // Update local license in Lcp object
                                self.status = try StatusDocument.init(with: data)
                                guard let status = self.status?.status else {
                                    print("The status is not filled.")
                                    return
                                }
                                // Update license status (to 'returned' normally)
                                try LCPDatabase.shared.licenses.updateState(forLicenseWith: self.license.id,
                                                                            to: status.rawValue)
                            } catch {
                                print(LcpError.licenseDocumentData.localizedDescription)
                            }
                        }

                        // logging the event in db

                    case 400:
                        print(LcpError.returnFailure.localizedDescription)
                    case 403:
                        print(LcpError.alreadyReturned.localizedDescription)
                    default:
                        print(LcpError.unexpectedServerError.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
            }
        })
        task.resume()

    }


    /// <#Description#>
    public func renew() {
        // Is the Status document fetched.
        guard let status = status else {
            print(LcpError.noStatusDocument.localizedDescription)
            return
        }
        // Get device ID and Name.
        guard let deviceId = getDeviceId() else {
            print(LcpError.deviceId)
            return
        }
        let deviceName = getDeviceName()
        // get registerUrl.
        guard var renewUrl = status.link(withRel: StatusDocument.Rel.renew)?.href else {
            print(LcpError.renewLinkNotFound.localizedDescription)
            return
        }
        // Removing the template return{?end,id,name}
        renewUrl.deleteLastPathComponent()
        renewUrl.appendPathComponent("renew")

    }
    
    /// Return the name of the Device.
    ///
    /// - Returns: The device name.
    public func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    /// Returns the id of the device (Looking in the userSettings).
    /// If the device have not UUID yet in the userSettigns, generate one and
    /// save it.
    ///
    /// - Returns: The device unique ID.
    public func getDeviceId() -> String? {
        guard let deviceId = UserDefaults.standard.string(forKey: "lcp_device_id") else {
            let deviceId = UUID.init()
            
            UserDefaults.standard.set(deviceId.description, forKey: "lcp_device_id")
            return deviceId.description
        }
        return deviceId
    }
    
    public func getStatus() -> StatusDocument.Status? {
        return status?.status ?? nil
    }
    
    /// Download publication to inbox and return the path to the downloaded
    /// resource.
    ///
    /// - Returns: The URL representing the path of the publication localy.
    public func fetchPublication() -> Promise<URL> {
        return Promise<URL> { fulfill, reject in
            guard let publicationLink = license.link(withRel: LicenseDocument.Rel.publication) else {
                reject(LcpError.publicationLinkNotFound)
                return
            }
            let request = URLRequest(url: publicationLink.href)
            let title = publicationLink.title ?? "publication" //Todo
            let fileManager = FileManager.default
            // Document Directory always exists (hence try!).
            var destinationUrl = try! fileManager.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
            
            destinationUrl.appendPathComponent("\(title).epub")
            guard !FileManager.default.fileExists(atPath: destinationUrl.path) else {
                fulfill(destinationUrl)
                return
            }
            
            let task = URLSession.shared.downloadTask(with: request, completionHandler: { tmpLocalUrl, response, error in
                print(error?.localizedDescription)
                if let localUrl = tmpLocalUrl, error == nil {
                    do {
                        try FileManager.default.moveItem(at: localUrl, to: destinationUrl)
                    } catch {
                        print(error.localizedDescription)
                        reject(error)
                    }
                    fulfill(destinationUrl)
                } else if let error = error {
                    reject(error)
                } else {
                    reject(LcpError.unknown)
                }
            })
            task.resume()
        }
    }
    
    /// Update the License Document.
    ///
    /// - Parameter completion:
    public func updateLicenseDocument() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            guard let status = self.status else {
                reject(LcpError.noStatusDocument)
                return
            }
            guard let licenseLink = status.link(withRel: StatusDocument.Rel.license) else {
                reject(LcpError.licenseLinkNotFound)
                return
            }
            var request = URLRequest(url: licenseLink.href)

            print(request)
            
            /// 3.4.1/ Fetch the updated license.
            let task = URLSession.shared.downloadTask(with: request, completionHandler: { tmpLocalUrl, response, error in
                if let localUrl = tmpLocalUrl, error == nil {
                    let content: Data
                    
                    do {

                        let fileContent = try String(contentsOf: localUrl)

                        print(fileContent)
                        /// Refresh the current LicenseDocument in memory with the
                        /// freshly fetched one.
                        content = try Data.init(contentsOf: localUrl)
                        self.license = try LicenseDocument.init(with: content)
                        /// Replace the current licenseDocument on disk with the
                        /// new one.
                        try FileManager.default.removeItem(at: self.licensePath)
                        // SHOULD make a save or something // TODO
                        try FileManager.default.moveItem(at: localUrl,
                                                         to: self.licensePath)
                    } catch {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
                fulfill()
            })
            task.resume()
        }
    }

    /// Get the data of a file from an archive.
    ///
    /// - Parameters:
    ///   - file: Absolute path.
    ///   - url: Relative path.
    /// - Returns: If found, the Data object representing the file.
    /// - Throws: .
    static fileprivate func getData(forFile fileUrl: URL, fromArchive url: URL) throws -> Data {
        guard let archive = Archive(url: url, accessMode: .read) else  {
            throw LcpError.archive
        }
        guard let entry = archive[fileUrl.absoluteString] else {
            throw LcpError.fileNotInArchive
        }
        var destPath = url.deletingLastPathComponent()

        destPath.appendPathComponent("extracted_file.tmp")

        let destUrl = URL.init(fileURLWithPath: destPath.absoluteString)
        let data: Data

        // Extract file.
        _ = try archive.extract(entry, to: destUrl)
        data = try Data.init(contentsOf: destUrl)

        // Remove temporary file.
        try FileManager.default.removeItem(at: destUrl)

        return data
    }
    
    /// Moves the license.lcpl file from the "Documents/Inbox/" folder to the Zip archive
    /// META-INF folder.
    ///
    /// - Parameters:
    ///   - licenseUrl: The url of the license.lcpl file on the file system.
    ///   - publicationUrl: The url of the publication archive
    /// - Throws: ``.
    static public func moveLicense(from licenseUrl: URL, to publicationUrl: URL) throws {
        guard let archive = Archive(url: publicationUrl, accessMode: .update) else  {
            throw LcpError.archive
        }
        // Create local META-INF folder to respect the zip file hierachy.
        let fileManager = FileManager.default
        var urlMetaInf = publicationUrl.deletingLastPathComponent()
        
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
