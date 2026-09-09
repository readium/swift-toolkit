//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import ReadiumShared

struct DiffableDecoration: Hashable {
    let decoration: Decoration
}

enum DecorationChange {
    case add(Decoration)
    case remove(Decoration.Id)
    case update(Decoration)
}

extension Array where Element == DiffableDecoration {
    func changesByHREF(from source: [DiffableDecoration]) -> [AnyURL: [DecorationChange]] {
        var changes: [AnyURL: [DecorationChange]] = [:]

        func register(_ change: DecorationChange, at locator: Locator) {
            changes[locator.href, default: []].append(change)
        }

        let sourceById = Dictionary(source.map { ($0.decoration.id, $0) }, uniquingKeysWith: { first, _ in first })
        let targetById = Dictionary(map { ($0.decoration.id, $0) }, uniquingKeysWith: { first, _ in first })

        for sourceElement in source {
            let id = sourceElement.decoration.id
            if let targetElement = targetById[id] {
                if sourceElement != targetElement {
                    register(.update(targetElement.decoration), at: targetElement.decoration.locator)
                }
            } else {
                register(.remove(id), at: sourceElement.decoration.locator)
            }
        }

        for targetElement in self {
            if sourceById[targetElement.decoration.id] == nil {
                register(.add(targetElement.decoration), at: targetElement.decoration.locator)
            }
        }

        return changes
    }
}
