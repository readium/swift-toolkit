//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import ReadiumShared
import SwiftUI

struct OPDSFeedView: View {
    @StateObject private var viewModel: OPDSFeedViewModel

    private var delegate: OPDSModuleDelegate?

    @State private var facetNavigationURL: URL?

    struct NavigablePublication: Identifiable, Hashable {
        let id: String
        let publication: ReadiumShared.Publication

        init(publication: ReadiumShared.Publication, index: Int) {
            self.publication = publication
            id = "\(publication.manifest.hashValue)-\(index)"
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }

        static func == (lhs: NavigablePublication, rhs: NavigablePublication) -> Bool {
            lhs.id == rhs.id
        }
    }

    /// Converts publications to NavigablePublications with unique IDs.
    /// Each publication gets an ID in the format: hash-index
    private func makeNavigablePublications(_ publications: [ReadiumShared.Publication]) -> [NavigablePublication] {
        publications.enumerated().map { index, publication in
            NavigablePublication(publication: publication, index: index)
        }
    }

    init(feedURL: URL, delegate: OPDSModuleDelegate?) {
        _viewModel = StateObject(wrappedValue: OPDSFeedViewModel(feedURL: feedURL, delegate: delegate))
        self.delegate = delegate
    }

    var body: some View {
        mainContent
            .navigationTitle(viewModel.feed?.metadata.title ?? "Loading...")
            .navigationBarTitleDisplayMode(.inline) // Keeps title small
            .onAppear {
                if viewModel.feed == nil {
                    viewModel.parseFeed()
                }
            }
            .toolbar {
                buildToolbar()
            }
            .sheet(isPresented: $viewModel.isShowingFacets) {
                buildFacetView()
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { facetNavigationURL != nil },
                    set: { if !$0 { facetNavigationURL = nil } }
                )
            ) {
                facetDestinationView()
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        Group {
            // If the feed is only publications, show a grid.
            if viewModel.isPublicationOnly {
                buildPublicationOnlyView(viewModel.publications)
            } else {
                // Otherwise, show a list view.
                buildListView()
            }
        }
    }

    @ViewBuilder
    private func facetDestinationView() -> some View {
        if let url = facetNavigationURL {
            OPDSFeedView(feedURL: url, delegate: delegate)
        } else {
            EmptyView()
        }
    }

    // MARK: - Toolbar & Sheet Builders

    @ToolbarContentBuilder
    private func buildToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if !(viewModel.feed?.facets.isEmpty ?? true) {
                Button {
                    viewModel.isShowingFacets = true
                } label: {
                    Text(NSLocalizedString("filter_button", comment: "Filter the OPDS feed"))
                }
            }
        }
    }

    @ViewBuilder
    private func buildFacetView() -> some View {
        OPDSFacetView(facets: viewModel.feed?.facets ?? []) { link in
            if let url = URL(string: link.href) {
                facetNavigationURL = url
            }
        }
    }

    // MARK: - List View Builders

    @ViewBuilder
    private func buildListView() -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if viewModel.feed != nil {
                    if !viewModel.navigation.isEmpty {
                        buildNavigationSection(viewModel.navigation)
                    }

                    if !viewModel.groups.isEmpty {
                        buildGroupsSection(viewModel.groups)
                    }

                    if let group = viewModel.rootPublicationsGroup {
                        buildGroupsSection([group])
                    }

                    if !viewModel.hasContent {
                        buildNoneView()
                            .padding()
                    }

                } else if viewModel.error != nil {
                    Text("Failed to load feed. Please try again.")
                        .padding()
                } else {
                    ProgressView()
                        .padding()
                }
            }
        }
    }

    @ViewBuilder
    private func buildNoneView() -> some View {
        if let error = viewModel.error {
            Text("Failed to load feed: \(error.localizedDescription)")
        } else {
            Text("No content in this feed.")
        }
    }

    // MARK: - Publication Grid Builder

    @ViewBuilder
    private func buildPublicationOnlyView(_ publications: [ReadiumShared.Publication]) -> some View {
        let columns = [
            GridItem(.adaptive(minimum: 140), spacing: 16),
        ]
        let navPublications = makeNavigablePublications(publications)

        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(navPublications) { navPublication in
                    NavigationLink(value: navPublication) {
                        OPDSPublicationItemView(publication: navPublication.publication)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if navPublication == navPublications.last {
                            viewModel.loadNextPage()
                        }
                    }
                }
            }
            .padding()

            if viewModel.isLoadingNextPage {
                ProgressView()
                    .padding()
            }
        }
    }

    // MARK: - Section Builders

    @ViewBuilder
    private func buildNavigationSection(_ navigation: [ReadiumShared.Link]) -> some View {
        HStack {
            Text(NSLocalizedString("opds_browse_title", comment: "Title of the section displaying the feeds"))
                .font(.title3.bold())
                .textCase(nil)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 16)
        .padding(.bottom, 8)

        Divider()
            .padding(.horizontal)

        buildNavigationList(navigation, isRootList: true)
    }

    @ViewBuilder
    private func buildGroupsSection(_ groups: [ReadiumShared.Group]) -> some View {
        ForEach(Array(groups.enumerated()), id: \.element.metadata.title) { _, group in
            HStack {
                Text(group.metadata.title)
                    .font(.title3.bold())
                    .textCase(nil)

                Spacer()

                if let moreLink = group.links.first, let url = URL(string: moreLink.href) {
                    NavigationLink(value: url) {
                        Text(NSLocalizedString("opds_more_button", comment: "Button to expand a feed gallery"))
                            .font(.title3.bold())
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 32)
            .padding(.bottom, 8)

            if !group.publications.isEmpty {
                let navPublications = makeNavigablePublications(group.publications)

                OPDSGroupRow(
                    group: group,
                    publications: navPublications,
                    isLoading: viewModel.isLoadingNextPage,
                    onLastItemAppeared: {
                        viewModel.loadNextPage()
                    }
                )
            } else if !group.navigation.isEmpty {
                Divider()
                    .padding(.horizontal)

                buildNavigationList(group.navigation, isRootList: false)
            }
        }
    }

    @ViewBuilder
    private func buildNavigationList(_ navigation: [ReadiumShared.Link], isRootList: Bool) -> some View {
        ForEach(navigation.indices, id: \.self) { index in
            let link = navigation[index]

            if let url = URL(string: link.href) {
                NavigationLink(value: url) {
                    OPDSNavigationRow(link: link)
                        .padding(.horizontal)
                }
                .buttonStyle(.plain)
                if isRootList {
                    Divider()
                        .padding(.horizontal)
                } else {
                    Divider()
                        .padding(.leading)
                }
            }
        }
    }
}
