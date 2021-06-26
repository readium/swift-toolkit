//
//  URL.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 26/07/2020.
//
//  Copyright 2020 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit
import R2Shared

extension URL {
    
    func download(description: String? = nil) -> Deferred<URL, Error> {
        assert(scheme != nil && !isFileURL, "Only a remote URL can be downloaded")
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        return deferred { success, failure, cancel in
            DownloadSession.shared.launch(
                request: URLRequest(url: self),
                description: description
            ) { downloadURL, response, error, downloadTask in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                
                if let downloadURL = downloadURL {
                    // The downloaded file will be automatically deleted at the end of this
                    // completion block, so we need to copy it to a temporary location.
                    let files = FileManager.default
                    let destinationURL = files.temporaryDirectory.appendingUniquePathComponent(response?.suggestedFilename ?? downloadURL.lastPathComponent)
                    do {
                        try files.moveItem(at: downloadURL, to: destinationURL)
                        success(destinationURL)
                    } catch {
                        failure(error)
                    }
                    
                } else if let error = error {
                    failure(error)
                } else {
                    cancel()
                }
                
                return true
            }
        }
        
    }
    
    /// Returns whether this URL locates a file that is under the app's home directory.
    var isAppFile: Bool {
        let homeDirectory = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return homeDirectory.isParentOf(self)
    }

}
