//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// MARK: - Temporal Selector

/// Identifies a time instant or clip within a media resource.
///
/// Follows the W3C Media Fragments URI specification for the temporal
/// dimension.
///
/// - https://www.w3.org/TR/media-frags/#naming-time
public enum TemporalSelector: Hashable, Sendable {
    /// A single point in time within the media stream.
    case position(TemporalPosition)

    /// A time range (clip) within the media stream.
    case clip(TemporalClip)

    /// Time to seek to, in seconds: the position's time, or the clip's start.
    public var start: TimeInterval {
        switch self {
        case let .position(p): return p.time
        case let .clip(c): return c.start
        }
    }

    /// Returns `true` when this selector is a position at the beginning of the
    /// media.
    public var isAtStart: Bool {
        switch self {
        case let .position(p): return p.time == 0
        case .clip: return false
        }
    }
}

/// A single point in time within a media rendition.
public struct TemporalPosition: Hashable, Sendable {
    /// Time offset from the start of the media rendition, in seconds.
    public let time: TimeInterval

    /// Returns `nil` when `time` is negative or not finite.
    public init?(time: TimeInterval) {
        guard let time = time.validTime else {
            return nil
        }
        self.time = time
    }
}

/// A time range within a media rendition.
public struct TemporalClip: Hashable, Sendable {
    /// Start of the clip, in seconds from the beginning of the media rendition.
    public let start: TimeInterval

    /// End of the clip, in seconds from the beginning of the media rendition.
    public let end: TimeInterval

    /// Returns `nil` when a time is negative or not finite, or when `start` is
    /// not before `end`.
    public init?(start: TimeInterval = 0, end: TimeInterval) {
        guard
            let start = start.validTime,
            let end = end.validTime,
            start < end
        else {
            return nil
        }
        self.start = start
        self.end = end
    }
}

private extension TimeInterval {
    /// Returns the time when it is finite and not negative, normalizing a
    /// negative zero to 0.
    var validTime: TimeInterval? {
        guard isFinite, self >= 0 else {
            return nil
        }
        return self == 0 ? 0 : self
    }
}

// MARK: - Fragment

public extension TemporalSelector {
    /// Creates a ``TemporalSelector`` from a URL fragment following the W3C
    /// Media Fragments URI specification (temporal dimension).
    ///
    /// Fragment format: `t=[npt:][start][,end]`, possibly among other
    /// dimensions separated by `&`. The last valid temporal dimension wins.
    ///
    /// The fragment must be percent-decoded, as returned by
    /// ``URLProtocol/fragment``.
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    init?(fragment: URLFragment) {
        let selector = fragment.rawValue
            .split(separator: "&", omittingEmptySubsequences: true)
            .reversed()
            .lazy
            .compactMap { dimension -> TemporalSelector? in
                guard dimension.hasPrefix("t=") else {
                    return nil
                }
                return TemporalSelector(nptValue: dimension.dropFirst(2))
            }
            .first

        guard let selector = selector else {
            return nil
        }
        self = selector
    }

    /// Parses the value of a temporal dimension, e.g. `npt:10,20`.
    private init?(nptValue: Substring) {
        var value = nptValue
        if value.hasPrefix("npt:") {
            value = value.dropFirst(4)
        }

        let parts = value.split(separator: ",", omittingEmptySubsequences: false)

        switch parts.count {
        case 1:
            guard
                let time = parseNPTTime(parts[0]),
                let position = TemporalPosition(time: time)
            else {
                return nil
            }
            self = .position(position)

        case 2:
            // An omitted start means the beginning of the media, but the end
            // is required after a comma.
            guard
                let start = parts[0].isEmpty ? 0 : parseNPTTime(parts[0]),
                let end = parseNPTTime(parts[1]),
                let clip = TemporalClip(start: start, end: end)
            else {
                return nil
            }
            self = .clip(clip)

        default:
            return nil
        }
    }

    /// Returns a URL fragment representation of this selector following the
    /// W3C Media Fragments URI specification (temporal dimension).
    ///
    /// Times are written in seconds with their exact decimal form, e.g.
    /// `t=71.5` or `t=10,20`.
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    var fragment: URLFragment {
        switch self {
        case let .position(p):
            return URLFragment(rawValue: "t=\(formatNPTSeconds(p.time))")!
        case let .clip(c):
            return URLFragment(rawValue: "t=\(formatNPTSeconds(c.start)),\(formatNPTSeconds(c.end))")!
        }
    }
}

/// Parses a Normal Play Time, in one of the forms `ss[.fraction]`,
/// `mm:ss[.fraction]` or `hh:mm:ss[.fraction]`.
private func parseNPTTime(_ s: Substring) -> TimeInterval? {
    let components = s.split(separator: ":", omittingEmptySubsequences: false)
    guard
        let last = components.last,
        let (integer, fraction) = splitNPTSeconds(last)
    else {
        return nil
    }

    // The clock forms are converted to whole seconds before parsing the
    // fraction, so that `01:01.029` and `61.029` give the same value.
    let seconds: String
    switch components.count {
    case 1:
        seconds = String(integer)

    case 2:
        guard
            let mm = parseNPTSexagesimal(components[0]),
            let ss = parseNPTSexagesimal(integer)
        else {
            return nil
        }
        seconds = formatNPTSeconds(mm * 60 + ss)

    case 3:
        guard
            let hh = parseNPTDigits(components[0]),
            let mm = parseNPTSexagesimal(components[1]),
            let ss = parseNPTSexagesimal(integer)
        else {
            return nil
        }
        let total = hh * 3600 + mm * 60 + ss
        guard total.isFinite else {
            return nil
        }
        seconds = formatNPTSeconds(total)

    default:
        return nil
    }

    return TimeInterval(fraction.isEmpty ? seconds : seconds + "." + fraction)
}

/// Splits seconds into their integer and fraction digits: `71`, `71.5`.
///
/// The fraction is empty when there is none.
private func splitNPTSeconds(_ s: Substring) -> (integer: Substring, fraction: Substring)? {
    let parts = s.split(separator: ".", maxSplits: 1, omittingEmptySubsequences: false)
    let fraction = parts.count == 2 ? parts[1] : ""
    guard parts[0].isASCIIDigits, fraction.isEmpty || fraction.isASCIIDigits else {
        return nil
    }
    return (parts[0], fraction)
}

/// Parses two digits below 60.
private func parseNPTSexagesimal(_ s: Substring) -> TimeInterval? {
    guard s.count == 2, let value = parseNPTDigits(s), value < 60 else {
        return nil
    }
    return value
}

/// Parses one or more digits.
private func parseNPTDigits(_ s: Substring) -> TimeInterval? {
    guard s.isASCIIDigits else {
        return nil
    }
    return TimeInterval(s)
}

/// Writes seconds with plain digits and a dot, without a sign or an exponent.
///
/// The description of a `Double` is the shortest text parsing back to the same
/// value, but it uses an exponent for small and large values.
private func formatNPTSeconds(_ time: TimeInterval) -> String {
    let text = "\(time)"

    guard let exponentIndex = text.firstIndex(where: { $0 == "e" || $0 == "E" }) else {
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    let mantissa = text[..<exponentIndex].split(separator: ".", omittingEmptySubsequences: false)
    let integer = mantissa[0]
    let fraction = mantissa.count > 1 ? mantissa[1] : ""
    let exponent = Int(text[text.index(after: exponentIndex)...]) ?? 0

    let digits = String(integer + fraction)
    // Position of the decimal point in `digits`.
    let point = integer.count + exponent

    var result: String
    if point <= 0 {
        result = "0." + String(repeating: "0", count: -point) + digits
    } else if point >= digits.count {
        result = digits + String(repeating: "0", count: point - digits.count)
    } else {
        let index = digits.index(digits.startIndex, offsetBy: point)
        result = digits[..<index] + "." + digits[index...]
    }

    if result.contains(".") {
        while result.hasSuffix("0") {
            result.removeLast()
        }
        if result.hasSuffix(".") {
            result.removeLast()
        }
    }
    return result
}

private extension Substring {
    var isASCIIDigits: Bool {
        !isEmpty && utf8.allSatisfy { (UInt8(ascii: "0") ... UInt8(ascii: "9")).contains($0) }
    }
}

public extension URLFragment {
    /// Parses the fragment as a ``TemporalSelector`` following the W3C Media
    /// Fragments URI specification.
    var temporalSelector: TemporalSelector? {
        TemporalSelector(fragment: self)
    }
}
