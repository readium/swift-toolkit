//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

public extension InputObserving where Self == KeyObserver {
    /// Recognizes any key press.
    ///
    /// Inspect the provided ``KeyEvent`` to know which keys were pressed.
    static func key(
        onKey: @MainActor @escaping (KeyEvent) async -> Bool
    ) -> KeyObserver {
        KeyObserver(onKey: onKey)
    }

    /// Recognizes a key combination pressed (e.g. A or Cmd+B).
    static func key(
        _ key: Key,
        _ modifiers: KeyModifiers = [],
        onKey: @MainActor @escaping () async -> Bool
    ) -> KeyObserver {
        KeyObserver(key: key, modifiers: modifiers, onKey: onKey)
    }
}

/// An input observer used to recognize a single key combination pressed.
@MainActor public final class KeyObserver: InputObserving {
    private typealias KeyCombo = (KeyModifiers, Key)

    private let keyCombo: KeyCombo?
    private let onKey: @MainActor (KeyEvent) async -> Bool

    public init(
        key: Key,
        modifiers: KeyModifiers,
        onKey: @MainActor @escaping () async -> Bool
    ) {
        keyCombo = (modifiers, key)
        self.onKey = { _ in await onKey() }
    }

    public init(
        onKey: @MainActor @escaping (KeyEvent) async -> Bool
    ) {
        keyCombo = nil
        self.onKey = onKey
    }

    public func didReceive(_ event: PointerEvent) async -> Bool {
        false
    }

    public func didReceive(_ event: KeyEvent) async -> Bool {
        guard event.phase == .down else {
            return false
        }
        if let (modifiers, key) = keyCombo {
            guard
                event.key == key,
                event.modifiers == modifiers
            else {
                return false
            }
        }

        return await onKey(event)
    }
}
