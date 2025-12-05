//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumFuzi
import ReadiumShared

// FIXME: Extension used until we migrate from ReadiumFuzi to our shared XMLParser API, in the streamer.
extension ReadiumFuzi.XMLDocument {
    func defineNamespace(_ namespace: XMLNamespace) {
        definePrefix(namespace.prefix, forNamespace: namespace.uri)
    }

    func defineNamespaces(_ namespaces: XMLNamespace...) {
        for namespace in namespaces {
            defineNamespace(namespace)
        }
    }
}

extension ReadiumFuzi.XMLElement {
    func attr(_ name: String, namespace: XMLNamespace?) -> String? {
        attr(name, namespace: namespace?.uri)
    }
}
