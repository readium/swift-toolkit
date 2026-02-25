//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// MARK: - Spatial Selector

/// Identifies an area of pixels within a visual media resource.
///
/// Follows the W3C Media Fragments URI specification for the spatial
/// dimension.
///
/// - https://www.w3.org/TR/media-frags/#naming-space
public struct SpatialSelector: Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public var unit: Unit

    public enum Unit: Hashable, Sendable {
        case percent
        case pixel
    }

    public init(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        unit: Unit
    ) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.unit = unit
    }
}

// MARK: - Fragment

public extension SpatialSelector {
    /// Creates a ``SpatialSelector`` from a URL fragment following the W3C
    /// Media Fragments URI specification (spatial dimension).
    ///
    /// Fragment format: `xywh=[unit:]x,y,w,h`
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-space
    init?(fragment: URLFragment) {
        let raw = fragment.rawValue
        guard raw.hasPrefix("xywh=") else { return nil }
        var value = String(raw.dropFirst(5))

        let unit: Unit
        if value.hasPrefix("percent:") {
            unit = .percent
            value = String(value.dropFirst(8))
        } else if value.hasPrefix("pixel:") {
            unit = .pixel
            value = String(value.dropFirst(6))
        } else {
            unit = .pixel
        }

        let parts = value.components(separatedBy: ",")
        guard parts.count == 4,
              let x = Double(parts[0]),
              let y = Double(parts[1]),
              let w = Double(parts[2]),
              let h = Double(parts[3])
        else { return nil }

        self.init(x: x, y: y, width: w, height: h, unit: unit)
    }

    /// Returns a URL fragment representation of this selector following the
    /// W3C Media Fragments URI specification (spatial dimension).
    ///
    /// - https://www.w3.org/TR/media-frags/#naming-space
    var fragment: URLFragment {
        let unitPrefix: String
        switch unit {
        case .percent: unitPrefix = "percent:"
        case .pixel: unitPrefix = ""
        }
        return URLFragment(rawValue: "xywh=\(unitPrefix)\(x),\(y),\(width),\(height)")!
    }
}

public extension URLFragment {
    /// Parses the fragment as a ``SpatialSelector`` following the W3C Media
    /// Fragments URI specification.
    var spatialSelector: SpatialSelector? {
        SpatialSelector(fragment: self)
    }
}
