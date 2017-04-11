//
//  SMILParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

/// The object containing the methods used to parse SMIL files.
internal class SMILParser {

    /// [RECURSIVE]
    /// Parse the <seq> elements at the current XML level. It will recursively
    /// parse they childrens <par> and <seq>
    ///
    /// - Parameters:
    ///   - element: The XML element which should contain <seq>.
    ///   - parent: The parent MediaOverlayNode of the "to be creatred" nodes.
    internal func parseSequences(in element: AEXMLElement,
                                 withParent parent: MediaOverlayNode,
                                 publicationSpine spine: inout [Link])
    {
        guard let sequenceElements = element["seq"].all,
            !sequenceElements.isEmpty else
        {
            return
        }
        // TODO: 2 lines differ from the version used in the parseMediaOverlay
        //       for loop. Refactor?
        for sequence in sequenceElements {
            let newNode = MediaOverlayNode()

            newNode.role.append("section")
            newNode.text = sequence.attributes["epub:textref"]
            parseParameters(in: sequence, withParent: newNode)
            parseSequences(in: sequence, withParent: newNode, publicationSpine: &spine)

            let baseHrefParent = parent.text?.components(separatedBy: "#")[0]

            guard let baseHref = newNode.text?.components(separatedBy: "#")[0],
                baseHref != baseHrefParent else
            {
                parent.children.append(newNode)
                continue
            }
            guard let link = spine.first(where: {
                guard let linkRef = $0.href else {
                    return false
                }
                return linkRef.contains(baseHref) || baseHref.contains(linkRef)
            }) else {
                continue
            }
            link.mediaOverlays.append(newNode)
            link.properties.append(EpubConstant.mediaOverlayURL + link.href!)
        }
    }

    /// Parse the <par> elements at the current XML element level.
    ///
    /// - Parameters:
    ///   - element: The XML element which should contain <par>.
    ///   - parent: The parent MediaOverlayNode of the "to be creatred" nodes.
    internal func parseParameters(in element: AEXMLElement,
                                  withParent parent: MediaOverlayNode)
    {
        guard let parameterElements = element["par"].all,
            !parameterElements.isEmpty else
        {
            return
        }
        // For each <par> in the current scope.
        for parameterElement in parameterElements {
            let newNode = MediaOverlayNode()

            guard let audioElement = parameterElement["audio"].first else {
                return
            }
            let audioFilePath = parse(audioElement: audioElement)

            newNode.audio = audioFilePath
            newNode.text = parameterElement["text"].attributes["src"]
            parent.children.append(newNode)
        }
    }

    /// Converts a smile time string into seconds String.
    ///
    /// - Parameter time: The smile time String.
    /// - Returns: The converted value in Seconds as String.
    internal func smilTimeToSeconds(_ time: String) -> String {
        let timeFormat: SmilTimeFormat

        if time.contains("h") {
            timeFormat = .hour
        } else if time.contains("s") {
            timeFormat = .second
        } else if time.contains("ms") {
            timeFormat = .milisecond
        } else {
            let timeArity = time.components(separatedBy: ":").count

            guard let format = SmilTimeFormat(rawValue: timeArity) else {
                return ""
            }
            timeFormat = format
        }
        return timeFormat.convertToseconds(smilTime: time)
    }

    /// Parse the <audio> XML element, children of <par> elements.
    ///
    /// - Parameter audioElement: The audio XML element.
    /// - Returns: The formated string representing the data.
    fileprivate func parse(audioElement: AEXMLElement) -> String? {
        guard var audio = audioElement.attributes["src"],
            let clipBegin = audioElement.attributes["clipBegin"],
            let clipEnd = audioElement.attributes["clipEnd"] else
        {
            return nil
        }
        /// Clean relative path elements "../"
        let components = audio.components(separatedBy: "/")
        if components[0] == ".." {
            audio.removeSubrange(audio.startIndex..<audio.index(audio.startIndex, offsetBy: 3))
        }
        audio += "#t="
        audio += smilTimeToSeconds(clipBegin)
        audio += ","
        audio += smilTimeToSeconds(clipEnd)
        return audio
    }
}

/// Describes the differents time string format of the smile tags.
///
/// - splitMonadic: Handle `SS` format.
/// - splitDyadic//MM/SS: Handles `MM/SS` format.
/// - splitTriadic//HH:MM:SS: Handles `HH:MM:SS` format.
/// - milisecond: Handles `MM"ms"` format.
/// - second: Handles `SS"s" || SS.MM"s"` format
/// - hour: Handles `HH"h" || HH.MM"h"` format.
internal enum SmilTimeFormat: Int {
    case splitMonadic = 1
    case splitDyadic
    case splitTriadic
    case milisecond
    case second
    case hour
}

internal extension SmilTimeFormat {

    /// Return the seconds double value from a possible SS.MS format.
    ///
    /// - Parameter seconds: The seconds String.
    /// - Returns: The translated Double value.
    fileprivate func parseSeconds(_ time: String) -> Double {
        let secMilsec = time.components(separatedBy: ".")
        var seconds = 0.0

        if secMilsec.count == 2 {
            seconds = Double(secMilsec[0]) ?? 0.0
            seconds += (Double(secMilsec[1]) ?? 0.0) / 1000.0
        } else {
            seconds = Double(time) ?? 0.0
        }
        return seconds
    }

    /// Will confort the `smileTime` to the equivalent in seconds given it's
    /// type.
    ///
    /// - Parameter time: The `smilTime` `String`.
    /// - Returns: The converted value in seconds.
    internal func convertToseconds(smilTime time: String) -> String {
        var seconds = 0.0

        switch self {
        case .milisecond:
            let ms = Double(time.replacingOccurrences(of: "ms", with: ""))
            seconds = (ms ?? 0) / 1000.0
        case .second:
            seconds = Double(time.replacingOccurrences(of: "s", with: "")) ?? 0
        case .hour:
            let hourMin = time.replacingOccurrences(of: "h", with: "").components(separatedBy: ".")
            let hoursToSeconds = (Double(hourMin[0]) ?? 0) * 3600.0
            let minutesToSeconds = (Double(hourMin[1]) ?? 0) * 0.6 * 60.0

            seconds = hoursToSeconds + minutesToSeconds
        case .splitMonadic:
            return time
        case .splitDyadic:
            let minSec = time.components(separatedBy: ":")

            // Min
            seconds += (Double(minSec[0]) ?? 0.0) * 60
            // Sec
            seconds += parseSeconds(minSec[1])
        case .splitTriadic:
            let hourMinSec = time.components(separatedBy: ":")

            // Hour
            seconds += (Double(hourMinSec[0]) ?? 0.0) * 3600.0
            // Min
            seconds += (Double(hourMinSec[1]) ?? 0.0) * 60
            // Sec
            seconds += parseSeconds(hourMinSec[2])
        }
        return String(seconds)
    }
}
