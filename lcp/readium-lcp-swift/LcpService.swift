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

    private let passphrases: PassphrasesService
    
    /// To modify depending of the profile of the liblcp.a used
    private let supportedProfiles = [
        "http://readium.org/lcp/basic-profile",
        "http://readium.org/lcp/profile-1.0",
    ]

    public init() {
        self.passphrases = PassphrasesService(repository: LcpDatabase.shared.transactions)
        self.passphrases.delegate = self
    }
        
    public func importLicenseDocument(_ lcpl: URL, completion: @escaping (ImportedPublication?, LcpError?) -> Void) {
        firstly { () -> Promise<(URL, URLSessionDownloadTask?)> in
            let container = LcplLicenseContainer(lcpl: lcpl)
            let session = try LcpSession(container: container, passphrases: passphrases)
            return session.downloadPublication()
            
        }.then { (result) -> Void in
            let (localUrl, downloadTask) = result
            return completion(ImportedPublication(localUrl: localUrl, downloadTask: downloadTask), nil)
            
        }.catch { error in
            completion(nil, LcpError.wrap(error))
        }
    }
    
    public func openLicense(in publication: URL, completion: @escaping (LcpLicense?, LcpError?) -> Void) -> Void {
        do {
            let supportedProfiles = self.supportedProfiles
            let container = EpubLicenseContainer(epub: publication)
            let session = try LcpSession(container: container, passphrases: passphrases)
            try session.loadDrm { result in
                switch result {
                case .success(let license):
                    // Checks if the license's profile is supported
                    // FIXME: to move in the step "1/ validate the license structure"
                    guard supportedProfiles.contains(license.profile ?? "") else {
                        completion(nil, LcpError.profileNotSupported)
                        return
                    }
                    completion(license, nil)
                    
                case .failure(let error):
                    completion(nil, error)
                }
            }
        } catch {
            completion(nil, LcpError.wrap(error))
        }
    }
    
    public func removePublication(at url: URL) -> Void {
        let container = EpubLicenseContainer(epub: url)
        if let lcpLicense = try? LcpLicense(container: container) {
            try? lcpLicense.removeDataBaseItem()
        }
        // In case, the epub download succeed but the process inserting lcp into epub failed
        if url.lastPathComponent.starts(with: "lcp.") {
            let possibleLCPID = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lcp.", with: "")
            try? LcpLicense.removeDataBaseItem(licenseID: possibleLCPID)
        }
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
