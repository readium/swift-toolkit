//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import Combine
import UIKit
import R2Shared // for UserProperty

// This color scheme is passed to SwiftUI. In the (SwiftUI) future, EnvironmentObject can be injected and updated from UserDefaults in some reactive way.
class ColorScheme {
    private(set) var mainColor: Color = Color.white
    private(set) var textColor: Color = Color.black
    
    func update(with appearance: UserProperty) {
        mainColor = Color(AssociatedColors.getColors(for: appearance).mainColor)
        textColor = Color(AssociatedColors.getColors(for: appearance).textColor)
    }
}

struct ColorModifier: ViewModifier {
    let colorScheme: ColorScheme
    func body(content: Content) -> some View {
        content
            .foregroundColor(colorScheme.textColor)
            .background(colorScheme.mainColor)
    }
}

extension View {
    func colorStyle(_ colorScheme: ColorScheme) -> some View {
        modifier(ColorModifier(colorScheme: colorScheme))
    }
}
