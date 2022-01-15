//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct HighlightContextMenu: View {
    let colors: [HighlightColor]
    let colorSelectedHandler: (HighlightColor) -> Void
    let deleteSelectedHandler: () -> Void
    
    var body: some View {
        HStack {
            Button {
                colorSelectedHandler(1)
            } label: {
                Circle().fill(Color.red)
            }
            
            Button {
                colorSelectedHandler(2)
            } label: {
                Circle().fill(Color.green)
                    .font(.system(size: 16))
            }
            
            Button {
                colorSelectedHandler(3)
            } label: {
                Circle().fill(Color.blue)
                    .font(.system(size: 16))
            }

            
//            Circle().fill(Color.yellow)
            Button {
                deleteSelectedHandler()
            } label: {
                Image(systemName: "xmark.bin")
                    .font(.system(size: 16))
            }
            
        }
//        .background(Color.gray)
    }
}
