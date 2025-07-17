//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumInternal

/// The Presentation Hints extension defines a number of hints for User Agents about the way content
/// should be presented to the user.
///
/// https://readium.org/webpub-manifest/extensions/presentation.html
/// https://readium.org/webpub-manifest/schema/extensions/presentation/metadata.schema.json
///
/// These properties are nullable to avoid having default values when it doesn't make sense for a
/// given `Publication`. If a navigator needs a default value when not specified,
/// `Presentation.defaultX` and `Presentation.X.default` can be used.
@available(*, unavailable, message: "This was removed from RWPM. You can still use the EPUB extensibility to access the original values.")
public struct Presentation: Equatable {
    /// Specifies whether or not the parts of a linked resource that flow out of the viewport are
    /// clipped.
    public let clipped: Bool?

    /// continuous Indicates how the progression between resources from the [readingOrder] should be
    /// handled.
    public let continuous: Bool?

    /// Suggested method for constraining a resource inside the viewport.
    public let fit: Fit?

    /// Suggested orientation for the device when displaying the linked resource.
    public let orientation: Orientation?

    /// Indicates if the overflow of linked resources from the `readingOrder` or `resources` should
    /// be handled using dynamic pagination or scrolling.
    public let overflow: Overflow?

    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic
    ///  spread.
    public let spread: Spread?

    /// Hint about the nature of the layout for the linked resources (EPUB extension).
    public let layout: EPUBLayout?

    public init(clipped: Bool? = nil, continuous: Bool? = nil, fit: Fit? = nil, orientation: Orientation? = nil, overflow: Overflow? = nil, spread: Spread? = nil, layout: EPUBLayout? = nil) {
        self.clipped = clipped
        self.continuous = continuous
        self.fit = fit
        self.orientation = orientation
        self.overflow = overflow
        self.spread = spread
        self.layout = layout
    }

    public init(json: Any?, warnings: WarningLogger? = nil) throws {
        guard json != nil else {
            self.init()
            return
        }
        guard let jsonObject = json as? [String: Any] else {
            warnings?.log("Invalid JSON object", model: Self.self, source: json)
            throw JSONError.parsing(Self.self)
        }

        self.init(
            clipped: jsonObject["clipped"] as? Bool,
            continuous: jsonObject["continuous"] as? Bool,
            fit: parseRaw(jsonObject["fit"]),
            orientation: parseRaw(jsonObject["orientation"]),
            overflow: parseRaw(jsonObject["overflow"]),
            spread: parseRaw(jsonObject["spread"]),
            layout: parseRaw(jsonObject["layout"])
        )
    }

    public var json: [String: Any] {
        makeJSON([
            "clipped": encodeIfNotNil(clipped),
            "continuous": encodeIfNotNil(continuous),
            "fit": encodeRawIfNotNil(fit),
            "orientation": encodeRawIfNotNil(orientation),
            "overflow": encodeRawIfNotNil(overflow),
            "spread": encodeRawIfNotNil(spread),
            "layout": encodeRawIfNotNil(layout),
        ])
    }

    /// Suggested method for constraining a resource inside the viewport.
    public enum Fit: String {
        /// The content is centered and scaled to fit both dimensions into the viewport.
        case contain
        /// The content is centered and scaled to fill the viewport.
        case cover
        /// The content is centered and scaled to fit the viewport width.
        case width
        /// The content is centered and scaled to fit the viewport height.
        case height
    }

    /// Suggested orientation for the device when displaying the linked resource.
    public enum Orientation: String {
        case landscape, portrait, auto
    }

    /// Indicates if the overflow of linked resources from the `readingOrder` or `resources` should
    /// be handled using dynamic pagination or scrolling.
    public enum Overflow: String {
        /// Content overflow should be handled using dynamic pagination.
        case paginated
        /// Content overflow should be handled using scrolling.
        case scrolled
        /// The User Agent can decide how overflow should be handled.
        case auto
    }

    /// Indicates how the linked resource should be displayed in a reading environment that
    /// displays synthetic spreads.
    public enum Page: String {
        case left, right, center
    }

    /// Indicates the condition to be met for the linked resource to be rendered within a synthetic
    /// spread.
    public enum Spread: String {
        /// The resource should be displayed in a spread only if the device is in landscape mode.
        case landscape
        /// The resource should be displayed in a spread whatever the device orientation is.
        case both
        /// The resource should never be displayed in a spread.
        case none
        /// The resource is left to the User Agent.
        case auto
    }
}
