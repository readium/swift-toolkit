//
//  NSRegularExpression.swift
//  r2-shared-swift
//
//  Created by Mickaël Menu on 04/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation

extension NSRegularExpression {
    
    convenience init(_ pattern: String) {
        do {
            try self.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }

    func matches(in text: String) -> [[String]] {
        let range = NSRange(text.startIndex..., in: text)
        return matches(in: text, range: range)
            .map { $0.groups(in: text) }
    }

}

extension NSTextCheckingResult {
    
    func groups(in text: String) -> [String] {
        return (0..<numberOfRanges).compactMap { i in
            let nsRange = range(at: i)
            guard
                nsRange.location != NSNotFound,
                let range = Range(nsRange, in: text) else
            {
                return nil
            }
            return String(text[range])
        }
    }

}

final class ReplacingRegularExpression: NSRegularExpression {
    
    typealias Replace = (NSTextCheckingResult, [String]) -> String
    
    private let replace: Replace
    
    init(_ pattern: String, replace: @escaping Replace) {
        do {
            self.replace = replace
            try super.init(pattern: pattern)
        } catch {
            preconditionFailure("Illegal regular expression: \(pattern).")
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func replacementString(for result: NSTextCheckingResult, in string: String, offset: Int, template templ: String) -> String {
        return replace(result, result.groups(in: string))
    }
    
    func stringByReplacingMatches(in string: String, options: NSRegularExpression.MatchingOptions = []) -> String {
        let range = NSRange(string.startIndex..., in: string)
        return stringByReplacingMatches(in: string, options: options, range: range, withTemplate: "")
    }

}
