import SwiftUI

struct EditOPDSCatalogView: View {
    @State var catalog: OPDSCatalog
    var onSave: (OPDSCatalog) -> Void
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("opds_add_title")
                ) {
                    TextField("Title", text: $catalog.title)
                    TextField("URL", text: Binding(
                        get: { catalog.url.absoluteString },
                        set: { catalog.url = URL(string: $0) ?? catalog.url }
                    ))
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
                    onSave(catalog)
                    presentationMode.wrappedValue.dismiss()
                }
            )
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
