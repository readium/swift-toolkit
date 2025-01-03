//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI

struct EditOPDSCatalogView: View {
    @State var catalog: OPDSCatalog
    var onSave: (OPDSCatalog) -> Void

    @Environment(\.presentationMode) var presentationMode

    @State private var showErrorAlert = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var urlString: String

    init(
        catalog: OPDSCatalog,
        onSave: @escaping (OPDSCatalog) -> Void
    ) {
        self.catalog = catalog
        self.onSave = onSave
        urlString = catalog.url.absoluteString
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("opds_add_title")) {
                    TextField("Title", text: $catalog.title)
                    TextField("URL", text: $urlString)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    validateAndSave()
                }
            )
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text(errorTitle),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }

    private func validateAndSave() {
        let trimmedTitle = catalog.title.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTitle.isEmpty {
            errorTitle = "Title Required"
            errorMessage = "Please enter a title."
            showErrorAlert = true
            return
        }

        if
            let url = URL(string: urlString),
            url.scheme != nil,
            url.host != nil
        {
            catalog.url = url
            onSave(catalog)
            presentationMode.wrappedValue.dismiss()
        } else {
            errorTitle = "Invalid URL"
            errorMessage = "Please enter a valid URL."
            showErrorAlert = true
        }
    }
}

#Preview {
    EditOPDSCatalogView(
        catalog: OPDSCatalog(
            id: UUID().uuidString,
            title: "OPDS 2.0 Test Catalog",
            url: URL(string: "https://test.opds.io/2.0/home.json")!
        ),
        onSave: { _ in }
    )
}
