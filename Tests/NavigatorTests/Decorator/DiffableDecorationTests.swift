//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
@testable import ReadiumNavigator
@testable import ReadiumShared
import Testing

struct DiffableDecorationTests {
    private func makeLocator(href: String) -> Locator {
        Locator(href: AnyURL(string: href)!, mediaType: .html)
    }

    private func makeDecoration(id: String, href: String, style: Decoration.Style) -> Decoration {
        Decoration(id: id, locator: makeLocator(href: href), style: style)
    }

    @Test func changesByHREF() {
        let dec1 = makeDecoration(id: "1", href: "/chapter1.html", style: .highlight(isActive: false))
        let dec2 = makeDecoration(id: "2", href: "/chapter1.html", style: .highlight(isActive: false))
        let dec3 = makeDecoration(id: "3", href: "/chapter2.html", style: .highlight(isActive: false))

        let source = [
            DiffableDecoration(decoration: dec1),
            DiffableDecoration(decoration: dec2),
            DiffableDecoration(decoration: dec3),
        ]

        // Modify dec1 (update), remove dec2, keep dec3, add dec4
        var updatedDec1 = dec1
        updatedDec1.style = .highlight(isActive: true)

        let dec4 = makeDecoration(id: "4", href: "/chapter1.html", style: .underline(isActive: false))
        let dec5 = makeDecoration(id: "5", href: "/chapter3.html", style: .highlight(isActive: false))

        let target = [
            DiffableDecoration(decoration: updatedDec1),
            DiffableDecoration(decoration: dec3),
            DiffableDecoration(decoration: dec4),
            DiffableDecoration(decoration: dec5),
        ]

        let changes = target.changesByHREF(from: source)

        // Verify /chapter1.html
        let ch1 = changes[AnyURL(string: "/chapter1.html")!] ?? []
        #expect(ch1.count == 3)

        var hasUpdate1 = false
        var hasRemove2 = false
        var hasAdd4 = false

        for change in ch1 {
            switch change {
            case let .update(dec):
                if dec.id == "1" { hasUpdate1 = true }
            case let .remove(id):
                if id == "2" { hasRemove2 = true }
            case let .add(dec):
                if dec.id == "4" { hasAdd4 = true }
            }
        }

        #expect(hasUpdate1)
        #expect(hasRemove2)
        #expect(hasAdd4)

        // Verify /chapter2.html has no changes
        #expect(changes[AnyURL(string: "/chapter2.html")!] == nil)

        // Verify /chapter3.html
        let ch3 = changes[AnyURL(string: "/chapter3.html")!] ?? []
        #expect(ch3.count == 1)

        if case let .add(dec) = ch3.first, dec.id == "5" {
            // success
        } else {
            Issue.record("Expected add change for decoration 5")
        }
    }
}
