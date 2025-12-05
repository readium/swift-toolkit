//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension NSRegularExpression {
    convenience init(_ pattern: String, options: NSRegularExpression.Options = []) {
        do {
            try self.init(pattern: pattern, options: options)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }

    func matches(in text: String) -> [NSTextCheckingResult] {
        let range = NSRange(text.startIndex..., in: text)
        return matches(in: text, range: range)
    }

    func matchesGroups(in text: String) -> [[String]] {
        matches(in: text).map { $0.groups(in: text) }
    }
}

public extension NSTextCheckingResult {
    func range(in text: String) -> Range<String.Index>? {
        range.range(in: text)
    }

    func groups(in text: String) -> [String] {
        (0 ..< numberOfRanges).compactMap { i in
            guard let range = range(at: i).range(in: text) else {
                return nil
            }
            return String(text[range])
        }
    }
}

public extension NSRange {
    func range(in text: String) -> Range<String.Index>? {
        guard location != NSNotFound else {
            return nil
        }
        return Range(self, in: text)
    }
}

public final class ReplacingRegularExpression: NSRegularExpression, @unchecked Sendable {
    public typealias Replace = (NSTextCheckingResult, [String]) -> String

    private let replace: Replace

    public init(_ pattern: String, replace: @escaping Replace) {
        do {
            self.replace = replace
            try super.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func replacementString(for result: NSTextCheckingResult, in string: String, offset: Int, template templ: String) -> String {
        replace(result, result.groups(in: string))
    }

    public func stringByReplacingMatches(in string: String, options: NSRegularExpression.MatchingOptions = []) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return stringByReplacingMatches(in: string, options: options, range: range, withTemplate: "")
    }
}
