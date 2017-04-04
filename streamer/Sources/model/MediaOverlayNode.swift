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
    var text: String?
    var audio: String?
    var role = [String]()
    var children = [MediaOverlayNode]()

    public init(_ text: String? = nil, audio: String? = nil) {
        self.text = text
        self.audio = audio
    }
}
