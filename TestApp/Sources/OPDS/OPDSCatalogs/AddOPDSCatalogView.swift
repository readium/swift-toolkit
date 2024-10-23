import SwiftUI

struct AddOPDSCatalogView: View {
    @Binding var catalog: OPDSCatalog
    
    var body: some View {
        Text("Hello, World!")
    }
}

private struct Wrapper: View {
    @State private var catalog = OPDSCatalog(
        title: "OPDS 2.0 Test Catalog",
        url: URL(string: "https://test.opds.io/2.0/home.json")!
    )
    
    var body: some View {
        AddOPDSCatalogView(catalog: $catalog)
    }
}

#Preview {
    Wrapper()
}
