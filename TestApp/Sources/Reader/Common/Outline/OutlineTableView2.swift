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
    
    private var subscriptions = Set<AnyCancellable>()
    
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
            Picker("Favorite Color", selection: $selectedSection, content: {
                Text("Contents").tag(Section.tableOfContents)
                Text("Bookmarks").tag(Section.bookmarks)
                Text("Pagelist").tag(Section.pageList)
                Text("Landmarks").tag(Section.landmarks)
                Text("Highlights").tag(Section.highlights)
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
                                .background(Color.black) // I can't make a whole row tappable without this modifier; now the question is where to get a color for it based on Night/Day mode
                                .onTapGesture {
                                    locatorSubject.send(Locator(link: item.link))
                                }
                            Divider()
                        }
                    }
                } else {
                    Text("Some error occured for outline #\(selectedSection.rawValue) ...")
                }
                
            case .bookmarks:
                ScrollView {
                    ForEach(bookmarksModel.bookmarks, id: \.self) { bookmark in
                        BookmarkCellView(bookmark: bookmark)
                            .onTapGesture {
                                locatorSubject.send(bookmark.locator)
                            }
                            .listRowInsets(EdgeInsets())
                    }
                }
                //.overlay(BookmarksStatusOverlay(model: model))
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
                //.overlay(HighlightsStatusOverlay(model: model))
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

// Pattern used: https://stackoverflow.com/a/61858358/2567725
class HighlightsViewModel: ObservableObject {
    private let bookId: Book.Id
    private let highlightRepository: HighlightRepository
    
    init(bookId: Book.Id, highlightRepository: HighlightRepository) {
        self.bookId = bookId
        self.highlightRepository = highlightRepository
    }
    
    @Published var highlights = [Highlight]()
    @Published var state = State.ready

    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    var dataTask: AnyPublisher<[Highlight], Error> {
        self.highlightRepository.all(for: bookId)
    }

    func load() {
        assert(Thread.isMainThread)
        self.state = .loading(self.dataTask.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case let .failure(error):
                    self.state = .error(error)
                }
            },
            receiveValue: { value in
                self.state = .loaded
                self.highlights = value
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = self.state else { return }
        self.load()
    }
}

class BookmarksViewModel: ObservableObject {
    private let bookId: Book.Id
    private let bookmarkRepository: BookmarkRepository
    
    init(bookId: Book.Id, bookmarkRepository: BookmarkRepository) {
        self.bookId = bookId
        self.bookmarkRepository = bookmarkRepository
    }
    
    @Published var bookmarks = [Bookmark]()
    @Published var state = State.ready

    enum State {
        case ready
        case loading(Combine.Cancellable)
        case loaded
        case error(Error)
    }

    var dataTask: AnyPublisher<[Bookmark], Error> {
        self.bookmarkRepository.all(for: bookId)
    }

    func load() {
        assert(Thread.isMainThread)
        self.state = .loading(self.dataTask.sink(
            receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case let .failure(error):
                    self.state = .error(error)
                }
            },
            receiveValue: { value in
                self.state = .loaded
                self.bookmarks = value
            }
        ))
    }

    func loadIfNeeded() {
        assert(Thread.isMainThread)
        guard case .ready = self.state else { return }
        self.load()
    }
}
