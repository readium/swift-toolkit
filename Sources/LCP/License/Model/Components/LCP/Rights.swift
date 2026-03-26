//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

public struct Rights: JSONValueDecodable {
    /// Maximum number of pages that can be printed over the lifetime of the license.
    public let print: Int?
    /// Maximum number of characters that can be copied to the clipboard over the lifetime of the license.
    public let copy: Int?
    /// Date and time when the license begins.
    public let start: Date?
    /// Date and time when the license ends.
    public let end: Date?
    /// Implementor-specific rights extensions. Each extension is identified by an URI.
    public let extensions: [String: JSONValue]

    public init(json: JSONValue?, warnings: WarningLogger? = nil) throws {
        var json = json?.object ?? [:]
        self.print = json.pop("print")?.positiveNumber()
        copy = json.pop("copy")?.positiveNumber()
        start = json.pop("start")?.parseDate()
        end = json.pop("end")?.parseDate()
        extensions = json
    }
}
