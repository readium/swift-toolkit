import SwiftUI

struct EditOPDSCatalogView: View {
    @State var catalog: OPDSCatalog
    
    var body: some View {
        Text("Hello, World!")
    }
}

#Preview {
    EditOPDSCatalogView(
        catalog: OPDSCatalog(
            id: UUID().uuidString,
            title: "OPDS 2.0 Test Catalog",
            url: URL(string: "https://test.opds.io/2.0/home.json")!
        )
    )
}
