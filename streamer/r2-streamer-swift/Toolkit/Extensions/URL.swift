//
//  URL.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension URL {

    /// Computes a publication title from the URL's filename.
    var title: String { title() }
    
    /// Computes a publication title from the URL's filename, capitalized with the given `locale`.
    func title(with locale: Locale? = nil) -> String {
        deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "_", with: " ")
            .capitalized(with: locale)
    }
        
}
