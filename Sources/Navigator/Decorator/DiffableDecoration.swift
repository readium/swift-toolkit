//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import DifferenceKit
import Foundation
import ReadiumShared

struct DiffableDecoration: Hashable, Differentiable {
    let decoration: Decoration
    var differenceIdentifier: Decoration.Id { decoration.id }
}

enum DecorationChange {
    case add(Decoration)
    case remove(Decoration.Id)
    case update(Decoration)
}

extension Array where Element == DiffableDecoration {
    func changesByHREF(from source: [DiffableDecoration]) -> [AnyURL: [DecorationChange]] {
        let changeset = StagedChangeset(source: source, target: self)

        var changes: [AnyURL: [DecorationChange]] = [:]

        func register(_ change: DecorationChange, at locator: Locator) {
            var resourceChanges: [DecorationChange] = changes[locator.href] ?? []
            resourceChanges.append(change)
            changes[locator.href] = resourceChanges
        }

        for change in changeset {
            for deleted in change.elementDeleted {
                let decoration = source[deleted.element].decoration
                register(.remove(decoration.id), at: decoration.locator)
            }
            for inserted in change.elementInserted {
                let decoration = self[inserted.element].decoration
                register(.add(decoration), at: decoration.locator)
            }
            for updated in change.elementUpdated {
                let decoration = self[updated.element].decoration
                register(.update(decoration), at: decoration.locator)
            }
        }

        return changes
    }
}
