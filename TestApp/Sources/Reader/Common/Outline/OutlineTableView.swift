//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import ReadiumShared
import SwiftUI

typealias OutlineTableViewAdapter = (UIHostingController<OutlineTableView>, AnyPublisher<Locator, Never>)

protocol OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository) -> OutlineTableViewAdapter
}

enum OutlineSection: Int {
    case tableOfContents = 0, bookmarks, pageList, landmarks, highlights
}

struct OutlineTableView: View {
    private let publication: Publication
    @ObservedObject private var bookmarksModel: BookmarksViewModel
    @ObservedObject private var highlightsModel: HighlightsViewModel
    @State private var selectedSection: OutlineSection = .tableOfContents

    // Outlines (list of links) to display for each section.
    @State private var outlines: [OutlineSection: [(level: Int, link: ReadiumShared.Link)]] = [:]

    init(publication: Publication, bookId: Book.Id, bookmarkRepository: BookmarkRepository, highlightRepository: HighlightRepository) {
        self.publication = publication
        bookmarksModel = BookmarksViewModel(bookId: bookId, repository: bookmarkRepository)
        highlightsModel = HighlightsViewModel(bookId: bookId, repository: highlightRepository)

        outlines = [
            .tableOfContents: [],
            .landmarks: flatten(publication.landmarks),
            .pageList: flatten(publication.pageList),
        ]
    }

    private func loadTableOfContents() async {
        guard let toc = try? await publication.tableOfContents().get() else {
            return
        }

        outlines[.tableOfContents] = flatten(!toc.isEmpty ? toc : publication.readingOrder)
    }

    var body: some View {
        VStack {
            OutlineTablePicker(selectedSection: $selectedSection)

            switch selectedSection {
            case .tableOfContents, .pageList, .landmarks:
                if let outline = outlines[selectedSection] {
                    List(outline.indices, id: \.self) { index in
                        let item = outline[index]
                        Text(String(repeating: "  ", count: item.level) + (item.link.title ?? item.link.href))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                Task {
                                    if let locator = await publication.locate(item.link) {
                                        locatorSubject.send(locator)
                                    }
                                }
                            }
                    }
                }

            case .bookmarks:
                List(bookmarksModel.bookmarks, id: \.self) { bookmark in
                    BookmarkCellView(bookmark: bookmark)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            locatorSubject.send(bookmark.locator)
                        }
                }
                .onAppear { bookmarksModel.loadIfNeeded() }
            case .highlights:
                List(highlightsModel.highlights, id: \.self) { highlight in
                    HighlightCellView(highlight: highlight)
                        .contentShape(Rectangle())
                        .listRowInsets(EdgeInsets()) // to remove padding at the left side
                        .onTapGesture {
                            locatorSubject.send(highlight.locator)
                        }
                }
                .onAppear { highlightsModel.loadIfNeeded() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            Task {
                await loadTableOfContents()
            }
        }
    }

    private let locatorSubject = PassthroughSubject<Locator, Never>()
    var goToLocatorPublisher: AnyPublisher<Locator, Never> {
        locatorSubject.eraseToAnyPublisher()
    }
}

struct OutlineTablePicker: View {
    @Binding var selectedSection: OutlineSection

    var body: some View {
        Picker("", selection: $selectedSection, content: {
            Text(OutlineTableViewConstants.tabContents).tag(OutlineSection.tableOfContents)
            Text(OutlineTableViewConstants.tabBookmarks).tag(OutlineSection.bookmarks)
            Text(OutlineTableViewConstants.tabPagelist).tag(OutlineSection.pageList)
            Text(OutlineTableViewConstants.tabLandmarks).tag(OutlineSection.landmarks)
            Text(OutlineTableViewConstants.tabHighlights).tag(OutlineSection.highlights)
        })
        .pickerStyle(SegmentedPickerStyle())
    }
}

enum OutlineTableViewConstants {
    static let tabContents = NSLocalizedString("reader_outline_tab_contents", comment: "Outline contents tab name")
    static let tabBookmarks = NSLocalizedString("reader_outline_tab_bookmarks", comment: "Outline bookmarks tab name")
    static let tabPagelist = NSLocalizedString("reader_outline_tab_pagelist", comment: "Outline pagelist tab name")
    static let tabLandmarks = NSLocalizedString("reader_outline_tab_landmarks", comment: "Outline landmarks tab name")
    static let tabHighlights = NSLocalizedString("reader_outline_tab_highlights", comment: "Outline highlights tab name")
}

private func flatten(_ links: [ReadiumShared.Link], level: Int = 0) -> [(level: Int, link: ReadiumShared.Link)] {
    links.flatMap { [(level, $0)] + flatten($0.children, level: level + 1) }
}
