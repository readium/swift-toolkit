//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI

struct NewReaderViewController: UIViewControllerRepresentable {
    let makeReaderVCFunc: () -> UIViewController

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    func makeUIViewController(context: Context) -> UIViewController {
        makeReaderVCFunc()
    }
}
