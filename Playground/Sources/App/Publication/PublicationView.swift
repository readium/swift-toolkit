//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// Detail view that opens a publication file.
struct PublicationView: View {
    /// The publication file to open.
    let file: URL

    /// The opened publication, set after `load()` completes successfully.
    @State private var publication: Publication?

    /// The publication's cover image, fetched after `publication` is set.
    @State private var cover: UIImage?

    /// Holds the last loading error.
    @State private var error: UserError?

    var body: some View {
        NavigationStack {
            Group {
                if let publication {
                    List {
                        coverSection

                        NavigationLink("Metadata") {
                            PublicationMetadataView(metadata: readMetadata(of: publication))
                        }

                        NavigationLink("JSON Manifest") {
                            JSONView(json: publication.manifest.jsonObject)
                                .navigationTitle("JSON Manifest")
                        }
                    }
                    .listStyle(.insetGrouped)
                } else if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text(error.message)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(publication?.metadata.title ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .alert(error: $error)
            .task {
                await load()
            }
        }
    }

    /// Opens the publication file and fetches its cover image.
    ///
    /// - `file.fileURL` is a safety guard: `DocumentRepository` always vends `file://`
    ///   URLs, but the check future-proofs against changes to that assumption.
    private func load() async {
        do {
            guard let url = file.anyURL.absoluteURL else {
                error = UserError("Not a valid absolute URL")
                return
            }
            let result = try await openPublication(at: url)
            publication = result.publication
            cover = try? await result.publication.cover().get()
        } catch {
            self.error = UserError(error)
        }
    }

    /// Renders the cover image in a full-width card.
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
