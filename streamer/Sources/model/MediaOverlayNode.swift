//
//  MediaOverlayNode.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/4/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// Represents a single node of a Media Overlay.
public class MediaOverlayNode {
    public var text: String?
    public var audio: String?
    public var role = [String]()
    public var children = [MediaOverlayNode]()

    public init(_ text: String? = nil, audio: String? = nil) {
        self.text = text
        self.audio = audio
    }

    /// OLD trashfunc™ TO REPLACE - below func will do
    /// Find the first next valid element.
    public func findParElement() -> MediaOverlayNode? {
        if role.contains("section") {
            for child in self.children {
                if let element = child.findParElement(),
                    element.audio != nil {
                    return element
                }
            }
        } else if audio != nil {
            return self
        }
        return nil
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
            guard !role.contains("section") else {
                // Try to find par nodes inside.
                return _findNode(forFragment: fragment, inNodes: node.children)
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
