//
//  LcpService.swift
//  r2-lcp-swift
//
//  Created by Mickaël Menu on 01.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import PromiseKit


public protocol LcpServiceDelegate: AnyObject {
    
    func requestPassphrase(for license: LicenseDocument, reason: PassphraseRequestReason, completion: @escaping (String?) -> Void)
    
}

public class LcpService {

    public struct ImportedPublication {
        public let localUrl: URL
        public let downloadTask: URLSessionDownloadTask?
    }
    
    public weak var delegate: LcpServiceDelegate?

    private let passphrases = PassphrasesService(repository: LcpDatabase.shared.transactions)
    private let device = DeviceService(repository: LcpDatabase.shared.licenses)
    private let crl = CrlService()
    
    /// To modify depending of the profile of the liblcp.a used
    private let supportedProfiles = [
        "http://readium.org/lcp/basic-profile",
        "http://readium.org/lcp/profile-1.0",
    ]

    public init() {
        passphrases.delegate = self
    }

    public func importLicenseDocument(_ lcpl: URL, completion: @escaping (ImportedPublication?, LcpError?) -> Void) {
        let container = LcplLicenseContainer(lcpl: lcpl)
        openLicense(from: container)
            .map { license in
                license.fetchPublication()
            }
            .map { ImportedPublication(localUrl: $0.0, downloadTask: $0.1) }
            .resolve(completion)
    }
    
    public func openLicense(in publication: URL, completion: @escaping (LcpLicense?, LcpError?) -> Void) -> Void {
        let container = EpubLicenseContainer(epub: publication)
        openLicense(from: container)
            .resolve(completion)
    }
    
    public func removePublication(at url: URL) -> Void {
//        let container = EpubLicenseContainer(epub: url)
//        if let lcpLicense = try? LcpLicense(container: container) {
//            try? lcpLicense.removeDataBaseItem()
//        }
//        // In case, the epub download succeed but the process inserting lcp into epub failed
//        if url.lastPathComponent.starts(with: "lcp.") {
//            let possibleLCPID = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lcp.", with: "")
//            try? LcpLicense.removeDataBaseItem(licenseID: possibleLCPID)
//        }
    }
    
    private func openLicense(from container: LicenseContainer) -> AsyncResult<LcpLicense> {
        let supportedProfiles = self.supportedProfiles
        let passphrases = self.passphrases
        let device = self.device
        let crl = self.crl
        let makeValidation = { LicenseValidation(supportedProfiles: supportedProfiles, passphrases: passphrases, device: device, crl: crl) }
        let license = LcpLicense(container: container, makeValidation: makeValidation, device: device)
        return license.validate()
    }

}

extension LcpService: PassphrasesServiceDelegate {
    
    func requestPassphrase(for license: LicenseDocument, reason: PassphraseRequestReason, completion: @escaping (String?) -> Void) {
        guard let delegate = self.delegate else {
            completion(nil)
            return
        }
        
        delegate.requestPassphrase(for: license, reason: reason, completion: completion)
    }

}
