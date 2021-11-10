//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation

/// A navigator supporting observation and/or customization of its presentation properties.
public protocol PresentableNavigator {
    
    /// Current values for the Presentation Properties and their metadata.
    var presentation: Presentation { get }

    func observePresentation(onChanged: @escaping OnPresentationChangedCallback)
    
    /// Submits a new set of Presentation Settings used by the Navigator to recompute its
    /// Presentation Properties.
    ///
    /// Note that the Navigator might not update its presentation right away, or might even ignore
    /// some of the provided settings. They are only used as guidelines to compute the Presentation
    /// Properties.
    func apply(presentationSettings: PresentationValues, completion: @escaping (Presentation) -> ())

    typealias OnPresentationChangedCallback = (_ presentation: Presentation) -> Void
}
