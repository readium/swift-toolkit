//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    var action: (String) -> Void

    @State var url: String = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("URL", text: $url)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
            }
            .navigationTitle("Add a Book")
            .toolbar(content: toolbarContent)
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(.cancel) {
                dismiss()
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(.save) {
                action(url)
                dismiss()
            }
            .disabled(url.isEmpty)
        }
    }
}

// struct AddBookSheet_Previews: PreviewProvider {
//    static var previews: some View {
//        AddBookSheet(showingSheet: true)
//    }
// }
