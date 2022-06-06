//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AddBookSheet: View {
    
    // For iOS 15, we can use @Environment(\.dismiss)
    @Binding var showingSheet: Bool
    var action: (String) -> Void
    
    @State var url: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                // FIXME better looking buttons here, or move to toolbar within sheet
                Button("Add") {
                    action(url)
                }
                Button("Cancel") {
                    showingSheet = false
                }
            }
            .navigationBarTitle("Add a Book")
        }
    }
}

//struct AddBookSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        AddBookSheet(showingSheet: true)
//    }
//}
