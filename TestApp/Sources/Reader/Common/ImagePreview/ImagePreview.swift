//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// A bitmap image preview.
///
/// Displays the image and basic metadata (href, caption) to demonstrate
/// the Readium `PointerEvent.targetElement` API.
struct ImagePreview: View {
    let publication: Publication
    let image: ImageContentElement

    /// Called when the user selects an extended description link, to close the
    /// preview and navigate to it in the reader.
    let onSelectLink: (ReadiumShared.Link) -> Void

    @State private var uiImage: UIImage?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("HREF") {
                        Text(image.embeddedLink.href)
                    }

                    if let caption = image.caption {
                        LabeledContent("Caption") {
                            Text(caption)
                        }
                    }

                    if let accessibleName = image.accessibleName {
                        LabeledContent("Accessible Name") {
                            Text(accessibleName)
                        }
                    }

                    if let accessibleDescription = image.accessibleDescription {
                        LabeledContent("Accessible Description") {
                            Text(accessibleDescription)
                        }
                    }
                }

                let extendedDescriptions = image.extendedDescriptions
                if !extendedDescriptions.isEmpty {
                    Section("Extended Descriptions") {
                        ForEach(extendedDescriptions, id: \.self) { link in
                            Button {
                                onSelectLink(link)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(link.title ?? "Extended description")
                                    Text(link.href)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            let link = image.embeddedLink
            if
                let resource = publication.get(link),
                let data = try? await resource.read().get()
            {
                uiImage = UIImage(data: data)
            }
        }
    }
}
