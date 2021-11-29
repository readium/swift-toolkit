//
//  Copyright 2021 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Foundation
import SwiftUI
import Combine
import R2Shared
import R2Navigator

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
        return Coordinator(text: $text)
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
    
    var body: some View {
        return VStack {
            SearchBar(text: Binding(get: { viewModel.query }, set: { viewModel.search(with: $0) }))
            List(viewModel.results.indices, id: \.self) { index in
                let locator = viewModel.results[index]
                (
                    Text(locator.text.previewBefore) +
                    Text(locator.text.previewHighlight).foregroundColor(Color.orange) +
                    Text(locator.text.previewAfter)
                )
                .onAppear(perform: {
                    if index == viewModel.results.count-1 {
                        viewModel.loadNextPage()
                    }
                })
                .onTapGesture {
                    viewModel.selectedLocator = locator
                }
            }
        }
    }
}

extension String {
    /// Replaces multiple whitespaces by a single space.
    func coalescingWhitespaces() -> String {
        return replacingOccurrences(of: "[\\s\n]+", with: " ", options: .regularExpression, range: nil)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

extension Locator.Text {
    var previewBefore: String {
        guard let before = before else { return "" }
        // remove all extra whitespaces, but leave the last one
        let suffix = before.hasSuffix(" ") ? " " : ""
        return before.coalescingWhitespaces().removingPrefix(" ") + suffix
    }

    var previewHighlight: String {
        highlight?.coalescingWhitespaces() ?? ""
    }

    var previewAfter: String {
        guard let after = after else { return "" }
        let prefix = after.hasPrefix(" ") ? " " : ""
        return prefix + after.coalescingWhitespaces()
    }
}
