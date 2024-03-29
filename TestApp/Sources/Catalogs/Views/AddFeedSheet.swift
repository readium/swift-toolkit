//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AddFeedSheet: View {
    
    typealias ActionCallback = ((title: String, url: String)) -> Void
    
    // For iOS 15, we can use @Environment(\.dismiss)
    @Binding var showingSheet: Bool
    var action: ActionCallback
    
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
            Button(.cancel) {
                showingSheet = false
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(.save) {
                action((title: title, url: url))
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
