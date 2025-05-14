//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension InputObservable {
    func setupLegacyInputCallbacks(
        onTap: @MainActor @escaping (CGPoint) -> Void,
        onPressKey: @MainActor @escaping (KeyEvent) -> Void,
        onReleaseKey: @MainActor @escaping (KeyEvent) -> Void
    ) {
        addObserver(.activate { event in
            onTap(event.location)
            return false
        })

        addObserver(.key { event in
            switch event.phase {
            case .down:
                onPressKey(event)
            case .up:
                onReleaseKey(event)
            case .change, .cancel:
                break
            }
            return false
        })
    }
}
