//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

extension URL {
    init?(path: String) {
        guard let path = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        self.init(percentEncodedString: path)
    }

    init?(percentEncodedString: String) {
        if #available(iOS 17.0, *) {
            self.init(string: percentEncodedString, encodingInvalidCharacters: false)
        } else {
            self.init(string: percentEncodedString)
        }
    }

    func copy(_ changes: (inout URLComponents) -> Void) -> URL? {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return nil
        }
        changes(&components)
        return components.url
    }
}
