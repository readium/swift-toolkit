//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct PublicationView: View {
    let file: URL

    @State private var publication: Publication?
    @State private var cover: UIImage?
    @State private var error: UserError?

    var body: some View {
        NavigationStack {
            Group {
                if let publication {
                    List {
                        LabeledContent("Title", value: publication.metadata.title ?? "")

                        LabeledContent("Cover") {
                            if let cover {
                                Image(uiImage: cover)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: 100)
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(file.lastPathComponent)
            .task { await load() }
        }
    }

    private func load() async {
        do throws(UserError) {
            guard let file = file.fileURL else {
                throw UserError("Not a file URL")
            }

            publication = try await Readium.shared.open(file: file.fileURL!)

            cover = try await publication?.cover()
                .mapError(\.userError)
                .get()

        } catch {
            self.error = error
        }
    }
}
