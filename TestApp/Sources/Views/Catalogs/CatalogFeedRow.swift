//
//  CatalogFeedRow.swift
//  TestApp
//
//  Created by Steven Zeck on 5/23/22.
//

import SwiftUI

struct CatalogFeedRow: View {
    var action: () -> Void = {}
    var title: String
    
    var body: some View {
        Text(title)
            .font(.title3)
        .padding(.vertical, 8)
    }
}

struct CatalogFeedRow_Previews: PreviewProvider {
    static var previews: some View {
        CatalogFeedRow(title: "Test")
    }
}
