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

public class Lcp {
    var licensePath: URL
    var license: LicenseDocument
    var status: StatusDocument?
    
    public init(withLicenseDocumentAt path: URL) throws {
        licensePath = path
        
        guard let data = try? Data.init(contentsOf: path.absoluteURL) else {
            throw LcpError.invalidPath
        }
        let json = JSON(data: data)
        guard let license = try? LicenseDocument.init(with: json) else {
            throw LcpError.invalidLcpl
        }
        self.license = license
    }
    
    /// Update the Status Document.
    ///
    /// - Parameter completion:
    internal func fetchStatusDocument() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            guard let statusLink = license.link(withRel: "status") else {
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
    internal func areRightsValid() -> Bool {
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
    ///
    /// - Throws: .
    internal func register() {
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
        guard var registerUrl = status.link(withRel: "register")?.href else {
            print(LcpError.registerLinkNotFound.localizedDescription)
            return
        }
        // Removing the templace {?id,name}
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
    
    /// Return the name of the Device.
    ///
    /// - Returns: The device name.
    internal func getDeviceName() -> String {
        return UIDevice.current.name
    }
    
    /// Returns the id of the device (Looking in the userSettings).
    /// If the device have not UUID yet in the userSettigns, generate one and
    /// save it.
    ///
    /// - Returns: The device unique ID.
    internal func getDeviceId() -> String? {
        guard let deviceId = UserDefaults.standard.string(forKey: "lcp_device_id") else {
            let deviceId = UUID.init()
            
            UserDefaults.standard.set(deviceId.description, forKey: "lcp_device_id")
            return deviceId.description
        }
        return deviceId
    }
    
    /// Download publication to inbox and return the path to the downloaded
    /// resource.
    ///
    /// - Returns: The URL representing the path of the publication localy.
    internal func fetchPublication() -> Promise<URL> {
        return Promise<URL> { fulfill, reject in
            guard let publicationLink = license.link(withRel: "publication") else {
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
            
            destinationUrl.appendPathComponent("Inbox/\(title).epub")
            guard !FileManager.default.fileExists(atPath: destinationUrl.path) else {
                fulfill(destinationUrl)
                return
            }
            
            let task = URLSession.shared.downloadTask(with: request, completionHandler: { tmpLocalUrl, response, error in
                if let localUrl = tmpLocalUrl, error == nil {
                    do {
                        try FileManager.default.copyItem(at: localUrl, to: destinationUrl)
                        try FileManager.default.removeItem(at: localUrl)
                    } catch {
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
    internal func updateLicenseDocument() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            guard let status = self.status else {
                reject(LcpError.noStatusDocument)
                return
            }
            guard let licenseLink = status.link(withRel: "license") else {
                reject(LcpError.licenseLinkNotFound)
                return
            }
            let request = URLRequest(url: licenseLink.href)
            
            /// 3.4.1/ Fetch the updated license.
            let task = URLSession.shared.downloadTask(with: request, completionHandler: { tmpLocalUrl, response, error in
                if let localUrl = tmpLocalUrl, error == nil {
                    let content: Data
                    
                    do {
                        /// Refresh the current LicenseDocument in memory with the
                        /// freshly fetched one.
                        content = try Data.init(contentsOf: localUrl)
                        self.license = try LicenseDocument.init(with: JSON(content))
                        /// Replace the current licenseDocument on disk with the
                        /// new one.
                        try FileManager.default.removeItem(at: self.licensePath)
                        // SHOULD make a save or something // TODO
                        try FileManager.default.moveItem(at: localUrl,
                                                         to: self.licensePath)
                    } catch {
                        reject(error)
                    }
                    fulfill()
                } else if let error = error {
                    reject(error)
                } else {
                    reject(LcpError.unknown)
                }
            })
            task.resume()
        }
    }
    
}
