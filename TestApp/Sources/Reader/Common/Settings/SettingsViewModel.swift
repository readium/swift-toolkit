//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import R2Navigator
import R2Shared
import SwiftUI

final class SettingsViewModel: ObservableObject {
    
    @Published private(set) var settings = PresentationController.Settings()
    
    private let presentation: PresentationController
    private var subscriptions: [Cancellable] = []
    
    init(presentation: PresentationController) {
        self.presentation = presentation
        
        presentation.settings
            .assign(to: \.settings, on: self)
            .store(in: &subscriptions)
    }
    
    func commit(changes: (PresentationController, PresentationController.Settings) -> Void) {
        presentation.commit(changes: changes)
    }
}
