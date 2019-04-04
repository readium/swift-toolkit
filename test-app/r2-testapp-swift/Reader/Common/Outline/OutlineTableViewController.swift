//
//  TableOfContentsTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 7/24/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import R2Shared
import R2Navigator
import UIKit


protocol OutlineTableViewControllerFactory {
    func make(tableOfContents: [Link], format: Publication.Format) -> OutlineTableViewController
}

protocol OutlineTableViewControllerDelegate: AnyObject {
    
    var bookmarksDataSource: BookmarkDataSource? { get }
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectItem item: String)
    func outline(_ outlineTableViewController: OutlineTableViewController, didSelectBookmark bookmark: Bookmark)
    
}

final class OutlineTableViewController: UITableViewController {
    
    weak var delegate: OutlineTableViewControllerDelegate?
    
    let kBookmarkCell = "kBookmarkCell"
    let kContentCell = "kContentCell"
    
    var publicationFormat: Publication.Format = .epub
    
    var tableOfContents = [Link]()
    var allElements = [Link]()
    
    var bookmarksDataSource: BookmarkDataSource? {
        return delegate?.bookmarksDataSource
    }

    @IBOutlet weak var segments: UISegmentedControl!
    @IBAction func segmentChanged(_ sender: Any) {
        tableView.reloadData()
    }
    
    @IBAction func dismissController(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Table Of Contents"
        tableView.delegate = self
        tableView.dataSource = self
        // Temporary - Get all the elements/subelements.
        if (publicationFormat != .cbz) {
            for link in tableOfContents {
                let childs = childsOf(parent: link)
                
                // Append parent.
                allElements.append(link)
                // Append childs, and their childs... recursive.
                allElements.append(contentsOf: childs)
            }
        }
        tableView.tintColor = UIColor.black
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch segments.selectedSegmentIndex {
        case 0:
            defer {
                tableView.deselectRow(at: indexPath, animated: true)
            }
            if (publicationFormat != .cbz) {
                let resourcePath = allElements[indexPath.row].href
                delegate?.outline(self, didSelectItem: resourcePath)
            } else {
                delegate?.outline(self, didSelectItem: String(indexPath.row))
            }
            dismiss(animated: true, completion:nil)
            break
        case 1:
            let selectedIndex = indexPath.item
            let bookmarks = bookmarksDataSource?.bookmarks ?? []
            if selectedIndex < 0 || selectedIndex >= bookmarks.count {return}
            if let bookmark = bookmarksDataSource?.bookmarks[selectedIndex] {
                delegate?.outline(self, didSelectBookmark: bookmark)
            }
            dismiss(animated: true, completion: nil)
            break
        default:break
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch segments.selectedSegmentIndex {
        case 0:
            let cell = UITableViewCell(style: .default, reuseIdentifier: kContentCell)
            if (publicationFormat != .cbz) {
                cell.textLabel?.text = allElements[indexPath.row].title
            } else {
                cell.textLabel?.text = tableOfContents[indexPath.row].href
            }
            return cell
        case 1:
            let cell: BookmarkCell = {
                if let cell = tableView.dequeueReusableCell(withIdentifier: kBookmarkCell) as? BookmarkCell {
                    return cell
                }
                return BookmarkCell(style: UITableViewCell.CellStyle.subtitle, reuseIdentifier: kBookmarkCell)
            } ()
            
            if let bookmark = bookmarksDataSource?.bookmark(at: indexPath.item) {
                cell.textLabel?.text = bookmark.locator.title
                cell.formattedDate = bookmark.creationDate
                cell.detailTextLabel?.text = nil
                if let progression = bookmark.locator.locations?.progression {
                    cell.detailTextLabel?.text = String(format: "\(progression)%.f%% through the chapter", progression * 100)
                }
            }
            
            return cell
        default:
            let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch segments.selectedSegmentIndex {
        case 0:
            if (publicationFormat != .cbz) {
                return allElements.count
            } else {
                return tableOfContents.count
            }
        case 1:
            return bookmarksDataSource?.count ?? 0
        default:
            return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = tableView.backgroundColor
        cell.tintColor = tableView.tintColor
        cell.textLabel?.textColor = tableView.tintColor
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        switch segments.selectedSegmentIndex {
        case 0:
            return false
        case 1:
            return true
        default:
            return false
        }
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        switch segments.selectedSegmentIndex {
        case 0:
            break
        case 1:
            if editingStyle == .delete {
                if (self.bookmarksDataSource?.removeBookmark(index: indexPath.item) ?? false) {
                    tableView.deleteRows(at: [indexPath], with: .fade)
                }
            }
            break
        default: break
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
    
    fileprivate func childsOf(parent: Link) -> [Link] {
        var childs = [Link]()
        
        for link in parent.children {
            childs.append(link)
            childs.append(contentsOf: childsOf(parent: link))
        }
        return childs
    }
}
