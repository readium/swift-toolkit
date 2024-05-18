//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import Fuzi
import ReadiumShared

// FIXME: To remove in Readium 3.0. This was replaced by `ReadiumCSS` in the Navigator.

/// Applies various CSS injections in reflowable EPUB resources.
final class EPUBHTMLInjector {
    private let metadata: Metadata
    private let userProperties: UserProperties

    init(metadata: Metadata, userProperties: UserProperties) {
        self.metadata = metadata
        self.userProperties = userProperties
    }

    func inject(resource: Resource) -> Resource {
        guard
            // Will be empty when the new Settings API is in use.
            !userProperties.properties.isEmpty,
            // We only transform HTML resources.
            resource.link.mediaType.isHTML
        else {
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
                              let tagStart = html.endIndex(of: "<\(tagName)")
                        else {
                            return html
                        }
                        return html.insert(string: #" dir="rtl""#, at: tagStart)
                    }

                    content = addRTLDir(to: "html", in: content)
                    content = addRTLDir(to: "body", in: content)
                }
            }

            if isReflowable, let headStart = content.endIndex(of: "<head>") {
                // FIXME: Readium 3.0 OpenDyslexic should be handled in the navigator.
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
