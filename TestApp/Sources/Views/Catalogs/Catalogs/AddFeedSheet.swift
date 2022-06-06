//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AddFeedSheet: View {
    
    // For iOS 15, we can use @Environment(\.dismiss)
    @Binding var showingSheet: Bool
    var action: (String, String) -> Void
    
    @State var title: String = ""
    @State var url: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Feed Title", text: $title)
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                // FIXME better looking buttons here, or move to toolbar within sheet
                Button("Add") {
                    action(title, url)
                }
                Button("Cancel") {
                    showingSheet = false
                }
            }
            .navigationBarTitle("Add an OPDS Feed")
        }
    }
}

//struct AddFeedSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        AddFeedSheet()
//    }
//}
