//
//  URITemplate.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 05/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

/// A lightweight implementation of URI Template (RFC 6570).
///
/// Only handles simple cases, fitting Readium's use cases.
/// See https://tools.ietf.org/html/rfc6570
public struct URITemplate: CustomStringConvertible {
    
    public let uri: String
    
    public init(_ uri: String) {
        self.uri = uri
    }
    
    /// List of URI template parameter keys.
    public var parameters: Set<String> {
        Set(
            NSRegularExpression(#"\{\??([^}]+)\}"#)
                .matches(in: uri)
                .flatMap { groups -> [String] in
                    guard groups.count == 2 else {
                        return []
                    }
                    return groups[1].split(separator: ",").compactMap(String.init)
            }
            .map { $0.trimmingCharacters(in: .whitespaces) }
        )
    }
    
    /// Expands the URI by replacing the template variables by the given parameters.
    ///
    /// Any extra parameter is appended as query parameters.
    /// See RFC 6570 on URI template: https://tools.ietf.org/html/rfc6570
    public func expand(with parameters: [String: String]) -> String {
        func expandSimpleString(_ string: String) -> String {
            string
                .split(separator: ",")
                .map { parameters[String($0)]?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "" }
                .joined(separator: ",")
        }
        
        func expandFormStyle(_ string: String) -> String {
            "?" + string
                .split(separator: ",")
                .map {
                    "\($0)=\(parameters[String($0)]?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }
                .joined(separator: "&")
        }
        
        return ReplacingRegularExpression(#"\{(\??)([^}]+)\}"#) { result, groups in
            guard groups.count == 3 else {
                return ""
            }
            return (groups[1].isEmpty)
                ? expandSimpleString(groups[2])
                : expandFormStyle(groups[2])

        }.stringByReplacingMatches(in: uri)
    }

    
    // MARK: CustomStringConvertible
    
    public var description: String { uri }
    
}
