//
//  SearchViewController.swift
//  TestApp
//
//  Created by Olha Pavliuk on 21.11.2021.
//

import UIKit
import R2Shared
import Combine

class SearchViewController: UIViewController {
    private var searchService: SearchService
    private var resultsList: UITableView!
    private var searchResultsBinding: AnyCancellable?
    let kSearchResultCell = "kSearchResultCell"
    
    init(publication: Publication) {
        searchService = SearchService(publication: publication)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        view.layer.cornerRadius = 5
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        // Search Bar
        let inset: CGFloat = 10
        let width = view.frame.width, height = view.frame.width
        let searchBarHeight: CGFloat = 50
        let searchBar = UISearchBar(frame: CGRect(x: inset, y: inset, width: width-inset*2, height: searchBarHeight))
        searchBar.delegate = self
        searchBar.placeholder = "Type a text"
        view.addSubview(searchBar)
        
        // Results
        resultsList = UITableView(frame: CGRect(x: inset, y: inset+searchBarHeight, width: width-inset*2, height: height-(inset+searchBarHeight)), style: .insetGrouped)
        resultsList.backgroundColor = .green
        view.addSubview(resultsList)
        resultsList.dataSource = self
        
        searchService.delegate = self
        
        // the following doesn't work, TODO: find why
//        searchResultsBinding = searchService.results.publisher.sink { _ in
//            self.resultsList.reloadData()
//        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchService.cancelSearch()
        searchService.search(with: searchText)
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchService.results.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: kSearchResultCell)
        let item = searchService.results[indexPath.row]
        
        let myAttribute = [ NSAttributedString.Key.font: UIFont(name: "Chalkduster", size: 18.0)!, NSAttributedString.Key.foregroundColor: UIColor.red ]
        
        let before = NSMutableAttributedString(string: String((item.text.before ?? "").suffix(5)), attributes: [:])
        let highlight = NSAttributedString(string: item.text.highlight ?? "", attributes: myAttribute)
        let after = NSMutableAttributedString(string: String((item.text.after ?? "").prefix(5)), attributes: [:])
        
        before.append(highlight)
        before.append(after)
        
        cell.textLabel!.attributedText = before
        
        return cell
    }
}

extension SearchViewController: SearchServiceDelegate {
    func searchResultsChanged(results: [Locator]) {
        resultsList.reloadData()
    }
}
