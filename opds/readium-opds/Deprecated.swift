//
//  Deprecated.swift
//  readium-opds
//
//  Created by Mickaël Menu on 20.02.19.
//
//  Copyright 2018 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared

public typealias Promise<T> = Void

extension OPDSParser {
    
    @available(*, unavailable, message: "Use `parseURL(url:completion:)` instead")
    public static func parseURL(url: URL) -> Promise<ParseData> {}

}

extension OPDS1Parser {
    
    @available(*, unavailable, message: "Use `parseURL(url:completion:)` instead")
    public static func parseURL(url: URL) -> Promise<ParseData> {}
    
    @available(*, unavailable, message: "Use `fetchOpenSearchTemplate(feed:completion:)` instead")
    public static func fetchOpenSearchTemplate(feed: Feed) -> Promise<String> {}
    
}

extension OPDS2Parser {
    
    @available(*, unavailable, message: "Use `parseURL(url:completion:)` instead")
    public static func parseURL(url: URL) -> Promise<ParseData> {}
    
}
