//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Represents a fragment identifier in a URL, e.g. `page=2`, without the `#`
/// prefix.
///
/// A fragment is kept percent-encoded, because it may be structured: a
/// delimiter such as `&` or `=` is different from its percent-encoded form.
///
/// Use ``percentDecoded`` for an opaque fragment such as an HTML element ID, and
/// ``parameters`` for a list of name-value pairs.
public struct URLFragment: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// Percent-encoded fragment, as it appears in a URL.
    public let rawValue: String

    /// Creates a fragment from its percent-encoded form.
    ///
    /// Returns `nil` when `rawValue` is empty or is not a valid
    /// percent-encoded fragment, e.g. `quz baz` instead of `quz%20baz`.
    public init?(rawValue: String) {
        guard !rawValue.isEmpty, rawValue.isPercentEncodedFragment else {
            return nil
        }

        self.rawValue = rawValue
    }

    /// Creates a fragment by percent-encoding the given string.
    ///
    /// The delimiters allowed in a fragment, such as `&` and `=`, are not
    /// encoded.
    ///
    /// Returns `nil` when `percentDecoded` is empty.
    public init?(percentDecoded: String) {
        guard let rawValue = percentDecoded.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) else {
            return nil
        }

        self.init(rawValue: rawValue)
    }

    /// Creates a fragment from its percent-encoded form.
    public init(stringLiteral value: StringLiteralType) {
        guard let fragment = URLFragment(rawValue: value) else {
            preconditionFailure("URLFragment cannot be initialized with an empty or invalid percent-encoded string literal: \(value)")
        }

        self = fragment
    }

    /// Percent-decoded fragment, or `nil` when the percent-encoded bytes are
    /// not valid UTF-8.
    ///
    /// Decoding the whole fragment loses the structure of a fragment made of
    /// name-value pairs, use ``parameters`` instead.
    public var percentDecoded: String? {
        rawValue.removingPercentEncoding
    }

    // MARK: - Parameters

    /// Represents a name-value pair in a URL fragment, e.g. `t=10`.
    public struct Parameter: Hashable, Sendable {
        /// Percent-decoded name.
        public let name: String

        /// Percent-decoded value.
        public let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }

    /// Creates a fragment from a list of name-value pairs, e.g.
    /// `t=10&track=audio`.
    ///
    /// The names and values are percent-encoded, including their `&` and `=`
    /// characters, so that ``parameters`` returns the given pairs.
    ///
    /// Returns `nil` when `parameters` is empty.
    public init?(parameters: [Parameter]) {
        var allowedCharacters = CharacterSet.urlFragmentAllowed
        allowedCharacters.remove(charactersIn: "&=")

        var pairs: [String] = []
        for parameter in parameters {
            guard
                let name = parameter.name.addingPercentEncoding(withAllowedCharacters: allowedCharacters),
                let value = parameter.value.addingPercentEncoding(withAllowedCharacters: allowedCharacters)
            else {
                return nil
            }
            pairs.append(name + "=" + value)
        }

        self.init(rawValue: pairs.joined(separator: "&"))
    }

    /// Returns the name-value pairs of a fragment such as `t=10&track=audio`,
    /// in their order of appearance.
    ///
    /// The fragment is split on `&`, then each pair on its first `=`, before
    /// percent-decoding the names and values, as required by the W3C Media
    /// Fragments URI specification. A component without `=` is ignored, as
    /// well as a pair whose name or value is not valid UTF-8.
    ///
    /// - https://www.w3.org/TR/media-frags/#processing-name-value-components
    public var parameters: [Parameter] {
        rawValue
            .split(separator: "&", omittingEmptySubsequences: true)
            .compactMap { pair in
                guard
                    let separator = pair.firstIndex(of: "="),
                    let name = pair[..<separator].removingPercentEncoding,
                    let value = pair[pair.index(after: separator)...].removingPercentEncoding
                else {
                    return nil
                }
                return Parameter(name: name, value: value)
            }
    }

    /// Returns all the values for the parameter with the given `name`, in
    /// their order of appearance.
    public func parameters(named name: String) -> [String] {
        parameters.filter { $0.name == name }.map(\.value)
    }
}

private extension String {
    /// Returns whether this string is a valid percent-encoded URL fragment,
    /// which is the case when a URL keeps it as is.
    var isPercentEncodedFragment: Bool {
        guard let url = URL(percentEncodedString: "#" + self) else {
            return false
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedFragment == self
    }
}
