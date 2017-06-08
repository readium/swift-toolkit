//
//  MediaOverlayNode.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/4/17.
//  Copyright © 2017 Readium. All rights reserved.
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
    public var duration: Double!
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
    public var audio: String?
    public var role = [String]()
    public var children = [MediaOverlayNode]()

    public init(_ text: String? = nil, audio: String? = nil) {
        self.text = text
        self.audio = audio
    }

    // Mark: - Internal Methods.

    /// Return the MO node's fragmentId.
    ///
    /// - Returns: Node's fragment id.
    internal func fragmentId() -> String? {
        guard let text = self.text else {
            return nil
        }
        return text.components(separatedBy: "#").last
    }

    /// Generate a `Clip` from self.
    ///
    /// - Returns: The generated `Clip`.
    /// - Throws: `MediaOverlayNodeError.audio`,
    ///           `MediaOverlayNodeError.timersParsing`.
    internal func clip() throws -> Clip {
        var newClip = Clip()

        // Retrieve the audioString (containing timers + audiofile url), then
        // retrieve both.
        guard let audioString = self.audio,
            let audioFileString = audioString.components(separatedBy: "#").first,
            let audioFileUrl = URL(string: audioFileString) else
        {
            throw MediaOverlayNodeError.audio
        }
        // Relative audio file URL.
        newClip.relativeUrl = audioFileUrl
        guard let times = audioString.components(separatedBy: "#").last else {
            throw MediaOverlayNodeError.timersParsing
        }
        try parseTimer(times, into: &newClip)
        newClip.fragmentId = fragmentId()
        return newClip
    }

    /// Parse the time String to fill `clip`.
    ///
    /// - Parameters:
    ///   - times: The time string ("t=S.MS,S.MS")
    ///   - clip: The Clip instance where to fill the parsed data.
    /// - Throws: `MediaOverlayNodeError.timersParsing`.
    fileprivate func parseTimer(_ times: String, into clip: inout Clip) throws {
        var times = times
        // Remove "t=" prefix from times string.
        times = times.substring(from: times.index(times.startIndex, offsetBy: 2))
        // Parse start and end times.
        guard let start = times.components(separatedBy: ",").first,
            let end = times.components(separatedBy: ",").last,
            let startTimer = Double(start),
            let endTimer = Double(end) else
        {
            throw MediaOverlayNodeError.timersParsing
        }
        clip.start = startTimer
        clip.end = endTimer
        clip.duration = endTimer - startTimer
    }
}
