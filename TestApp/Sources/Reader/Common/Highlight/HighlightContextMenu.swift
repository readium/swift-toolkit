//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct HighlightContextMenu: View {
    var body: some View {
        HStack {
            Button {
                
            } label: {
                Circle().fill(Color.red)
            }
            
            Button {
                
            } label: {
                Circle().fill(Color.green)
            }
            
            Button {
                
            } label: {
                Circle().fill(Color.blue)
            }

            
//            Circle().fill(Color.yellow)
            Image(systemName: "xmark.bin")
        }
    }
}
