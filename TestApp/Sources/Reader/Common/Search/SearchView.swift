//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Foundation
import ReadiumNavigator
import ReadiumShared
import SwiftUI

struct SearchBar: UIViewRepresentable {
    @Binding var text: String

    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        init(text: Binding<String>) {
            _text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
    }

    func makeCoordinator() -> SearchBar.Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.placeholder = "Search"
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
}

struct SearchView: View {
    @ObservedObject var viewModel: SearchViewModel
    @State var viewVisible: Bool = false

    var body: some View {
        VStack {
            SearchBar(text: Binding(get: { viewModel.query }, set: { viewModel.search(with: $0) }))
            ScrollViewReader { proxy in
                List(viewModel.results.indices, id: \.self) { index in
                    let locator = viewModel.results[index]
                    let text = locator.text.sanitized()
                    (
                        Text(text.before ?? "") +
                            Text(text.highlight ?? "").foregroundColor(Color.orange) +
                            Text(text.after ?? "")
                    )
                    .onAppear(perform: {
                        if index == viewModel.results.count - 1 {
                            viewModel.loadNextPage()
                        }
                    })
                    .onTapGesture {
                        viewModel.selectSearchResultCell(locator: locator, index: index)
                    }
                }
                .onChange(of: viewVisible) {
                    if viewVisible, let lastSelectedIndex = viewModel.selectedIndex {
                        proxy.scrollTo(lastSelectedIndex, anchor: .top)
                    }
                }
            }
        }
        .onAppear {
            viewVisible = true
        }
        .onDisappear {
            viewVisible = false
        }
    }
}
