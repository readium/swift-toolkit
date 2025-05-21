//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

extension Array where Element == DecorationChange {
    /// Generates the JavaScript used to apply the receiver list of `DecorationChange` in a web view.
    func javascript(forGroup group: String, styles: [Decoration.Style.Id: HTMLDecorationTemplate]) -> String? {
        guard !isEmpty else {
            return nil
        }

        return
            """
            // Using requestAnimationFrame helps to make sure the page is fully laid out before adding the
            // decorations.
            requestAnimationFrame(function () {
                let group = readium.getDecorations('\(group)');
                \(compactMap { $0.javascript(styles: styles) }.joined(separator: "\n"))
            });
            """
    }
}

extension DecorationChange {
    /// Generates the JavaScript used to apply the receiver `DecorationChange` in a web view.
    func javascript(styles: [Decoration.Style.Id: HTMLDecorationTemplate]) -> String? {
        func serializeJSON(of decoration: Decoration) -> String? {
            guard let style = styles[decoration.style.id] else {
                EPUBNavigatorViewController.log(.error, "Decoration style not registered: \(decoration.style.id)")
                return nil
            }
            var json = decoration.json
            json["element"] = style.element(decoration)
            guard let jsonString = serializeJSONString(json) else {
                EPUBNavigatorViewController.log(.error, "Can't serialize decoration to JSON: \(json)")
                return nil
            }
            return jsonString
        }

        switch self {
        case let .add(decoration):
            return serializeJSON(of: decoration)
                .map { "group.add(\($0));" }
        case let .remove(identifier):
            return "group.remove('\(identifier)');"
        case let .update(decoration):
            return serializeJSON(of: decoration)
                .map { "group.update(\($0));" }
        }
    }
}
