//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// A SwiftUI wrapper for the UIKit OPDSPublicationInfoViewController.
struct OPDSPublicationInfoView: UIViewControllerRepresentable {
    let publication: Publication

    func makeUIViewController(context: Context) -> OPDSPublicationInfoViewController {
        OPDSFactory.shared.make(publication: publication)
    }

    func updateUIViewController(_ uiViewController: OPDSPublicationInfoViewController, context: Context) {}
}
