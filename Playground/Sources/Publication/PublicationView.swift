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
                        coverSection

                        NavigationLink("Metadata") {
                            PublicationMetadataView(publication: publication)
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(publication?.metadata.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await load()
            }
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

    @ViewBuilder private var coverSection: some View {
        if let cover {
            Section {
                Image(uiImage: cover)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(4)
                    .shadow(radius: 4)
                    .padding(20)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
        }
    }
}
