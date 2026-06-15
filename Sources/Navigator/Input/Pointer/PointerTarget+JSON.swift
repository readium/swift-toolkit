//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared
import UIKit

extension PointerTarget {
    /// Parses a `target` JSON object produced by the navigator scripts.
    ///
    /// - Parameter resourceBaseURL: Publication-relative URL of the resource currently loaded in the web view.
    init?(json: [String: Any], resourceBaseURL: AnyURL?) {
        guard json["type"] as? String == "image" else {
            return nil
        }

        guard let frame = CGRect(json: json["frame"]) else {
            return nil
        }

        guard
            let hrefString = json["href"] as? String,
            !hrefString.isEmpty,
            let href = AnyURL(string: hrefString) ?? AnyURL(legacyHREF: hrefString)
        else {
            return nil
        }

        let resolvedHref = resourceBaseURL?.resolve(href) ?? href

        let caption: String? = {
            guard let caption = json["caption"] as? String else {
                return nil
            }
            let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()

        self = .image(ImagePointerTarget(
            frame: frame,
            href: resolvedHref,
            caption: caption
        ))
    }
}
