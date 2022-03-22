//
//  Copyright 2022 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SwiftUI
import Combine
import R2Shared

typealias OutlineTableViewAdapter = (UIHostingController<OutlineTableView>, AnyPublisher<Locator, Never>)

protocol OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository, colorScheme: ColorScheme) -> OutlineTableViewAdapter
}

enum OutlineSection: Int {
    case tableOfContents = 0, bookmarks, pageList, landmarks, highlights
}

struct OutlineTableView: View {
    @State private var colorScheme: ColorScheme
    
    @ObservedObject private var bookmarksModel: BookmarksViewModel
    @ObservedObject private var highlightsModel: HighlightsViewModel
    @State private var selectedSection: OutlineSection = .tableOfContents
    
    // Outlines (list of links) to display for each section.
    private var outlines: [OutlineSection: [(level: Int, link: R2Shared.Link)]] = [:]
    
    init(publication: Publication, bookId: Book.Id, bookmarkRepository: BookmarkRepository, highlightRepository: HighlightRepository, colorScheme: ColorScheme) {
     
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
        self.colorScheme = colorScheme
    }
    
    var body: some View {
        VStack {
            OutlineTablePicker(selectedSection: $selectedSection, colorScheme: $colorScheme)
            
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
                                .colorStyle(colorScheme)
                                .onTapGesture {
                                    locatorSubject.send(Locator(link: item.link))
                                }
                            Divider()
                        }
                    }
                } else {
                    preconditionFailure("Outline \(selectedSection) can't be nil!")
                }
                
            case .bookmarks:
                ScrollView {
                    ForEach(bookmarksModel.bookmarks, id: \.self) { bookmark in
                        BookmarkCellView(bookmark: bookmark)
                            .colorStyle(colorScheme)
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
                            .colorStyle(colorScheme)
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
        .colorStyle(colorScheme)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private let locatorSubject = PassthroughSubject<Locator, Never>()
    var goToLocatorPublisher: AnyPublisher<Locator, Never> {
        return locatorSubject.eraseToAnyPublisher()
    }
}

struct OutlineTablePicker: View {
    @Binding var selectedSection: OutlineSection
    @Binding var colorScheme: ColorScheme
    
    @State private var pickerPrevSelectedSegmentTintColor: UIColor?
    @State private var pickerPrevBackgroundColor: UIColor?
    @State private var pickerPrevTintColor: UIColor?
    
    var body: some View {
        Picker("", selection: $selectedSection, content: {
            Text(OutlineTableViewConstants.tabContents).tag(OutlineSection.tableOfContents)
            Text(OutlineTableViewConstants.tabBookmarks).tag(OutlineSection.bookmarks)
            Text(OutlineTableViewConstants.tabPagelist).tag(OutlineSection.pageList)
            Text(OutlineTableViewConstants.tabLandmarks).tag(OutlineSection.landmarks)
            Text(OutlineTableViewConstants.tabHighlights).tag(OutlineSection.highlights)
        })
        .pickerStyle(SegmentedPickerStyle())
        .onAppear(perform: {
            // "foregroundColor"/"backround" modifiers still don't work for Picker, so this is a quick fix; this quick-fix doesn't work well for the Dark mode, because text remains black
            pickerPrevSelectedSegmentTintColor = UISegmentedControl.appearance().selectedSegmentTintColor
            pickerPrevBackgroundColor = UISegmentedControl.appearance().backgroundColor
            pickerPrevTintColor = UISegmentedControl.appearance().tintColor
            
            UISegmentedControl.appearance().selectedSegmentTintColor = UIColor.white
            UISegmentedControl.appearance().backgroundColor = UIColor.gray
            UISegmentedControl.appearance().tintColor = UIColor(colorScheme.textColor) // doesn't work
        })
        .onDisappear {
            // we don't want to spoil other UISegmentedControl's in the app
            UISegmentedControl.appearance().selectedSegmentTintColor = pickerPrevSelectedSegmentTintColor
            UISegmentedControl.appearance().backgroundColor = pickerPrevBackgroundColor
            UISegmentedControl.appearance().tintColor = pickerPrevTintColor
        }
    }
}

enum OutlineTableViewConstants {
    static let tabContents = NSLocalizedString("reader_outline_tab_contents", comment: "Outline contents tab name")
    static let tabBookmarks = NSLocalizedString("reader_outline_tab_bookmarks", comment: "Outline bookmarks tab name")
    static let tabPagelist = NSLocalizedString("reader_outline_tab_pagelist", comment: "Outline pagelist tab name")
    static let tabLandmarks = NSLocalizedString("reader_outline_tab_landmarks", comment: "Outline landmarks tab name")
    static let tabHighlights = NSLocalizedString("reader_outline_tab_highlights", comment: "Outline highlights tab name")
}
