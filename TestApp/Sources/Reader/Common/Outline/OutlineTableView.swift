//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import Combine
import R2Shared

protocol OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository, subscriber: OutlineLocatorSubsriber) -> UIHostingController<OutlineTableView>
}

struct OutlineTableView: View {
    
    var publication: Publication!
    var bookId: Book.Id!
    
    @ObservedObject var bookmarksModel: BookmarksViewModel
    @ObservedObject var highlightsModel: HighlightsViewModel
    
    // Outlines (list of links) to display for each section.
    private var outlines: [Section: [(level: Int, link: R2Shared.Link)]] = [:]
    
    private enum Section: Int {
        case tableOfContents = 0, bookmarks, pageList, landmarks, highlights
    }
    @State private var selectedSection: Section = .tableOfContents
    
    init(publication: Publication, bookId: Book.Id, bookmarkRepository: BookmarkRepository, highlightRepository: HighlightRepository) {
     
        func flatten(_ links: [R2Shared.Link], level: Int = 0) -> [(level: Int, link: R2Shared.Link)] {
            return links.flatMap { [(level, $0)] + flatten($0.children, level: level + 1) }
        }
        
        outlines = [
            .tableOfContents: flatten(publication.tableOfContents),
            .landmarks: flatten(publication.landmarks),
            .pageList: flatten(publication.pageList)
        ]
        
        bookmarksModel = BookmarksViewModel(bookId: bookId, bookmarkRepository: bookmarkRepository)
        highlightsModel = HighlightsViewModel(bookId: bookId, highlightRepository: highlightRepository)
    }
    
    var body: some View {
        VStack {
            Picker("", selection: $selectedSection, content: {
                Text(OutlineTableViewConstants.tabContents).tag(Section.tableOfContents)
                Text(OutlineTableViewConstants.tabBookmarks).tag(Section.bookmarks)
                Text(OutlineTableViewConstants.tabPagelist).tag(Section.pageList)
                Text(OutlineTableViewConstants.tabLandmarks).tag(Section.landmarks)
                Text(OutlineTableViewConstants.tabHighlights).tag(Section.highlights)
            })
            .pickerStyle(SegmentedPickerStyle())
            
            switch selectedSection {
            case .tableOfContents, .pageList, .landmarks:
                if let outline = outlines[selectedSection] {
                    ScrollView {
                        ForEach(outline.indices, id: \.self) { index in
                            let item = outline[index]
                            Text(String(repeating: "  ", count: item.level) + (item.link.title ?? item.link.href))
                                .listRowInsets(EdgeInsets())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.white) // I can't make a whole row tappable without this modifier; now the question is where to get a color for it based on Night/Day mode
                                .onTapGesture {
                                    locatorSubject.send(Locator(link: item.link))
                                }
                            Divider()
                        }
                    }
                } else {
                    Text(OutlineTableViewConstants.errorOutlineNotFound)
                }
                
            case .bookmarks:
                ScrollView {
                    ForEach(bookmarksModel.bookmarks, id: \.self) { bookmark in
                        BookmarkCellView(bookmark: bookmark)
                            .onTapGesture {
                                locatorSubject.send(bookmark.locator)
                            }
                            .listRowInsets(EdgeInsets())
                        Divider()
                    }
                }
                .onAppear { self.bookmarksModel.loadIfNeeded() }
            case .highlights:
                ScrollView {
                    ForEach(highlightsModel.highlights, id: \.self) { highlight in
                        HighlightCellView(highlight: highlight)
                            .listRowInsets(EdgeInsets())
                            .onTapGesture {
                                locatorSubject.send(highlight.locator)
                            }
                        Divider()
                    }
                }
                .onAppear { self.highlightsModel.loadIfNeeded() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private let locatorSubject = PassthroughSubject<Locator, Never>()
    var goToLocatorPublisher: AnyPublisher<Locator, Never> {
        return locatorSubject.eraseToAnyPublisher()
    }
}

enum OutlineTableViewConstants {
    static let tabContents = NSLocalizedString("reader_outline_tab_contents", comment: "Outline contents tab name")
    static let tabBookmarks = NSLocalizedString("reader_outline_tab_bookmarks", comment: "Outline bookmarks tab name")
    static let tabPagelist = NSLocalizedString("reader_outline_tab_pagelist", comment: "Outline pagelist tab name")
    static let tabLandmarks = NSLocalizedString("reader_outline_tab_landmarks", comment: "Outline landmarks tab name")
    static let tabHighlights = NSLocalizedString("reader_outline_tab_highlights", comment: "Outline highlights tab name")
    static let errorOutlineNotFound = NSLocalizedString("reader_outline_not_found", comment: "Outline not found")
}
