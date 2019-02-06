//
//  Lcp.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/14/17.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import PromiseKit
import SwiftyJSON
import ZIPFoundation
import R2Shared
import R2LCPClient

public class LcpLicense: DrmLicense {

    var license: LicenseDocument
    var status: StatusDocument?
    internal var context: DRMContext?
    private var container: LicenseContainer
    
    init(container: LicenseContainer) throws {
        self.container = container
        self.license = try container.read()
    }
    
    /// Decipher encrypted content.
    ///
    /// - Parameter data: <#data description#>
    /// - Returns: <#return value description#>
    /// - Throws: <#throws value description#>
    public func decipher(_ data: Data) throws -> Data? {
        guard let context = context else {
            throw LcpError.invalidContext
        }
        return decrypt(data: data, using: context)
    }

    /// Update the Status Document.
    /// - Parametet initialDownloadAttempt: if serverError then Reject with error for initial download attempt otherwise fulfill with error
    /// - Parameter completion:
    public func fetchStatusDocument(shouldRejectError: Bool) -> Promise<Error?> {
        return Promise<Error?> { fulfill, reject in
            guard let statusLink = license.link(withRel: LicenseDocument.Rel.status) else {
                reject(LcpError.statusLinkNotFound)
                return
            }
            let task = URLSession.shared.dataTask(with: statusLink.href) { (data, response, error) in
                
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    
                    let serverError:Error? = {
                        if statusCode == 404 {
                            let info = [NSLocalizedDescriptionKey : "The Readium LCP License Status Document does not exist."]
                            return NSError(domain: "org.readium", code: 404, userInfo: info)
                        } else if statusCode >= 500 {
                            let info = [NSLocalizedDescriptionKey : "The Readium LCP server is experiencing problems, the License Status Document is unreachable"]
                            return NSError(domain: "org.readium", code: statusCode, userInfo: info)
                        }
                        return nil
                    } ()
                    
                    if let theServerError = serverError {
                        if shouldRejectError {
                            reject(theServerError)
                        } else {
                            fulfill(theServerError)
                        }
                        return
                    }
                }
                
                if let data = data {
                    do {
                        self.status = try StatusDocument.init(with: data)
                    } catch {
                        reject(error)
                    }
                  fulfill(nil)
                } else if let error = error {
                    fulfill(error)
                } else {
                    reject(LcpError.unknown(nil))
                }
            }
            task.resume()
        }
    }
    
    /// Check that current date is inside the [end - start] right's dates range.
    ///
    /// - Returns: True if valid.
    public func areRightsValid() throws {
        let now = Date.init()
        
        if let start = license.rights.start,
            !(now > start) {
            throw LcpError.invalidRights
        }
        if let end = license.rights.end,
            !(now < end) {
            throw LcpError.invalidRights
        }
    }

    public func checkStatus() throws {
        guard let theStatus =  status?.status else {
            throw LcpError.missingLicenseStatus
        }
        
        let updatedDate = status?.updated?.status
        
        switch theStatus {
        case .returned:
            throw LcpError.licenseStatusReturned(updatedDate)
        case .expired:
            throw LcpError.licenseStatusExpired(updatedDate)
        case .revoked:
            let extraInfo: String? = {
                if let registerCount = self.status?.events.filter({ (event) -> Bool in
                    return event.type == "register"
                }).count {
                    return "The license was registered by \(registerCount) devices."
                }
                return nil
            } ()
            throw LcpError.licenseStatusRevoked(updatedDate, extraInfo)
        case .cancelled:
            throw LcpError.licenseStatusCancelled(updatedDate)
        default:
            return
        }
    }
    
    /// Attemps to register the device for the given license using the Status
    /// document's register Link.
    /// Check if the license has been registered in local DB, and if not
    /// register it then write a row in DB.
    /// Note: This function fail without blocking the flow of LCP process.
    /// If not registered this time, will be the next time.
    public func register() {
        let database = LcpDatabase.shared

        // Check that no existing license with license.id are in the base.
        guard let registered = try? database.licenses.checkRegister(with: license.id), !registered
        else {
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
        // Removing the template {?id,name}
        guard let url = status.link(withRel: StatusDocument.Rel.register)?.href,
            let registerUrl = URL(string: url.absoluteString.replacingOccurrences(of: "%7B?id,name%7D", with: "")) else
        {
            print(LcpError.registerLinkNotFound.localizedDescription)
            return
        }
        var request = URLRequest(url: registerUrl)
        request.httpMethod = "POST"
        request.httpBody = "id=\(deviceId)&name=\(deviceName)".data(using: .utf8)
        // Call registerUrl.
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            guard let httpResponse = response as? HTTPURLResponse else {
                if let error = error {
                    print(error.localizedDescription)
                }
                return
            }
            if httpResponse.statusCode == 400 {
                print(LcpError.registrationFailure.localizedDescription)
            } else if httpResponse.statusCode == 200 {
                //  5.3/ Store the fact the the device / license has been registered.
                do {
                    try LcpDatabase.shared.licenses.register(forLicenseWith: self.license.id)
                    return // SUCCESS
                } catch {
                    print(error.localizedDescription)
                }
            } else {
                print(LcpError.unexpectedServerError)
            }
        })
        task.resume()
    }

    /// <#Description#>
    public func `return`(completion: @escaping (Error?) -> Void){
        // Is the Status document fetched.
        guard let status = status else {
            completion(LcpError.noStatusDocument)
            return
        }
        // Get device ID and Name.
        guard let deviceId = getDeviceId() else {
            completion(LcpError.deviceId)
            return
        }
        let deviceName = getDeviceName()
        // get registerUrl.
        guard let url = status.link(withRel: StatusDocument.Rel.return)?.href,
            var returnUrl = URL(string: url.absoluteString.replacingOccurrences(of: "%7B?id,name%7D", with: "")) else
        {
            completion(LcpError.returnLinkNotFound)
            return
        }

        returnUrl = URL(string: returnUrl.absoluteString + "?id=\(deviceId)&name=\(deviceName)")!
        var request = URLRequest(url: returnUrl)
        request.httpMethod = "PUT"
        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
            guard let httpResponse = response as? HTTPURLResponse else {
                if let error = error {
                    completion(error)
                }
                return
            }
            if error == nil {
                switch httpResponse.statusCode {
                case 200:
                    // update the status document
                    if let data = data {
                        do {
                            // Update local license in Lcp object
                            self.status = try StatusDocument.init(with: data)
                            // Update license status (to 'returned' normally)
                            try LcpDatabase.shared.licenses.updateState(forLicenseWith: self.license.id,
                                                                        to: self.status!.status.rawValue)
                            completion(nil)
                        } catch {
                            completion(LcpError.licenseDocumentData)
                        }
                    }
                case 400:
                    completion(LcpError.returnFailure)
                case 403:
                    completion(LcpError.alreadyReturned)
                default:
                    completion(LcpError.unexpectedServerError)
                }
            }
        })
        task.resume()
    }

    /// <#Description#>
    public func renew(endDate: Date?, completion: @escaping (Error?) -> Void) {
        // Is the Status document fetched.
        guard let status = status else {
            completion(LcpError.noStatusDocument)
            return
        }
        // Get device ID and Name.
        guard let deviceId = getDeviceId() else {
            completion(LcpError.deviceId)
            return
        }
        let deviceName = getDeviceName()
        // get registerUrl.
        guard let url = status.link(withRel: StatusDocument.Rel.renew)?.href,
            var renewUrl = URL(string: url.absoluteString.replacingOccurrences(of: "%7B?end,id,name%7D", with: "")) else
        {
            completion(LcpError.renewLinkNotFound)
            return
        }

        renewUrl = URL(string: renewUrl.absoluteString + "?id=\(deviceId)&name=\(deviceName)")!
        var request = URLRequest(url: renewUrl)
        request.httpMethod = "PUT"

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
                                // Update license status (to 'returned' normally)
                                try LcpDatabase.shared.licenses.updateState(forLicenseWith: self.license.id,
                                                                            to: self.status!.status.rawValue)
                                // Update license document.
                                firstly {
                                    self.updateLicenseDocument()
                                    }.then {
                                        completion(nil)
                                    }.catch { error in
                                        completion(error)
                                }
                            } catch {
                                completion(LcpError.licenseDocumentData)
                            }
                        }
                    case 400:
                        completion(LcpError.renewFailure)
                    case 403:
                        completion(LcpError.renewPeriod)
                    default:
                        completion(LcpError.unexpectedServerError)
                    }
                } else if let error = error {
                    completion(error)
                }
            }
        })
        task.resume()
    }
    
    /// Return the name of the Device.
    ///
    /// - Returns: The device name.
    public func getDeviceName() -> String {
        return String(UIDevice.current.name.filter { !" \n\t\r".contains($0) })
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
    public func fetchPublication() -> Promise<(URL, URLSessionDownloadTask?)> {
        let license = self.license
        return Promise<(URL, URLSessionDownloadTask?)> { fulfill, reject in
            guard let publicationLink = license.link(withRel: LicenseDocument.Rel.publication) else {
                reject(LcpError.publicationLinkNotFound)
                return
            }
            let request = URLRequest(url: publicationLink.href)
            let fileManager = FileManager.default
            // Document Directory always exists (hence try!).
            var destinationUrl = try! fileManager.url(for: .documentDirectory,
                                                      in: .userDomainMask,
                                                      appropriateFor: nil,
                                                      create: true)
            let fileName = "lcp." + license.id
            destinationUrl.appendPathComponent("\(fileName).epub")
            
            let publicationTitle = publicationLink.title ?? "..."
            
            DownloadSession.shared.launch(request: request, description: publicationTitle, completionHandler: { (tmpLocalUrl, response, error, downloadTask) -> Bool? in
                if let localUrl = tmpLocalUrl, error == nil {
                    do {
                        // Saves the License Document into the downloaded publication
                        let container = EpubLicenseContainer(epub: localUrl)
                        try container.write(license)
                        
                        try FileManager.default.moveItem(at: localUrl, to: destinationUrl)
                    } catch {
                        print(error.localizedDescription)
                        reject(error)
                        return false
                    }
                    fulfill((destinationUrl, downloadTask))
                    return true
                } else if let error = error {
                    reject(error)
                } else {
                    reject(LcpError.unknown(nil))
                }
                return false
            })
        }
    }
    
    /// Try to save the license document without status document.
    /// There is also no update logic for the license, because the license url belongs to status.
    /// - Parameters:
    ///   - shouldRejectError: should the function reject anny error emitted .
    ///
    public func saveLicenseDocumentWithoutStatus(shouldRejectError: Bool) -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            do {
                let exist = try LcpDatabase.shared.licenses.existingLicense(with: self.license.id)
                if exist { // When the LCP license already exist
                    if shouldRejectError {
                        reject(LcpError.licenseAlreadyExist)
                    }
                } else {
                    try LcpDatabase.shared.licenses.insert(self.license, with: nil)
                }
                fulfill(())
            } catch {
                if shouldRejectError {
                    reject(error)
                } else {fulfill(())}
            }
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
            print(licenseLink.href.absoluteString)
            let request = URLRequest(url: licenseLink.href)

            // Compare last update date
            let latestUpdate = license.dateOfLastUpdate()

            if let lastUpdate = LcpDatabase.shared.licenses.dateOfLastUpdate(forLicenseWith: license.id),
                lastUpdate > latestUpdate {
                    fulfill(())
                return
            }
            
            /// 3.4.1/ Fetch the updated license.
            let task = URLSession.shared.downloadTask(with: request, completionHandler: { tmpLocalUrl, response, error in
                if let localUrl = tmpLocalUrl, error == nil {
                    let content: Data
                    
                    do {
                        /// Refresh the current LicenseDocument in memory with the
                        /// freshly fetched one.
                        content = try Data.init(contentsOf: localUrl)
                        self.license = try LicenseDocument.init(with: content)
                        try self.container.write(self.license)
                    } catch {
                        print(error.localizedDescription)
                    }
                } else if let error = error {
                    print(error.localizedDescription)
                }
                try? LcpDatabase.shared.licenses.insert(self.license, with: status.status)
              fulfill(())
            })
            task.resume()
        }
    }

    public func removeDataBaseItem() throws {
        try LcpDatabase.shared.licenses.deleteData(for: self.license.id)
    }
    
    public static func removeDataBaseItem(licenseID: String) throws {
        try LcpDatabase.shared.licenses.deleteData(for: licenseID)
    }
    
    public var profile: String? {
        return license.encryption.profile.absoluteString
    }

    public func currentStatus() -> String {
        return getStatus()?.rawValue ?? ""
    }

    public func lastUpdate() -> Date {
        return license.dateOfLastUpdate()
    }

    public func issued() -> Date {
        return license.issued
    }

    public func provider() -> URL {
        return license.provider
    }

    public func rightsEnd() -> Date? {
        return license.rights.end
    }

    public func rightsStart() -> Date? {
        return license.rights.start
    }

    public func rightsPrints() -> Int? {
        return license.rights.print
    }

    public func rightsCopies() -> Int? {
        return license.rights.copy
    }

    public func potentialRightsEnd() -> Date? {
        return license.rights.potentialEnd
    }
}
