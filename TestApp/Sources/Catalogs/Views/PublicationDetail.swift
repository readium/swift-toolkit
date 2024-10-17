//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// Screen of the publication detail, last in the stack
struct PublicationDetail: View {
    @State var opdsPublication: OPDSPublication

    var body: some View {
        let authors = opdsPublication.authors
            .map(\.name)
            .joined(separator: ", ")
        ScrollView {
            VStack {
                AsyncImage(
                    url: opdsPublication.images.first
                        .map { URL(string: $0.href)! },
                    content: { $0
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 225, height: 330)
                    },
                    placeholder: { ProgressView() }
                )
                Text(opdsPublication.title ?? "").font(.title)
                Text(authors).font(.title3)
                    .padding([.top], 5)
                Text(opdsPublication.description ?? "")
                    .padding([.top, .bottom], 20)
                    .frame(alignment: .leading)
            }
        }
        .padding()
        .toolbar(content: toolbarContent)
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(.download) {
                // TODO: download the publication
            }
        }
    }
}

// struct PublicationDetail_Previews: PreviewProvider {
//    static var previews: some View {
//        PublicationDetail()
//    }
// }
