//
//  PublicationParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 4/4/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// The parsing protocol.
protocol PublicationParser {
    func parse(fileAtPath: String) throws -> PubBox
}
