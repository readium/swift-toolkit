//
//  LcpLicenseFactory.swift
//  readium-lcp-swift
//
//  Created by Alexandre Camilleri on 9/12/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

public class LcpLicenseFactory {
    var license: LcpLicense

    /// Private initializer for the LicenseDocument.
    ///
    /// - Parameter url: The url of the licenseDocument.
    /// - Throws: `LcpError.file`.
    private init(uri: URL) throws {
        self.license = LcpLicense(uri: uri)
        guard let data = try? Data.init(contentsOf: uri, options: []),
            let licenseDocument = try? LicenseDocument.init(with: data) else {
                throw LcpError.file
        }
        self.license.licenseDocument = licenseDocument
    }

    /// Fetch the remove StatusDocument, and pass the result to the `completion`
    /// closure parameter.
    ///
    /// - Parameter completion: The handler of the result.
    /// - Throws: `LcpError.statusLink`.
    private func fetchStatusDocument(_ completion: @escaping (Error?) -> Void) {
        guard let statusLink = license.licenseDocument?.link(withRel: "status") else {
            completion(LcpError.statusLink)
            return
        }
        let statusDocumentUrl = statusLink.href
        let task = URLSession.shared.dataTask(with: statusDocumentUrl) { (data, response, error) in
            guard let data = data, error == nil else {
                return
            }
            do {
                self.license.statusDocument = try StatusDocument.init(with: data)
            } catch {
                completion(error)
            }
            completion(nil)
        }
        task.resume()
    }

    /// Initialize a LcpLicense object, if successfull will be returned to the
    /// handler parameter. Contain async code.
    ///
    /// - Parameters:
    ///   - license: The url of the license file.
    ///   - completion: The handler block handling the result.
    /// - Throws: `LcpError.statusLink`,
    ///           `LcpError.file`.
    public static func initialize(with license: URL, completion: @escaping (LcpLicense?, Error?) -> Void) {
        let factory: LcpLicenseFactory

        do {
            factory = try LcpLicenseFactory(uri: license)
        } catch {
            completion(nil, error)
            return
        }

        factory.fetchStatusDocument({ error in
            guard error != nil else {
                completion(nil, error)
                return
            }
            completion(factory.license, nil)
        })
    }
}
