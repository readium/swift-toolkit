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
                Section {
                    TextField("Feed Title", text: $title)
                    TextField("URL", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            .navigationBarTitle("Add an OPDS Feed")
            .toolbar(content: toolbarContent)
        }
    }
    
    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            CancelButton {
                showingSheet = false
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            SaveButton {
                action(title, url)
                showingSheet = false
            }
            .disabled(title.isEmpty || url.isEmpty)
        }
    }
}

//struct AddFeedSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        AddFeedSheet()
//    }
//}
