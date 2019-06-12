//
//  Error.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 22.02.19.
//
//  Copyright 2019 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// This is to simplify the refactoring, but should be removed in the end once the error enums are properly created.
enum AppError: Error {
    case message(String)
    
    var localizedDescription: String {
        switch self {
        case .message(let message):
            return message
        }
    }
}
