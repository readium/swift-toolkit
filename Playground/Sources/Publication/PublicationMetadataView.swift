//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct PublicationMetadataView: View {
    let publication: Publication

    private var metadata: Metadata {
        publication.metadata
    }

    var body: some View {
        List {
            metadataSection(for: publication)
        }
        .navigationTitle("Metadata")
    }

    @ViewBuilder private func metadataSection(for publication: Publication) -> some View {
        Section("About") {
            if let title = metadata.title {
                LabeledContent("Title", value: title)
            }

            if let subtitle = metadata.subtitle {
                LabeledContent("Subtitle", value: subtitle)
            }

            if let authors = formatContributors(metadata.authors) {
                LabeledContent("Author", value: authors)
            }

            if let publishers = formatContributors(metadata.publishers) {
                LabeledContent("Publisher", value: publishers)
            }

            if let published = formatDate(metadata.published) {
                LabeledContent("Published", value: published)
            }

            if let modified = formatDate(metadata.modified) {
                LabeledContent("Modified", value: modified)
            }

            if let languages = formatLanguages(metadata.languages) {
                LabeledContent("Language", value: languages)
            }

            if let pages = metadata.numberOfPages {
                LabeledContent("Pages", value: "\(pages)")
            }

            if let duration = metadata.duration?.formatted(.time) {
                LabeledContent("Duration", value: duration)
            }

            if let subjects = formatSubjects(metadata.subjects) {
                LabeledContent("Subjects", value: subjects)
            }

            if let series = formatCollections(metadata.belongsToSeries) {
                LabeledContent("Series", value: series)
            }

            if let collections = formatCollections(metadata.belongsToCollections) {
                LabeledContent("Collection", value: collections)
            }

            NavigationLink("Contributors") {
                contributorsList
            }
        }

        Section("Technical") {
            if let identifier = metadata.identifier {
                LabeledContent("Identifier", value: identifier)
            }

            ForEach(publication.manifest.metadata.conformsTo, id: \.self) { profile in
                LabeledContent("Profile", value: profile.uri)
            }

            if let layout = metadata.layout {
                LabeledContent("Layout", value: layout.rawValue)
            }
        }

        if let description = metadata.description {
            Section("Description") {
                // The description may contain HTML tags.
                HTMLText(description)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func formatDate(_ date: Date?) -> String? {
        guard let date else {
            return nil
        }
        return date.formatted(date: .long, time: .omitted)
    }

    private func formatLanguages(_ languages: [String]) -> String? {
        guard !languages.isEmpty else {
            return nil
        }

        return languages
            .map { Language(code: .bcp47($0)).localizedDescription() }
            .joined(separator: ", ")
    }

    private func formatSubjects(_ subjects: [Subject]) -> String? {
        guard !subjects.isEmpty else {
            return nil
        }

        return subjects
            .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }
            .map(\.name)
            .joined(separator: ", ")
    }

    private func formatContributors(_ contributors: [Contributor]) -> String? {
        guard !contributors.isEmpty else {
            return nil
        }

        return contributors
            .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }
            .map(\.name)
            .joined(separator: ", ")
    }

    private func formatCollections(_ collections: [Metadata.Collection]) -> String? {
        guard !collections.isEmpty else {
            return nil
        }

        return collections
            .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }
            .map { formatCollection($0) }
            .joined(separator: ", ")
    }

    private func formatCollection(_ collection: Metadata.Collection) -> String {
        var string = collection.name
        if let position = collection.position {
            string += " (\(position.formatted(.number)))"
        }
        return string
    }

    private var contributorsList: some View {
        List {
            contributorsList(of: "Authors", with: metadata.authors)
            contributorsList(of: "Translators", with: metadata.translators)
            contributorsList(of: "Editors", with: metadata.editors)
            contributorsList(of: "Artists", with: metadata.artists)
            contributorsList(of: "Illustrators", with: metadata.illustrators)
            contributorsList(of: "Letterers", with: metadata.letterers)
            contributorsList(of: "Pencilers", with: metadata.pencilers)
            contributorsList(of: "Colorists", with: metadata.colorists)
            contributorsList(of: "Inkers", with: metadata.inkers)
            contributorsList(of: "Narrators", with: metadata.narrators)
            contributorsList(of: "Contributors", with: metadata.contributors)
            contributorsList(of: "Publishers", with: metadata.publishers)
            contributorsList(of: "Imprints", with: metadata.imprints)
        }
        .navigationTitle("Contributors")
    }

    @ViewBuilder private func contributorsList(of role: String, with contributors: [Contributor]) -> some View {
        if !contributors.isEmpty {
            let contributors = contributors
                .sorted { ($0.sortAs ?? $0.name) < ($1.sortAs ?? $1.name) }

            Section(role) {
                ForEach(contributors, id: \.self) { contributor in
                    Text(contributor.name)
                }
            }
        }
    }
}
