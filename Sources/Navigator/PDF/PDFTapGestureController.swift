//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import PDFKit
import UIKit

/// Since iOS 13, the way to add a properly functioning tap gesture recognizer on a `PDFView`
/// significantly changed. This class handles the setup depending on the current iOS version.
final class PDFTapGestureController: NSObject {
    private let pdfView: PDFView
    private let tapAction: TargetAction
    private var tapRecognizer: UITapGestureRecognizer!

    init(
        pdfView: PDFView,
        touchTypes: [UITouch.TouchType],
        target: AnyObject,
        action: Selector
    ) {
        assert(pdfView.superview != nil, "The PDFView must be in the view hierarchy")

        self.pdfView = pdfView
        tapAction = TargetAction(target: target, action: action)

        super.init()

        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
        tapRecognizer.allowedTouchTypes = touchTypes.map { NSNumber(value: $0.rawValue) }
        tapRecognizer.requiresExclusiveTouchType = true

        // If we add the gesture on the superview on iOS 13, then it will be
        // triggered when taping a link.
        //
        // The delegate will be used to make sure that this recognizer has a
        // lower precedence over the default tap recognizer of the `PDFView`,
        // which is used to handle links.
        tapRecognizer.delegate = self
        pdfView.addGestureRecognizer(tapRecognizer)
    }

    @objc private func didTap(_ gesture: UITapGestureRecognizer) {
        // On iOS 13, the tap to clear text selection is broken by adding the
        // tap recognizer, so we clear it manually.
        guard pdfView.currentSelection == nil else {
            pdfView.clearSelection()
            return
        }

        tapAction.invoke(from: gesture)
    }
}

extension PDFTapGestureController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (otherGestureRecognizer as? UITapGestureRecognizer)?.numberOfTouchesRequired == 1
    }
}
