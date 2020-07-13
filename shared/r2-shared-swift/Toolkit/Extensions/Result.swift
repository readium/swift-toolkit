//
//  Result.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 13/07/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension Result {
    
    func getOrNil() -> Success? {
        return try? get()
    }

}
