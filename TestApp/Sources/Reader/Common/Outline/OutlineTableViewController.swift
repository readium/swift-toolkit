//
//  OutlineTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 7/24/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Combine
import R2Shared
import R2Navigator
import UIKit
import SwiftUI

typealias HighlightCellSwiftuiWrapper = HostingTableViewCell<HighlightCellView>

protocol OutlineTableViewControllerFactory {
    func make(publication: Publication, bookId: Book.Id, bookmarks: BookmarkRepository, highlights: HighlightRepository) -> OutlineTableViewController
}

protocol OutlineTableViewControllerDelegate: AnyObject {
    func outline(_ outlineTableViewController: OutlineTableViewController, goTo location: Locator)
}

final class OutlineTableViewController: UITableViewController {

    weak var delegate: OutlineTableViewControllerDelegate?
    
    let kBookmarkCell = "kBookmarkCell"
    let kHighlightCell = "kHighlightCell"
    let kContentCell = "kContentCell"
    
    var publication: Publication!
    var bookId: Book.Id!
    var bookmarkRepository: BookmarkRepository!
    var highlightRepository: HighlightRepository!
  
    // Outlines (list of links) to display for each section.
    private var outlines: [Section: [(level: Int, link: R2Shared.Link)]] = [:]
    private var bookmarks: [Bookmark] = []
    private var highlights: [Highlight] = []
    
    private var subscriptions = Set<AnyCancellable>()

    @IBOutlet weak var segments: UISegmentedControl!
    @IBAction func segmentChanged(_ sender: Any) {
        tableView.reloadData()
    }

    private enum Section: Int {
        case tableOfContents = 0, bookmarks, pageList, landmarks, highlights
    }
    
    private var section: Section {
        return Section(rawValue: segments.selectedSegmentIndex) ?? .tableOfContents
    }
    
    @IBAction func dismissController(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = publication.metadata.title
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tintColor = UIColor.black

        func flatten(_ links: [R2Shared.Link], level: Int = 0) -> [(level: Int, link: R2Shared.Link)] {
            return links.flatMap { [(level, $0)] + flatten($0.children, level: level + 1) }
        }
        
        outlines = [
            .tableOfContents: flatten(publication.tableOfContents),
            .landmarks: flatten(publication.landmarks),
            .pageList: flatten(publication.pageList)
        ]
        
        bookmarkRepository.all(for: bookId)
            .assertNoFailure()
            .sink { bookmarks in
                self.bookmarks = bookmarks
                self.tableView.reloadData()
            }
            .store(in: &subscriptions)
        
        highlightRepository.all(for: bookId)
            .assertNoFailure()
            .sink { highlights in
                self.highlights = highlights
                self.tableView.reloadData()
            }
            .store(in: &subscriptions)
        
        tableView.register(HighlightCellSwiftuiWrapper.self, forCellReuseIdentifier: kHighlightCell)
    }
    
    func locator(at indexPath: IndexPath) -> Locator? {
        switch section {
        case .bookmarks:
            return bookmarks[indexPath.row].locator
        case .highlights:
            return highlights[indexPath.row].locator

        default:
            guard let outline = outlines[section],
                outline.indices.contains(indexPath.row) else
            {
                return nil
            }
            return Locator(link: outline[indexPath.row].link)
        }
    }
    
    override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        // If the locator's href is #, then the item is not a link.
        guard let locator = locator(at: indexPath), locator.href != "#" else {
            return nil
        }
        return indexPath
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        if let locator = locator(at: indexPath) {
            delegate?.outline(self, goTo: locator)
        }

        dismiss(animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch section {
        case .bookmarks:
            let cell: BookmarkCell = {
                if let cell = tableView.dequeueReusableCell(withIdentifier: kBookmarkCell) as? BookmarkCell {
                    return cell
                }
                return BookmarkCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: kBookmarkCell)
            } ()
            
            let bookmark = bookmarks[indexPath.row]
            cell.textLabel?.text = bookmark.locator.title
            cell.formattedDate = bookmark.created
            cell.detailTextLabel?.text = {
                if let position = bookmark.locator.locations.position {
                    return String(format: NSLocalizedString("reader_outline_position_label", comment: "Outline bookmark label when the position is available"), position)
                } else if let progression = bookmark.locator.locations.progression {
                    return String(format: NSLocalizedString("reader_outline_progression_label", comment: "Outline bookmark label when the progression is available"), progression * 100)
                } else {
                    return nil
                }
            }()
            return cell
        case .highlights:
            let cell = tableView.dequeueReusableCell(withIdentifier: kHighlightCell) as! HighlightCellSwiftuiWrapper
            cell.host(HighlightCellView(highlight: highlights[indexPath.row]), parent: self)
            return cell
        default:
            guard let outline = outlines[section] else {
                return UITableViewCell(style: .default, reuseIdentifier: nil)
            }
            
            let cell = UITableViewCell(style: .default, reuseIdentifier: kContentCell)
            let item = outline[indexPath.row]
            cell.textLabel?.text = String(repeating: "  ", count: item.level) + (item.link.title ?? item.link.href)
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection tableSection: Int) -> Int {
        switch section {
        case .bookmarks:
            return bookmarks.count
        case .highlights:
            return highlights.count
        default:
            return outlines[section]?.count ?? 0
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = tableView.backgroundColor
        cell.tintColor = tableView.tintColor
        cell.textLabel?.textColor = tableView.tintColor
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch section {
        case .bookmarks:
            return true
        default:
            return false
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch section {
        case .bookmarks:
            if editingStyle == .delete {
                let bookmark = bookmarks[indexPath.row]
                bookmarkRepository.remove(bookmark.id!)
                    .assertNoFailure()
                    .sink {}
                    .store(in: &subscriptions)
            }
            
        default:
            break
        }
    }
    
    public override var prefersStatusBarHidden: Bool {
        return false
    }
}

extension OutlineTableViewController {
    
    /// Synchronyze the UI appearance to the UserSettings.Appearance.
    ///
    /// - Parameter appearance: The appearance.
    public func setUIColor(for appearance: UserProperty) {
        let colors = AssociatedColors.getColors(for: appearance)
        
        tableView.tintColor = colors.textColor
        tableView.backgroundColor = colors.mainColor
        tableView.reloadData()
    }

}
