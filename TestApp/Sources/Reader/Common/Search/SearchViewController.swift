//
//  SearchViewController.swift
//  TestApp
//
//  Created by Olha Pavliuk on 21.11.2021.
//

import UIKit
import R2Shared
import Combine
import R2Navigator

class SearchViewController: UIViewController {
    private let navigator: UIViewController & Navigator
    private let viewModel: SearchViewModel
    private var resultsTable: UITableView!
    private var searchResultsBinding: AnyCancellable?
    let kSearchResultCell = "kSearchResultCell"
    private var cachedResults = [Locator]()
    
    init(navigator: UIViewController & Navigator, viewModel: SearchViewModel) {
        self.navigator = navigator
        self.viewModel = viewModel
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
        searchBar.text = viewModel.lastQuery ?? ""
        searchBar.delegate = self
        searchBar.placeholder = "Type a text"
        view.addSubview(searchBar)
        
        // Results
        resultsTable = UITableView(frame: CGRect(x: inset, y: inset+searchBarHeight, width: width-inset*2, height: height-(inset+searchBarHeight)), style: .insetGrouped)
        view.addSubview(resultsTable)
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.register(UINib(nibName: "SearchResultCell", bundle: Bundle.main), forCellReuseIdentifier: "kSearchResultCell")
        //resultsTable.register(SearchResultCell.self, forCellReuseIdentifier: kSearchResultCell)
        
        searchResultsBinding = viewModel.$results.sink { [self] newValue in
            self.cachedResults = newValue
            self.resultsTable.reloadData()
        }
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cachedResults.removeAll()
        viewModel.cancelSearch()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        cachedResults.removeAll()
        viewModel.cancelSearch()
        viewModel.search(with: searchText)
    }
}

extension SearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.dismiss(animated: false, completion: nil)
        navigator.go(to: cachedResults[indexPath.row], animated: true) {
            if let decorator = self.navigator as? DecorableNavigator {
                let locator = self.cachedResults[indexPath.row]
                let decoration = Decoration(id: locator.text.jsonString ?? "", locator: locator, style: Decoration.Style.highlight(tint: .yellow, isActive: false))
                decorator.apply(decorations: [decoration], in: "search")
            }
        }
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cachedResults.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = resultsTable.dequeueReusableCell(withIdentifier: kSearchResultCell, for: indexPath) as! SearchResultCell
        let item = cachedResults[indexPath.row]
        
        let myAttribute = [ NSAttributedString.Key.backgroundColor : UIColor.yellow ]
        
        // .suffix(5))
        let before = NSMutableAttributedString(string: String(item.text.before ?? ""), attributes: [:])
        let highlight = NSAttributedString(string: item.text.highlight ?? "", attributes: myAttribute)
        let after = NSMutableAttributedString(string: String(item.text.after ?? ""), attributes: [:])
        
        before.append(highlight)
        before.append(after)
        
        cell.textView.isEditable = false
        cell.textView.isUserInteractionEnabled = false
        cell.textView.attributedText = before
        cell.textView.setContentOffset(CGPoint(x: (cell.frame.width-cell.textView.contentSize.width)/2, y: (cell.frame.height-cell.textView.contentSize.height)/2), animated: false)
        
        return cell
    }
}
                                              
                                              
