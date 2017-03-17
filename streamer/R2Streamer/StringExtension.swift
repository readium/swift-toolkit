//
//  StringExtension.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/27/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// Replace `s = (myString as NSString).appendingPathComponent(otherString)`
/// by      `s.appending(pathComponent: path)`
extension String {
    func appending(pathComponent: String) -> String {
        return (self as NSString).appendingPathComponent(pathComponent)
    }

    func deletingLastPathComponent() -> String {
        return (self as NSString).deletingLastPathComponent
    }

    func lastPathComponent() -> String {
        return (self as NSString).lastPathComponent
    }
}
