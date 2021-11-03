//
//  EPUBHTMLInjector.swift
//  r2-streamer-swift
//
//  Created by Mickaël Menu, Alexandre Camilleri on 01/06/2020.
//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import R2Shared
import Fuzi

/// Applies various CSS injections in reflowable EPUB resources.
final class EPUBHTMLInjector {
    
    private let metadata: Metadata
    private let userProperties: UserProperties

    init(metadata: Metadata, userProperties: UserProperties) {
        self.metadata = metadata
        self.userProperties = userProperties
    }
    
    func inject(resource: Resource) -> Resource {
        // We only transform HTML resources.
        guard resource.link.mediaType.isHTML else {
            return resource
        }

        let isReflowable = (metadata.presentation.layout(of: resource.link) == .reflowable)

        return resource.mapAsString { [metadata] content in
            var content = content

            if isReflowable {
                // User properties injection
                if let htmlStart = content.endIndex(of: "<html") {
                    let style = #" style="\#(self.userProperties.css)""#
                    content = content.insert(string: style, at: htmlStart)
                }

                // RTL dir attributes injection
                if case .rtl = metadata.effectiveReadingProgression {
                    // We need to add the dir="rtl" attribute on <html> and <body> if not already present.
                    // https://readium.org/readium-css/docs/CSS03-injection_and_pagination.html#right-to-left-progression
                    func addRTLDir(to tagName: String, in html: String) -> String {
                        guard let tagRange = html.range(of: "<\(tagName).*>", options: [.regularExpression, .caseInsensitive]),
                              // Checks if the dir= attribute already exists, in which case we don't add it again otherwise the WebView reports an error.
                              String(html[tagRange]).range(of: "dir=", options: [.regularExpression, .caseInsensitive]) == nil,
                              let tagStart = html.endIndex(of: "<\(tagName)") else {
                            return html
                        }
                        return html.insert(string: #" dir="rtl""#, at: tagStart)
                    }

                    content = addRTLDir(to: "html", in: content)
                    content = addRTLDir(to: "body", in: content)
                }
            }

            if isReflowable, let headStart = content.endIndex(of: "<head>") {
                content = content.insert(string: """
                    <meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0;"/>
                    <style type="text/css">@font-face{font-family: "OpenDyslexic"; src:url("/fonts/OpenDyslexic-Regular.otf") format("opentype");}</style>
                """, at: headStart)
            }
            
            return content
        }

    }

}

private extension UserProperties {
    
    var css: String {
        properties
            .map { p in "\(p.name): \(p.toString())" }
            .joined(separator: "; ")
    }
        
}
