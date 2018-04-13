//
//  SMILParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/11/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import R2Shared
import AEXML

/// The object containing the methods used to parse SMIL files.
final internal class SMILParser {
    
    /// [RECURSIVE]
    /// Parse the <seq> elements at the current XML level. It will recursively
    /// parse they childrens <par> and <seq>
    ///
    /// - Parameters:
    ///   - element: The XML element which should contain <seq>.
    ///   - parent: The parent MediaOverlayNode of the "to be creatred" nodes.
    ///   - spine: <#spine description#>
    ///   - base: The base location of the file for path normalization.
    static internal func parseSequences(in element: AEXMLElement,
                                        withParent parent: MediaOverlayNode,
                                        publicationSpine spine: inout [Link],
                                        base: String)
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
            newNode.text = normalize(base: base, href: sequence.attributes["epub:textref"]!)
            
            parseParameters(in: sequence, withParent: newNode, base: base)
            parseSequences(in: sequence, withParent: newNode, publicationSpine: &spine, base: base)
            
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
            link.properties.mediaOverlay = EpubConstant.mediaOverlayURL + link.href!
        }
    }
    
    /// Parse the <par> elements at the current XML element level.
    ///
    /// - Parameters:
    ///   - element: The XML element which should contain <par>.
    ///   - parent: The parent MediaOverlayNode of the "to be creatred" nodes.
    static internal func parseParameters(in element: AEXMLElement,
                                         withParent parent: MediaOverlayNode,
                                         base: String)
    {
        guard let parameterElements = element["par"].all,
            !parameterElements.isEmpty else
        {
            return
        }
        
        // For each <par> in the current scope.
        for parameterElement in parameterElements {
            
            guard let audioElement = parameterElement["audio"].first else {
                continue // no audio
            }
            guard let audioClip = parse(base: base, audioElement: audioElement) else {
                continue // invalid audio element
            }
            
            let nodeText = normalize(base: base, href: parameterElement["text"].attributes["src"]!)
            
            let newNode = MediaOverlayNode(nodeText, clip: audioClip)
            parent.children.append(newNode)
        }
    }
    
    /// Converts a smile time string into seconds String.
    ///
    /// - Parameter time: The smile time String.
    /// - Returns: The converted value in Seconds as String.
    static internal func smilTimeToSeconds(_ time: String) -> String {
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
    static fileprivate func parse(base: String, audioElement: AEXMLElement) -> Clip? {
        guard let audioSrc = audioElement.attributes["src"] else {
            return nil
        }
        
        //SML3.0/1.0: clipBegin/clip-begin and clipEnd/clip-end
        let clipBegin = audioElement.attributes["clipBegin"] ?? "0.0"
        let clipEnd = audioElement.attributes["clipEnd"] ?? "-1.0"
        
        let parsedBegin = SMILParser.smilTimeToSeconds(clipBegin)
        let parsedEnd = SMILParser.smilTimeToSeconds(clipEnd)
        
        let timeBegin = Double(parsedBegin) ?? 0.0
        let timeEnd = Double(parsedEnd) ?? -1.0
        
        let audioString = normalize(base: base, href: audioSrc)
        guard let audioURL = URL(string: audioString) else {return nil}
        
        var newClip = Clip()
        newClip.relativeUrl = audioURL
    
        newClip.start = timeBegin
        newClip.end = timeEnd
        
        // It's not recommended getting the duration of audio here.
        // It's still inside the *.epub file, actually a zip file.
        // As the result, it cannot utilize AV APIs from Apple. The soultion
        // And the fetcher (minizip) only provide data access, that might be IO problem.
        
        newClip.duration = timeEnd>0 ? (timeEnd - timeBegin):-1
        //let asset = AVURLAsset(url: URL(fileURLWithPath: "resource"))
        //let duration = Double(CMTimeGetSeconds(asset.duration))
        //fetcher.data(forRelativePath: "EPUB/audio/basic_tests.mp3")
        //fetcher.dataStream(forRelativePath: "EPUB/audio/basic_tests.mp3")
        
        return newClip
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
