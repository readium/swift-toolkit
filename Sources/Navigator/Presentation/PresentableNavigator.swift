//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Shared

/// A navigator supporting observation and/or customization of its presentation properties.
public protocol PresentableNavigator: Navigator {
    
    /// Current values for the Presentation Properties and their metadata.
    var presentation: ObservableVariable<Presentation> { get }
    
    /// Submits a new set of Presentation Settings used by the Navigator to recompute its
    /// Presentation Properties.
    ///
    /// Note that the Navigator might not update its presentation right away, or might even ignore
    /// some of the provided settings. They are only used as guidelines to compute the Presentation
    /// Properties.
    func apply(presentationSettings: PresentationValues)
}
