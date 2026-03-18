//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

/// Full metadata display for a publication.
struct PublicationMetadataView: View {
    let metadata: PublicationMetadata

    var body: some View {
        List {
            aboutSection
            technicalSection
            descriptionSection
        }
        .navigationTitle("Metadata")
    }

    /// Human-readable bibliographic information: title, contributors, dates,
    /// language, etc.
    private var aboutSection: some View {
        Section("About") {
            if let title = metadata.title {
                LabeledContent("Title", value: title)
            }

            if let subtitle = metadata.subtitle {
                LabeledContent("Subtitle", value: subtitle)
            }

            if !metadata.contributors.authors.isEmpty {
                LabeledContent("Author", value: metadata.contributors.authors.joined(separator: ", "))
            }

            if !metadata.contributors.publishers.isEmpty {
                LabeledContent("Publisher", value: metadata.contributors.publishers.joined(separator: ", "))
            }

            if let published = metadata.published {
                LabeledContent("Published", value: published.formatted(date: .long, time: .omitted))
            }

            if let modified = metadata.modified {
                LabeledContent("Modified", value: modified.formatted(date: .long, time: .omitted))
            }

            if let language = metadata.language {
                // localizedDescription() is a convenience API from Readium that
                // will display the name of the language in the system language.
                LabeledContent("Language", value: language.localizedDescription())
            }

            if let pages = metadata.numberOfPages {
                LabeledContent("Pages", value: "\(pages)")
            }

            if let duration = metadata.duration?.formatted() {
                LabeledContent("Duration", value: duration)
            }

            if !metadata.subjects.isEmpty {
                LabeledContent("Subjects", value: metadata.subjects.joined(separator: ", "))
            }

            if !metadata.series.isEmpty {
                LabeledContent("Series", value: metadata.series.joined(separator: ", "))
            }

            if !metadata.collections.isEmpty {
                LabeledContent("Collections", value: metadata.collections.joined(separator: ", "))
            }

            NavigationLink("Contributors") {
                contributorsDetailView
            }
        }
    }

    private var technicalSection: some View {
        Section("Technical") {
            if let identifier = metadata.identifier {
                LabeledContent("Identifier", value: identifier)
            }

            ForEach(metadata.profiles, id: \.self) { profile in
                LabeledContent("Profile", value: profile.uri)
            }

            if let layout = metadata.layout {
                LabeledContent("Layout", value: layout.rawValue)
            }
        }
    }

    /// The publication's description/synopsis, if present.
    ///
    /// The `description` field may contain HTML markup (e.g. `<b>`, `<i>`,
    /// `<p>`). `HTMLText` parses it into an `AttributedString` for rich
    /// rendering.
    @ViewBuilder private var descriptionSection: some View {
        if let description = metadata.description {
            Section("Description") {
                HTMLText(description)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Contributors Detail

    /// Drill-down view listing every contributor grouped by role.
    private var contributorsDetailView: some View {
        List {
            contributorSection(of: "Authors", with: metadata.contributors.authors)
            contributorSection(of: "Translators", with: metadata.contributors.translators)
            contributorSection(of: "Editors", with: metadata.contributors.editors)
            contributorSection(of: "Artists", with: metadata.contributors.artists)
            contributorSection(of: "Illustrators", with: metadata.contributors.illustrators)
            contributorSection(of: "Letterers", with: metadata.contributors.letterers)
            contributorSection(of: "Pencilers", with: metadata.contributors.pencilers)
            contributorSection(of: "Colorists", with: metadata.contributors.colorists)
            contributorSection(of: "Inkers", with: metadata.contributors.inkers)
            contributorSection(of: "Narrators", with: metadata.contributors.narrators)
            contributorSection(of: "Contributors", with: metadata.contributors.contributors)
            contributorSection(of: "Publishers", with: metadata.contributors.publishers)
            contributorSection(of: "Imprints", with: metadata.contributors.imprints)
        }
        .navigationTitle("Contributors")
    }

    /// Renders a titled section for one contributor role.
    @ViewBuilder private func contributorSection(of role: String, with names: [String]) -> some View {
        if !names.isEmpty {
            Section(role) {
                ForEach(names, id: \.self) { name in
                    Text(name)
                }
            }
        }
    }
}
