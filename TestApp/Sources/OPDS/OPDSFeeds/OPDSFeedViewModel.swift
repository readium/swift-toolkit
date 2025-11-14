//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumOPDS
import ReadiumShared

enum FeedBrowsingState {
    case Navigation
    case Publication
    case MixedGroup
    case MixedNavigationPublication
    case MixedNavigationGroup
    case MixedNavigationGroupPublication
    case None
}

@MainActor
class OPDSFeedViewModel: ObservableObject {
    let feedURL: URL

    @Published var feed: Feed?
    @Published var browsingState: FeedBrowsingState = .None
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
        browsingState = .None
        error = nil
        nextPageURL = nil // Reset next page URL

        OPDSParser.parseURL(url: feedURL) { [weak self] data, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let data = data, let feed = data.feed {
                    self.feed = feed
                    self.browsingState = self.determineBrowsingState(feed)
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

    private func determineBrowsingState(_ feed: Feed) -> FeedBrowsingState {
        if feed.navigation.count > 0, feed.groups.count == 0, feed.publications.count == 0 {
            return .Navigation
        } else if feed.publications.count > 0, feed.groups.count == 0, feed.navigation.count == 0 {
            return .Publication
        } else if feed.groups.count > 0, feed.publications.count == 0, feed.navigation.count == 0 {
            return .MixedGroup
        } else if feed.navigation.count > 0, feed.groups.count == 0, feed.publications.count > 0 {
            return .MixedNavigationPublication
        } else if feed.navigation.count > 0, feed.groups.count > 0, feed.publications.count == 0 {
            return .MixedNavigationGroup
        } else if feed.navigation.count > 0, feed.groups.count > 0, feed.publications.count > 0 {
            return .MixedNavigationGroupPublication
        } else {
            return .None
        }
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

    var publicationsAsGroup: ReadiumShared.Group? {
        guard let feed = feed, !feed.publications.isEmpty else {
            return nil
        }

        let title: String
        switch browsingState {
        case .MixedNavigationPublication:
            title = NSLocalizedString("opds_browse_title", comment: "Title of the section displaying the feeds")
        case .MixedNavigationGroupPublication:
            title = feed.metadata.title
        default:
            return nil
        }

        // Create the group and assign publications
        let pubGroup = ReadiumShared.Group(title: title)
        pubGroup.publications = feed.publications
        return pubGroup
    }
}
