//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit
import SwiftUI
import ReadiumShared

final class OPDSFacetsViewController: UIHostingController<OPDSFacetsView> {

    init(
        feed: Feed,
        onLinkTap: @escaping (ReadiumShared.Link) -> Void
    ) {
        let view = OPDSFacetsView(feed: feed, onLinkTap: onLinkTap)
        super.init(rootView: view)
    }
    
    @MainActor @preconcurrency required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
