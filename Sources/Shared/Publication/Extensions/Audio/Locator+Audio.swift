//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Audio extensions for `Locator.Locations`.
public extension Locator.Locations {
    enum TimeFragment: Equatable, Sendable {
        case begin(Double)
        case end(Double)
        case interval(Double, Double)

        init?(begin: Double?, end: Double?) {
            switch (begin, end) {
            case let (.some(begin), .some(end)):
                self = .interval(begin, end)
            case let (.some(begin), .none):
                self = .begin(begin)
            case let (.none, .some(end)):
                self = .end(end)
            case (.none, .none):
                return nil
            }
        }

        public var begin: Double? {
            switch self {
            case let .begin(begin):
                return begin
            case let .interval(begin, _):
                return begin
            default:
                return nil
            }
        }

        public var end: Double? {
            switch self {
            case let .end(end):
                return end
            case let .interval(_, end):
                return end
            default:
                return nil
            }
        }
    }

    private static let timeFragmentRegex = try! NSRegularExpression(pattern: #"t=([^,]*),?([^,]*)"#)

    /// The Temporal Dimension media fragment, if it exists.
    /// https://www.w3.org/TR/media-frags/#media-fragment-syntax
    var time: TimeFragment? {
        for fragment in fragments {
            let range = NSRange(fragment.startIndex ..< fragment.endIndex, in: fragment)
            if let match = Self.timeFragmentRegex.firstMatch(in: fragment, range: range) {
                let group1NSRange = match.range(at: 1)
                let group2NSRange = match.range(at: 2)
                var begin: Double?
                var end: Double?
                if group1NSRange.location != NSNotFound, let group1Range = Range(group1NSRange, in: fragment) {
                    begin = Double(fragment[group1Range])
                }
                if group2NSRange.location != NSNotFound, let group2Range = Range(group2NSRange, in: fragment) {
                    end = Double(fragment[group2Range])
                }
                return TimeFragment(begin: begin, end: end)
            }
        }
        return nil
    }
}
