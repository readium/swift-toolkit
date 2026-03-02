//
//  Copyright 2026 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumOPDS
import ReadiumShared

@MainActor
class OPDSFeedViewModel: ObservableObject {
    let feedURL: URL

    @Published var feed: Feed?
    @Published var error: Error?
    @Published var isShowingFacets = false

    /// Tracks if a pagination request is in progress.
    @Published var isLoadingNextPage = false

    weak var delegate: OPDSModuleDelegate?

    /// Stores the URL for the next page of results.
    private var nextPageURL: URL?

    init(feedURL: URL, delegate: OPDSModuleDelegate?) {
        self.feedURL = feedURL
        self.delegate = delegate
    }

    /// Fetches and parses the initial OPDS feed.
    func parseFeed() {
        feed = nil
        error = nil
        nextPageURL = nil // Reset next page URL

        OPDSParser.parseURL(url: feedURL) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let data = data, let feed = data.feed {
                    self.feed = feed
                    // Find and store the next page URL
                    self.nextPageURL = self.findNextPageURL(feed: feed)
                } else if let error = error {
                    self.error = error
                    print("Failed to parse feed: \(error)")
                } else {
                    self.error = OPDSError.invalidURL(self.feedURL.absoluteString)
                }
            }
        }
    }

    /// Fetches and parses the next page of the feed.
    func loadNextPage() {
        // Don't load if already loading or if there's no next page
        guard !isLoadingNextPage, let url = nextPageURL else {
            return
        }

        isLoadingNextPage = true

        OPDSParser.parseURL(url: url) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let data = data, let newFeed = data.feed {
                    // Append new publications to the existing feed
                    self.feed?.publications.append(contentsOf: newFeed.publications)
                    // Find the *next* next page URL
                    self.nextPageURL = self.findNextPageURL(feed: newFeed)
                } else if let error = error {
                    print("Failed to load next page: \(error)")
                }

                self.isLoadingNextPage = false
            }
        }
    }

    /// Finds the "next" link in the feed's links.
    private func findNextPageURL(feed: Feed) -> URL? {
        guard let href = feed.links.firstWithRel(.next)?.href else {
            return nil
        }
        return URL(string: href)
    }

    // MARK: - View-Ready Computed Properties

    /// Provides the navigation links, or an empty array.
    var navigation: [ReadiumShared.Link] {
        feed?.navigation ?? []
    }

    /// Provides the feed groups, or an empty array.
    var groups: [ReadiumShared.Group] {
        feed?.groups ?? []
    }

    /// Provides the publications, or an empty array.
    var publications: [ReadiumShared.Publication] {
        feed?.publications ?? []
    }

    /// True if the feed contains only publications and no navigation or groups.
    /// The View uses this to decide whether to show a grid or a list.
    var isPublicationOnly: Bool {
        guard let feed = feed else { return false }
        return !feed.publications.isEmpty
            && feed.navigation.isEmpty
            && feed.groups.isEmpty
    }

    /// True if the feed contains any content at all.
    var hasContent: Bool {
        guard let feed = feed else { return false }
        return !feed.navigation.isEmpty
            || !feed.groups.isEmpty
            || !feed.publications.isEmpty
    }

    /// Creates a group for publications at the feed's root.
    /// This allows the View to render them as just another group in the list.
    var rootPublicationsGroup: ReadiumShared.Group? {
        guard let feed = feed, !feed.publications.isEmpty else {
            return nil
        }

        if isPublicationOnly {
            return nil
        }

        let title: String
        if feed.groups.isEmpty {
            title = NSLocalizedString("opds_browse_title", comment: "Title of the section displaying the feeds")
        } else {
            title = feed.metadata.title
        }

        // Create the group and assign publications
        let pubGroup = ReadiumShared.Group(title: title)
        pubGroup.publications = feed.publications
        return pubGroup
    }
}
