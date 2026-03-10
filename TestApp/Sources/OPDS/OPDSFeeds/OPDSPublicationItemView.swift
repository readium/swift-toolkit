//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSPublicationItemView: View {
    let publication: Publication

    private let coverHeight: CGFloat = 200
    private let coverWidth: CGFloat = 140

    private var imageURL: URL? {
        let primaryURL = publication.coverLink?.url(relativeTo: publication.baseURL).httpURL?.url

        let fallbackURL = publication.images.first?.url(relativeTo: publication.baseURL).httpURL?.url

        return primaryURL ?? fallbackURL
    }

    var body: some View {
        VStack(alignment: .leading) {
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color.gray.opacity(0.3)
                    .overlay(Image(systemName: "book.closed"))
            }
            .frame(width: coverWidth, height: coverHeight)
            .clipped()

            Text(publication.metadata.title ?? "")
                .font(.caption)
                .lineLimit(2)

            Text(publication.metadata.authors.map(\.name).joined(separator: ", "))
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: coverWidth)
    }
}

private extension Publication {
    /// Finds the first link with `cover` or thumbnail relations.
    var coverLink: ReadiumShared.Link? {
        links.firstWithRel(.cover)
            ?? links.firstWithRel("http://opds-ps.org/image")
            ?? links.firstWithRel("http://opds-ps.org/image/thumbnail")
    }
}
