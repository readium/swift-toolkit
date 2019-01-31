//
//  Created by Mickaël Menu on 31.01.19.
//  Copyright © 2019 Readium. All rights reserved.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

#if LCP

import Foundation
import UIKit
import ReadiumLCP
import R2LCPClient
import R2Shared
import PromiseKit

extension AppDelegate {
    
    func importLcpPublication(_ licenseDocumentUrl: URL) {
        // Retrieve publication using the LCPL.
        firstly { () -> Promise<(URL, URLSessionDownloadTask?)> in
            let session = try LcpSession(licenseDocument: licenseDocumentUrl, delegate: self)
            return session.downloadPublication()
            
            }.then { (publicationUrl, downloadTask)-> Void in
                
                /// Parse publication. (tomove?)
                if self.lightParsePublication(at: Location(absolutePath: publicationUrl.path,
                                                           relativePath: "",
                                                           type: .epub)) {
                    
                    self.reload(downloadTask: downloadTask)
                } else {
                    self.showInfoAlert(title: "Error", message: "The LCP Publication couldn't be loaded.")
                }
            }.catch { error in
                print("Error -- \(error.localizedDescription)")
                self.showInfoAlert(title: "Error", message: error.localizedDescription)
                if FileManager.default.fileExists(atPath: licenseDocumentUrl.path) {
                    try? FileManager.default.removeItem(at: licenseDocumentUrl)
                }
            }
    }
    
    func removeLcpPublication(at url: URL) {
        if let lcpLicense = try? LcpLicense(withLicenseDocumentIn: url) {
            try? lcpLicense.removeDataBaseItem()
        }
        // In case, the epub download succeed but the process inserting lcp into epub failed
        if url.lastPathComponent.starts(with: "lcp.") {
            let possibleLCPID = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "lcp.", with: "")
            try? LcpLicense.removeDataBaseItem(licenseID: possibleLCPID)
        }
    }
    
    func loadLcpProtectedPublication(atPath publicationPath: String, with drm: Drm, completion: @escaping (Drm?, Error?) -> Void) throws {
        guard let epubUrl = URL(string: publicationPath) else {
            print("URL error")
            return
        }
        
        let session = try LcpSession(protectedEpubUrl: epubUrl, delegate: self)
        try session.loadDrm(drm, completion)
    }

}

extension AppDelegate: LcpSessionDelegate {
    
    func requestPassphrase(for license: LicenseDocument, reason: String?) -> Promise<String> {
        return Promise<String> { fullfil, reject in
            let title = reason ?? "LCP Passphrase"
            let message = license.getHint()
            let alert = UIAlertController(title: title,
                                          message: message, preferredStyle: .alert)
            let dismissButton = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
                reject(NSError.cancelledError())
            }
            
            let confirmButton = UIAlertAction(title: "Submit", style: .default) { (_) in
                let passphrase = alert.textFields?[0].text
                fullfil(passphrase ?? "")
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
    
}

#endif
