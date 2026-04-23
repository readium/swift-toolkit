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

    @State private var uiImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }

                Text(image.embeddedLink.href)
            }
            .padding()
            .navigationTitle(image.caption ?? "")
            .navigationBarTitleDisplayMode(.inline)
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
