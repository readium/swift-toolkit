//
//  MediaOverlayNode.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/4/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// The fonctionnal object
public struct Clip {
    public var relativeUrl: URL!
    public var start: Double!
    public var end: Double!
    public var duration: Double!
}

/// Represents a single node of a Media Overlay.
public class MediaOverlayNode {
    var text: String?
    var audio: String?
    var role = [String]()
    var children = [MediaOverlayNode]()


    public init(_ text: String? = nil, audio: String? = nil) {
        self.text = text
        self.audio = audio
    }

//    /// OLD trashfunc™ TO REPLACE - below func will do
//    /// Find the first next valid element.
//    public func findParElement() -> MediaOverlayNode? {
//        if role.contains("section") {
//            for child in self.children {
//                if let element = child.findParElement(),
//                    element.audio != nil {
//                    return element
//                }
//            }
//        } else if audio != nil {
//            return self
//        }
//        return nil
//    }

    public func getClip(forFragmentWithId id: String) -> Clip? {
        var newClip = Clip()

        let audioElementForFragment = findNode(forFragment: id)

        // Retrieve the audioString (containing timers + audiofile url), then
        // retrieve both.
        guard let audioString = audioElementForFragment?.audio,
            let audioFileString = audioString.components(separatedBy: "#").first,
            let audioFileUrl = URL(string: audioFileString),
            var times = audioString.components(separatedBy: "#").last else
        {
            return nil
        }
        // Relative audio file URL.
        newClip.relativeUrl = audioFileUrl
        
        // Remove "t=" prefix from times string.
        times = times.substring(from: times.index(times.startIndex, offsetBy: 2))
        // Parse start and end times.
        guard let start = times.components(separatedBy: ",").first,
            let end = times.components(separatedBy: ",").last,
            let startTimer = Double(start),
            let endTimer = Double(end) else
        {
            return nil
        }
        newClip.start = startTimer
        newClip.end = endTimer
        newClip.duration = endTimer - startTimer
        return newClip
    }

    /// <#Description#>
    ///
    /// - Parameter forFragment: <#forFragment description#>
    /// - Returns: <#return value description#>
    public func findNode(forFragment fragment: String?) -> MediaOverlayNode? {
        return _findNode(forFragment: fragment, inNodes: self.children)
    }
    /// [RECURISVE]
    /// Find the node (<par>) corresponding to "fragment" ?? nil.
    ///
    /// - Parameters:
    ///   - fragment: The current fragment name for which we are looking the 
    ///               associated media overlay node.
    ///   - nodes: The set of MediaOverlayNodes where to search. Default to 
    ///            self children.
    /// - Returns: The node we found ?? nil.
    fileprivate func _findNode(forFragment fragment: String?,
                         inNodes nodes: [MediaOverlayNode]) -> MediaOverlayNode?
    {
        // For each node of the current scope..
        for node in nodes {
            // If the node is a "section" (<seq> sequence element)..
            if node.role.contains("section") {
                // Try to find par nodes inside.
                if let found = _findNode(forFragment: fragment, inNodes: node.children)
                {
                    return found
                }
            }
            // If the node text refer to filename or that filename is nil,
            // return node.
            if fragment == nil || node.text?.contains(fragment!) ?? false {
                return node
            }
        }
        // If nothing found, return nil.
        return nil
    }

    /// <#Description#>
    ///
    /// - Parameter forFragment: <#forFragment description#>
    /// - Returns: <#return value description#>
    public func findNextNode(forFragment fragment: String?) -> MediaOverlayNode? {
        return _findNextNode(forFragment: fragment, inNodes: self.children)
    }
    /// [RECURISVE]
    /// Find the node (<par>) corresponding to the next one after the given 
    /// "fragment" ?? nil.
    ///
    /// - Parameters:
    ///   - fragment: The fragment name corresponding to the node previous to 
    ///               the one we want.
    ///   - nodes: The set of MediaOverlayNodes where to search. Default to
    ///            self children.
    /// - Returns: The node we found ?? nil.
    fileprivate func _findNextNode(forFragment fragment: String?,
                             inNodes nodes: [MediaOverlayNode]) -> MediaOverlayNode?
    {
        var previousNodeFoundFlag = false

        // For each node of the current scope..
        for node in nodes {
            guard !previousNodeFoundFlag else {
                return node
            }
            // If the node is a "section" (<seq> sequence element)..
            guard !role.contains("section") else {
                // Try to find par nodes inside.
                return _findNode(forFragment: fragment, inNodes: node.children)
            }
            // If the node text refer to filename or that filename is nil,
            // return node.
            if fragment == nil || node.text?.contains(fragment!)  ?? false {
                previousNodeFoundFlag = true
            }
        }
        // If nothing found, return nil.
        return nil
    }
}
