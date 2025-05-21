//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// The publicly accessible struct.

/// Clip is the representation of a MediaOverlay file fragment. A clip represent
/// the synchronized audio for a piece of text, it has a file where its data
/// belong, start/end times relatives to this file's data and  a duration
/// calculated from the aforementioned values.
public struct Clip {
    /// The relative URL.
    public var relativeUrl: URL!
    /// The relative fragmentId.
    public var fragmentId: String?
    /// Start time in seconds.
    public var start: Double!
    /// End time in seconds.
    public var end: Double!
    /// Total clip duration in seconds (end - start).
//    @available(iOS, deprecated: 9.0, message: "Don't use it when the value is negative, because some information is missing in the original SMIL file. Try to get the duration from file system or APIs in Fetcher, then minus the start value.")
    public var duration: Double!

    public init() {}
}

/// The Error enumeration of the MediaOverlayNode class.
///
/// - audio: Couldn't generate a proper clip due to erroneous audio property.
/// - timersParsing: Couldn't generate a proper clip due to timersParsing failure.
public enum MediaOverlayNodeError: Error {
    case audio
    case timersParsing
}

/// Represents a MediaOverlay XML node.
public class MediaOverlayNode {
    public var text: String?
    public var clip: Clip?

    public var role = [String]()
    public var children = [MediaOverlayNode]()

    public init(_ text: String? = nil, clip: Clip? = nil) {
        self.text = text
        self.clip = clip
        self.clip?.fragmentId = fragmentId()
    }

    // MARK: - Internal Methods.

    /// Return the MO node's fragmentId.
    ///
    /// - Returns: Node's fragment id.
    public func fragmentId() -> String? {
        guard let text = text else {
            return nil
        }
        return text.components(separatedBy: "#").last
    }
}
