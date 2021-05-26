//
//  Publication.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 26.06.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import CoreServices
import Foundation
import R2Shared

extension Publication {
    
    /// Finds all the downloadable links for this publication.
    var downloadLinks: [Link] {
        links.filter {
            return DocumentTypes.main.supportsMediaType($0.type)
                || DocumentTypes.main.supportsFileExtension($0.url(relativeTo: nil)?.pathExtension)
        }
    }

}
