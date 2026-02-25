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

    /// Returns `true` when this selector points to the beginning of the media.
    public var isAtStart: Bool {
        switch self {
        case let .position(p): return p.time == 0
        case let .clip(c): return (c.start ?? 0) == 0 && c.end == nil
        }
    }
}

/// A single point in time within a media rendition.
public struct TemporalPosition: Hashable, Sendable {
    /// Time offset from the start of the media rendition, in seconds.
    public var time: TimeInterval

    public init(time: TimeInterval) {
        self.time = time
    }
}

/// A time range within a media rendition.
public struct TemporalClip: Hashable, Sendable {
    /// Start of the clip, in seconds from the beginning of the media rendition.
    public var start: TimeInterval?

    /// End of the clip, in seconds from the beginning of the media rendition.
    public var end: TimeInterval?

    public init(
        start: TimeInterval? = nil,
        end: TimeInterval? = nil
    ) {
        self.start = start
        self.end = end
    }
}

// MARK: - Fragment

public extension TemporalSelector {
    /// Creates a ``TemporalSelector`` from a URL fragment following the W3C
    /// Media Fragments URI specification (temporal dimension).
    ///
    /// Fragment format: `t=[npt:]start[,end]`
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    init?(fragment: URLFragment) {
        let raw = fragment.rawValue
        guard raw.hasPrefix("t=") else { return nil }
        var value = String(raw.dropFirst(2))

        // Strip optional `npt:` prefix
        if value.hasPrefix("npt:") {
            value = String(value.dropFirst(4))
        }

        let parts = value.components(separatedBy: ",")

        switch parts.count {
        case 1:
            guard !parts[0].isEmpty, let t = TimeInterval(parts[0]) else { return nil }
            self = .position(TemporalPosition(time: t))

        case 2:
            let startStr = parts[0]
            let endStr = parts[1]

            let start: TimeInterval? = startStr.isEmpty ? nil : TimeInterval(startStr)
            let end: TimeInterval? = endStr.isEmpty ? nil : TimeInterval(endStr)

            if start == nil, end == nil { return nil }

            if !startStr.isEmpty, endStr.isEmpty {
                // `t=10,` — open-ended clip, not a point
                guard let t = start else { return nil }
                self = .clip(TemporalClip(start: t, end: nil))
            } else {
                self = .clip(TemporalClip(start: start, end: end))
            }

        default:
            return nil
        }
    }

    /// Returns a URL fragment representation of this selector following the
    /// W3C Media Fragments URI specification (temporal dimension).
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-time
    var fragment: URLFragment {
        switch self {
        case let .position(p):
            return URLFragment(rawValue: "t=\(p.time)")!
        case let .clip(c):
            let start = c.start.map { "\($0)" } ?? ""
            let end = c.end.map { "\($0)" } ?? ""
            return URLFragment(rawValue: "t=\(start),\(end)")!
        }
    }
}

public extension URLFragment {
    /// Parses the fragment as a ``TemporalSelector`` following the W3C Media
    /// Fragments URI specification.
    var temporalSelector: TemporalSelector? {
        TemporalSelector(fragment: self)
    }
}
