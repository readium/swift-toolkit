//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public struct Rights {
    /// Maximum number of pages that can be printed over the lifetime of the license.
    public let print: Int?
    /// Maximum number of characters that can be copied to the clipboard over the lifetime of the license.
    public let copy: Int?
    /// Date and time when the license begins.
    public let start: Date?
    /// Date and time when the license ends.
    public let end: Date?
    /// Implementor-specific rights extensions. Each extension is identified by an URI.
    public let extensions: [String: Any]

    init(json: [String: Any]?) throws {
        var json = json ?? [:]
        self.print = json.removeValue(forKey: "print") as? Int
        copy = json.removeValue(forKey: "copy") as? Int
        start = (json.removeValue(forKey: "start") as? String)?.dateFromISO8601
        end = (json.removeValue(forKey: "end") as? String)?.dateFromISO8601
        extensions = json
    }
}
