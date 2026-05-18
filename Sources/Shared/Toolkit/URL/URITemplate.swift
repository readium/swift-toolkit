//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// A lightweight implementation of URI Template (RFC 6570).
///
/// Only handles simple cases, fitting Readium's use cases.
/// See https://tools.ietf.org/html/rfc6570
public struct URITemplate: CustomStringConvertible {
    public let uri: String

    public init(_ uri: String) {
        self.uri = uri
    }

    private static let parametersRegex = NSRegularExpression(#"\{[?&]?([^}]+)\}"#)

    /// List of URI template parameter keys.
    public var parameters: Set<String> {
        Set(
            URITemplate.parametersRegex
                .matchesGroups(in: uri)
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
    /// Extra parameters not found in the template are ignored.
    /// See RFC 6570 on URI template: https://tools.ietf.org/html/rfc6570
    public func expand(with parameters: [String: LosslessStringConvertible]) -> String {
        let parameters = parameters.mapValues { $0.description }

        func expandSimpleString(_ string: String) -> String {
            string
                .split(separator: ",")
                .map { parameters[String($0).trimmingCharacters(in: .whitespaces)]?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "" }
                .joined(separator: ",")
        }

        func expandFormStyle(prefix: String, _ string: String) -> String {
            let pairs = string
                .split(separator: ",")
                .compactMap { variable -> String? in
                    let key = String(variable).trimmingCharacters(in: .whitespaces)
                    guard let value = parameters[key] else { return nil }
                    return "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                }
                .joined(separator: "&")
            return pairs.isEmpty ? "" : prefix + pairs
        }

        return ReplacingRegularExpression(#"\{([?&]?)([^}]+)\}"#) { _, groups in
            guard groups.count == 3 else {
                return ""
            }
            switch groups[1] {
            case "?": return expandFormStyle(prefix: "?", groups[2])
            case "&": return expandFormStyle(prefix: "&", groups[2])
            default: return expandSimpleString(groups[2])
            }
        }.stringByReplacingMatches(in: uri)
    }

    // MARK: CustomStringConvertible

    public var description: String {
        uri
    }
}
