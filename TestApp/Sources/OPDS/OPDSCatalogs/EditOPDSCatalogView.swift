import SwiftUI

struct EditOPDSCatalogView: View {
    @State var catalog: OPDSCatalog
    var onSave: (OPDSCatalog) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showErrorAlert = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var urlString: String
    @State private var selectedSymbol: OPDSCatalogSymbol

    
    init(catalog: OPDSCatalog, onSave: @escaping (OPDSCatalog) -> Void) {
        self._catalog = State(initialValue: catalog)
        self.onSave = onSave
        self._urlString = State(initialValue: catalog.url.absoluteString)
        self._selectedSymbol = State(initialValue: catalog.symbol)

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
                
                Section(header: Text("Icon")) {
                    Picker(
                        "Choose icon",
                        selection: $selectedSymbol
                    ) {
                        ForEach(OPDSCatalogSymbol.allCases) { symbol in
                            Image(systemName: symbol.rawValue)
                                .tag(symbol)
                        }
                    }
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
            catalog.symbol = selectedSymbol
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
            url: URL(string: "https://test.opds.io/2.0/home.json")!,
            symbol: .booksVerticalFill
        ),
        onSave: { _ in }
    )
}
