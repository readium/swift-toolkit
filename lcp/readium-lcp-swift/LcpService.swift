//
//  Created by Mickaël Menu on 01.02.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import PromiseKit


public enum LcpPassphraseRequest {
    case passphrase(String)
    case cancelled
}

public enum LcpPassphraseRequestReason {
    case unknownPassphrase
    case changedPassphrase
    case invalidPassphrase
}

public protocol LcpServiceDelegate: AnyObject {
    
    func requestPassphrase(for license: LicenseDocument, reason: LcpPassphraseRequestReason, completion: @escaping (LcpPassphraseRequest) -> Void)
    
}

public class LcpService {
    
    public weak var delegate: LcpServiceDelegate?
    
    public struct ImportedPublication {
        public let localUrl: URL
        public let downloadTask: URLSessionDownloadTask?
    }

    public init() {}
        
    public func importLicenseDocument(_ lcpl: URL, completion: @escaping (ImportedPublication?, LcpError?) -> Void) {
        firstly { () -> Promise<(URL, URLSessionDownloadTask?)> in
            let session = try LcpSession(licenseDocument: lcpl, delegate: self)
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
            let session = try LcpSession(protectedEpubUrl: publication, delegate: self)
            try session.loadDrm(completion)
        } catch {
            completion(nil, LcpError.wrap(error))
        }
    }
    
    public func removePublication(at url: URL) -> Void {
        if let lcpLicense = try? LcpLicense(withLicenseDocumentIn: url) {
            try? lcpLicense.removeDataBaseItem()
        }
        // In case, the epub download succeed but the process inserting lcp into epub failed
        if url.lastPathComponent.starts(with: "lcp.") {
            let possibleLCPID = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lcp.", with: "")
            try? LcpLicense.removeDataBaseItem(licenseID: possibleLCPID)
        }
    }
    
}

extension LcpService: LcpSessionDelegate {

    public func requestPassphrase(for license: LicenseDocument, reason: LcpPassphraseRequestReason) -> Promise<LcpPassphraseRequest> {
        return Promise<LcpPassphraseRequest> { [weak self] fulfill, reject in
            guard let delegate = self?.delegate else {
                fulfill(.cancelled)
                return
            }
            
            delegate.requestPassphrase(for: license, reason: reason, completion: fulfill)
        }
    }
}
