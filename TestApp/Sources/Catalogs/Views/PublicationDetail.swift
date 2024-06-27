//
//  Copyright 2024 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct PublicationDetail: View {
    @State var publication: Publication

    var body: some View {
        let authors = publication.metadata.authors
            .map(\.name)
            .joined(separator: ", ")
        ScrollView {
            VStack {
                AsyncImage(
                    url: publication.images.first
                        .map { URL(string: $0.href)! },
                    content: { $0
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 225, height: 330)
                    },
                    placeholder: { ProgressView() }
                )
                Text(publication.metadata.title ?? "").font(.largeTitle)
                Text(authors).font(.title2)
                Text(publication.metadata.description ?? "")
                    .padding([.top, .bottom], 20)
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
