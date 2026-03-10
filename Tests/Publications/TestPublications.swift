//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// Provides access to shared test publication files.
public enum TestPublications {
    /// Returns the resource bundle containing shared test publications.
    public static let bundle = Bundle.module

    /// Returns a URL for the specified publication file.
    ///
    /// - Parameter filename: The filename with extension (e.g., "childrens-literature.epub").
    /// - Returns: A URL pointing to the publication file.
    public static func url(for filename: String) -> URL {
        let components = filename.split(separator: ".", maxSplits: 1)
        let name = String(components[0])
        let ext = components.count > 1 ? String(components[1]) : nil

        guard let url = bundle.url(forResource: name, withExtension: ext, subdirectory: "Publications") else {
            fatalError("Test publication '\(filename)' not found in TestPublications bundle")
        }

        return url
    }
}
