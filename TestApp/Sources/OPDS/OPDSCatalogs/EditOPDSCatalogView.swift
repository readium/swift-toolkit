import SwiftUI

struct EditOPDSCatalogView: View {
    @Binding var catalog: OPDSCatalog
    
    var body: some View {
        Text("Hello, World!")
    }
}

private struct Wrapper: View {
    @State private var catalog = OPDSCatalog(
        id: UUID().uuidString,
        title: "OPDS 2.0 Test Catalog",
        url: URL(string: "https://test.opds.io/2.0/home.json")!
    )
    
    var body: some View {
        EditOPDSCatalogView(catalog: $catalog)
    }
}

#Preview {
    Wrapper()
}
