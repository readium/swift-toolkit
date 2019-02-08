//
//  License.swift
//  readium-lcp-swift
//
//  Created by Mickaël Menu on 08.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import SwiftyJSON
import ZIPFoundation
import R2Shared
import R2LCPClient

final class License {
    
    enum State {
        case pendingValidation
        case validating(LicenseValidation)
        case valid(LicenseDocument, StatusDocument?, DRMContext)
        case invalid(LCPError)
    }

    private let container: LicenseContainer
    private let makeValidation: () -> LicenseValidation
    private let device: DeviceService
    private var state: State

    init(container: LicenseContainer, makeValidation: @escaping () -> LicenseValidation, device: DeviceService) {
        self.container = container
        self.makeValidation = makeValidation
        self.device = device
        self.state = .pendingValidation
    }
    
    /// Reads and validates the License Document in the container.
    func validate(_ completion: @escaping (Result<License>) -> Void) {
        guard let containerLicenseData = try? container.read() else {
            completion(.failure(.licenseNotInContainer)) // FIXME: wrong error?
            return
        }
        
        let validation = makeValidation()
        state = .validating(validation)
        
        validation.validateLicenseData(containerLicenseData) { result in
            result.map(
                success: { license, status, context in
                    self.state = .valid(license, status, context)
                    // Overwrites the License Document in the container if it was updated
                    if containerLicenseData != license.data {
                        try? self.container.write(license) // FIXME: should we report an error here?
                    }
                    completion(.success(self))
                },
                failure: { error in
                    self.state = .invalid(error)
                    completion(.failure(error))
                }
            )
        }
    }

    /// Download publication to inbox and return the path to the downloaded
    /// resource.
    ///
    /// - Returns: The URL representing the path of the publication localy.
    func fetchPublication(_ completion: @escaping (Result<(URL, URLSessionDownloadTask?)>) -> Void) {
        guard case .valid(let license, _, _) = state else {
            completion(.failure(.invalidLicense(nil)))
            return
        }
        
        guard let publicationLink = license.link(withRel: LicenseDocument.Rel.publication) else {
            completion(.failure(.publicationLinkNotFound))
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
                    let container = EPUBLicenseContainer(epub: localUrl)
                    try container.write(license)
                    
                    try FileManager.default.moveItem(at: localUrl, to: destinationUrl)
                } catch {
                    print(error.localizedDescription)
                    completion(.failure(LCPError.wrap(error)))
                    return false
                }
                completion(.success((destinationUrl, downloadTask)))
                return true
            } else if let error = error {
                completion(.failure(LCPError.wrap(error)))
            } else {
                completion(.failure(LCPError.unknown(nil)))
            }
            return false
        })
    }

}


/// Public API
extension License: LCPLicense {

    /// Decipher encrypted content.
    public func decipher(_ data: Data) throws -> Data? {
        guard case let .valid(_, _, context) = state else {
            throw LCPError.invalidContext
        }
        return decrypt(data: data, using: context)
    }

    /// Check that current date is inside the [end - start] right's dates range.
    // FIXME: Is it useful? it seems to be checked by the lcplib (LCPClientError.licenseOutOfDate)
    public func areRightsValid() throws {
        guard case .valid(let license, _, _) = state else {
            throw LCPError.invalidLicense(nil)
        }
        let now = Date.init()
        if let start = license.rights.start,
            !(now > start) {
            throw LCPError.invalidRights
        }
        if let end = license.rights.end,
            !(now < end) {
            throw LCPError.invalidRights
        }
    }

    public func register() {
        guard case let .valid(license, optionalStatus, _) = state, let status = optionalStatus else {
            return
        }
        
        device.registerLicense(license, using: status, completion: nil)
    }

    public func renew(endDate: Date?, completion: @escaping (Error?) -> Void) {
//        // Is the Status document fetched.
//        guard let status = status else {
//            completion(LCPError.noStatusDocument)
//            return
//        }
//        // Get device ID and Name.
//        guard let deviceId = getDeviceId() else {
//            completion(LCPError.deviceId)
//            return
//        }
//        let deviceName = getDeviceName()
//        // get registerUrl.
//        guard let url = status.link(withRel: StatusDocument.Rel.renew)?.href,
//            var renewUrl = URL(string: url.absoluteString.replacingOccurrences(of: "%7B?end,id,name%7D", with: "")) else
//        {
//            completion(LCPError.renewLinkNotFound)
//            return
//        }
//
//        renewUrl = URL(string: renewUrl.absoluteString + "?id=\(deviceId)&name=\(deviceName)")!
//        var request = URLRequest(url: renewUrl)
//        request.httpMethod = "PUT"
//
//        // Call returnUrl.
//        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
//            if let httpResponse = response as? HTTPURLResponse  {
//                if error == nil {
//                    switch httpResponse.statusCode {
//                    case 200:
//                        // update the status document
//                        if let data = data {
//                            do {
//                                // Update local license in LCP object
//                                self.status = try StatusDocument(data: data)
//                                // Update license status (to 'returned' normally)
//                                try Database.shared.licenses.updateState(forLicenseWith: self.license.id,
//                                                                            to: self.status!.status.rawValue)
//                                // Update license document.
//                                firstly {
//                                    self.updateLicenseDocument()
//                                    }.then {
//                                        completion(nil)
//                                    }.catch { error in
//                                        completion(error)
//                                }
//                            } catch {
//                                completion(LCPError.licenseDocumentData)
//                            }
//                        }
//                    case 400:
//                        completion(LCPError.renewFailure)
//                    case 403:
//                        completion(LCPError.renewPeriod)
//                    default:
//                        completion(LCPError.unexpectedServerError)
//                    }
//                } else if let error = error {
//                    completion(error)
//                }
//            }
//        })
//        task.resume()
    }

    public func `return`(completion: @escaping (Error?) -> Void){
        guard case let .valid(license, optionalStatus, _) = state, let status = optionalStatus else {
            completion(LCPError.noStatusDocument)
            return
        }
        
        guard let url = status.link(withRel: StatusDocument.Rel.return)?.href,
            var returnUrl = URL(string: url.absoluteString.replacingOccurrences(of: "%7B?id,name%7D", with: "")) else
        {
            completion(LCPError.returnLinkNotFound)
            return
        }
        //
        //        returnUrl = URL(string: returnUrl.absoluteString + "?id=\(device.id)&name=\(device.name)")!
        //        var request = URLRequest(url: returnUrl)
        //        request.httpMethod = "PUT"
        //        let task = URLSession.shared.dataTask(with: request, completionHandler: { (data, response, error) in
        //            guard let httpResponse = response as? HTTPURLResponse else {
        //                if let error = error {
        //                    completion(error)
        //                }
        //                return
        //            }
        //            if error == nil {
        //                switch httpResponse.statusCode {
        //                case 200:
        //                    // update the status document
        //                    if let data = data {
        //                        do {
        //                            // Update local license in LCP object
        //                            self.status = try StatusDocument(data: data)
        //                            // Update license status (to 'returned' normally)
        //                            try Database.shared.licenses.updateState(forLicenseWith: self.license.id,
        //                                                                        to: self.status!.status.rawValue)
        //                            completion(nil)
        //                        } catch {
        //                            completion(LCPError.licenseDocumentData)
        //                        }
        //                    }
        //                case 400:
        //                    completion(LCPError.returnFailure)
        //                case 403:
        //                    completion(LCPError.alreadyReturned)
        //                default:
        //                    completion(LCPError.unexpectedServerError)
        //                }
        //            }
        //        })
        //        task.resume()
    }

    public func currentStatus() -> String {
        guard case .valid(_, let optionalStatus, _) = state,
            let status = optionalStatus
            else {
                return ""
        }
        return status.status.rawValue
    }

    public func lastUpdate() -> Date {
        guard case let .valid(license, _, _) = state else {
            return Date()
        }
        return license.dateOfLastUpdate()
    }

    public func issued() -> Date {
        guard case let .valid(license, _, _) = state else {
            return Date()
        }
        return license.issued
    }

    public func provider() -> URL {
        guard case let .valid(license, _, _) = state else {
            return URL(string: "http://test.com")!
        }
        return license.provider
    }

    public func rightsEnd() -> Date? {
        guard case let .valid(license, _, _) = state else {
            return nil
        }
        return license.rights.end
    }

    public func potentialRightsEnd() -> Date? {
        guard case let .valid(license, _, _) = state else {
            return nil
        }
        return license.rights.potentialEnd
    }

    public func rightsStart() -> Date? {
        guard case let .valid(license, _, _) = state else {
            return nil
        }
        return license.rights.start
    }

    public func rightsPrints() -> Int? {
        guard case let .valid(license, _, _) = state else {
            return nil
        }
        return license.rights.print
    }

    public func rightsCopies() -> Int? {
        guard case let .valid(license, _, _) = state else {
            return nil
        }
        return license.rights.copy
    }

    public var profile: String {
        guard case let .valid(license, _, _) = state else {
            return ""
        }
        return license.encryption.profile.absoluteString
    }
    
}
