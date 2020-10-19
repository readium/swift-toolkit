//
//  LCPLibraryService.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 01.02.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

#if LCP

import Foundation
import UIKit
import R2Shared
import ReadiumLCP


class LCPLibraryService: DRMLibraryService {

    private var lcpService = LCPService()
    private let authentication = LCPDialogAuthentication()
    
    var contentProtection: ContentProtection? {
        lcpService.contentProtection(with: authentication)
    }
    
    func canFulfill(_ file: URL) -> Bool {
        return file.pathExtension.lowercased() == "lcpl"
    }
    
    func fulfill(_ file: URL) -> Deferred<DRMFulfilledPublication, Error> {
        return deferred { completion in
            self.lcpService.acquirePublication(from: file)
                .onCompletion { result in
                    completion(result
                        .map {
                            DRMFulfilledPublication(
                                localURL: $0.localURL,
                                downloadTask: $0.downloadTask,
                                suggestedFilename: $0.suggestedFilename
                            )
                        }
                        .eraseToAnyError()
                    )
                }
        }
    }

}

#endif
