//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

// The `ReadiumInternal` package was removed and its utilities are now internal
// (`package`) to `ReadiumShared`. A few of these helpers used to leak through
// `ReadiumShared`'s public API surface. The declarations below are kept as
// unavailable tombstones so that apps relying on them get a clear migration
// message instead of a cryptic error. The original implementations are kept so
// you can easily copy the helper into your own codebase if you still need it.

public extension Array {
    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func appending(_ newElement: Element) -> Self {
        var array = self
        array.append(newElement)
        return array
    }
}

public extension Result {
    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func get(or def: Success) -> Success {
        (try? get()) ?? def
    }

    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func `catch`(_ recover: (Failure) -> Self) -> Self {
        if case let .failure(error) = self {
            return recover(error)
        }
        return self
    }
}

public extension String {
    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    var sanitizedPathComponent: String {
        // See https://superuser.com/a/358861
        let invalidCharacters = CharacterSet(charactersIn: "\\/:*?\"<>|")
            .union(.newlines)
            .union(.illegalCharacters)
            .union(.controlCharacters)

        return components(separatedBy: invalidCharacters)
            .joined(separator: " ")
    }

    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func addingPrefix(_ prefix: String) -> String {
        if hasPrefix(prefix) {
            return self
        } else {
            return prefix + self
        }
    }

    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func replacingPrefix(_ prefix: String, by replacement: String) -> String {
        guard hasPrefix(prefix) else {
            return self
        }
        return replacement + dropFirst(prefix.count)
    }

    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func substringBeforeLast(_ delimiter: String) -> String? {
        guard let range = range(of: delimiter, options: [.backwards, .literal]) else {
            return self
        }
        return String(self[..<range.lowerBound])
    }
}

public extension Task<Void, Never>? {
    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    mutating func replace(@_implicitSelfCapture with operation: sending @escaping @isolated(any) () async -> Void) {
        self?.cancel()
        self = Task(operation: operation)
    }
}

public extension URL {
    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    mutating func removeFragment() -> String? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        let fragment = components.fragment
        components.fragment = nil
        guard let result = components.url else {
            return nil
        }
        self = result
        return fragment
    }

    @available(*, unavailable, message: "This utility was an internal helper that leaked through ReadiumShared. It is no longer part of the public API. Copy it into your own codebase if you still need it.")
    func removingFragment() -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.fragment = nil
        return components.url
    }
}
