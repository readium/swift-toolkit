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
        // We only transform reflowable HTML resources.
        guard
            resource.link.mediaType?.isHTML == true,
            metadata.presentation.layout(of: resource.link) == .reflowable else
        {
            return resource
        }

        return resource.mapAsString { [metadata] content in
            guard let document = try? XMLDocument(string: content) else {
                return content
            }

            var content = content
            let language = metadata.languages.first ?? document.root?.attr("lang")
            let contentLayout = metadata.contentLayout(forLanguage: language)

            // User properties injection
            if let htmlStart = content.endIndex(of: "<html") {
                let style = #" style="\(userProperties.css)""#
                content = content.insert(string: style, at: htmlStart)
            }
    
            // RTL dir attributes injection
            if case .rtl = contentLayout.readingProgression {
                // We need to add the dir="rtl" attribute on <html> and <body> if not already present.
                // https://readium.org/readium-css/docs/CSS03-injection_and_pagination.html#right-to-left-progression
                func addRTLDir(to tagName: String, in html: String) -> String {
                    guard let tagRange = html.range(of: "<\(tagName).*>", options: [.regularExpression, .caseInsensitive]),
                        // Checks if the dir= attribute already exists, in which case we don't add it again otherwise the WebView reports an error.
                        String(html[tagRange]).range(of: "dir=", options: [.regularExpression, .caseInsensitive]) == nil,
                        let tagStart = html.endIndex(of: "<\(tagName)") else
                    {
                        return html
                    }
                    return html.insert(string: #" dir="rtl""#, at: tagStart)
                }
    
                content = addRTLDir(to: "html", in: content)
                content = addRTLDir(to: "body", in: content)
            }

            if let headStart = content.endIndex(of: "<head>") {
                let viewport = #"<meta name="viewport" content="width=device-width, height=device-height, initial-scale=1.0;"/>"#
                content = content.insert(string: viewport, at: headStart)

                if let headEnd = content.startIndex(of: "</head>") {
                    let openDyslexicStyle = #"<style type="text/css">@font-face{font-family: "OpenDyslexic"; src:url("/fonts/OpenDyslexic-Regular.otf") format("opentype");}</style>"#
                    content = content.insert(string: openDyslexicStyle, at: headEnd)
                }
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
