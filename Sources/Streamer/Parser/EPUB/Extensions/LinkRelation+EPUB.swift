//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared

extension LinkRelation {
    init?(epubType type: String) {
        self = switch type {
        case "cover": .cover
        case "toc": .contents
        case "bodymatter": .start
        default: LinkRelation("http://idpf.org/epub/vocab/structure/#\(type)")
        }
    }

    init?(epub2Type type: String) {
        let asEPUB3Type = switch type {
        case "title-page": "titlepage"
        case "text": "bodymatter"
        case "acknowledgements": "acknowledgments"
        case "notes": "endnotes"
        default: type
        }
        self.init(epubType: asEPUB3Type)
    }
}
