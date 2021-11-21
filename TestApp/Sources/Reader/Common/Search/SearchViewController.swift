//
//  SearchViewController.swift
//  TestApp
//
//  Created by Olha Pavliuk on 21.11.2021.
//

import UIKit
import R2Shared

class SearchViewController: UIViewController {
    var searchService: SearchService
    
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
        let resultsList = UITableView(frame: CGRect(x: inset, y: inset+searchBarHeight, width: width-inset*2, height: height-(inset+searchBarHeight)), style: .insetGrouped)
        resultsList.backgroundColor = .green
        view.addSubview(resultsList)
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "castle" {
            searchService.search(with: searchText) 
        }
    }
}
