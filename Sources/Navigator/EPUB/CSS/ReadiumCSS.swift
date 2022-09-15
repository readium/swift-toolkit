//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

struct ReadiumCSS {
    var layout: CSSLayout = CSSLayout()
    var rsProperties: CSSRSProperties = CSSRSProperties()
    var userProperties: CSSUserProperties = CSSUserProperties()

    /// Injects Readium CSS in the given `html` resource.
    ///
    /// https://github.com/readium/readium-css/blob/develop/docs/CSS06-stylesheets_order.md
    func injectHTML(_ originalHTML: String) -> String {
        var html = originalHTML
        injectStyles(in: &html)
        injectCSSProperties(in: &html)
        injectDir(in: &html)
        injectLang(in: &html)
        return html
    }

    /// Inject the Readium CSS stylesheets and font face declarations.
    private func injectStyles(in html: inout String) {

    }

    private func injectCSSProperties(in html: inout String) {

    }

    private func injectDir(in html: inout String) {

    }

    private func injectLang(in html: inout String) {

    }
}