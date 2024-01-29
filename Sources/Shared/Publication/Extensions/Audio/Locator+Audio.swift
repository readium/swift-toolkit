//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Audio extensions for `Locator.Locations`.
public extension Locator.Locations {
  enum TimeFragment: Equatable, Sendable {
    case offset(Double)
    case duration(Double)
    case range(Double, Double)

    init?(offset: Double?, duration: Double?) {
      switch (offset, duration) {
      case let (.some(offset), .some(duration)):
        self = .range(offset, duration)
      case let (.some(offset), .none):
        self = .offset(offset)
      case let (.none, .some(duration)):
        self = .duration(duration)
      case (.none, .none):
        return nil
      }
    }

    public var offset: Double? {
      switch self {
      case let .offset(offset):
        return offset
      case let .range(offset, _):
        return offset
      default:
        return nil
      }
    }

    public var duration: Double? {
      switch self {
      case let .duration(duration):
        return duration
      case let .range(_, duration):
        return duration
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
        var offset: Double?
        var duration: Double?
        if group1NSRange.location != NSNotFound, let group1Range = Range(group1NSRange, in: fragment) {
          offset = Double(fragment[group1Range])
        }
        if group2NSRange.location != NSNotFound, let group2Range = Range(group2NSRange, in: fragment) {
          duration = Double(fragment[group2Range])
        }
        return TimeFragment(offset: offset, duration: duration)
      }
    }
    return nil
  }
}
