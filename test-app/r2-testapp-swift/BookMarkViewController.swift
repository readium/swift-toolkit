//
//  BookmarkViewController.swift
//  r2-testapp-swift
//
//  Created by Senda Li on 2018/7/19.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation
import UIKit

let kBookmarkInfoCell = "kBookmarkInfoCell"

class BookmarkViewController: UITableViewController {
    
    let dataSource: BookmarkDataSource
    
    init(dataSource:BookmarkDataSource) {
        self.dataSource = dataSource
        super.init(style: .plain)
        
        self.tableView.rowHeight = 50
    }
    
    var didSelectBookmark: ((Bookmark) -> Void)?
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func reload() {
        self.dataSource.reloadDate()
        self.tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.navigationController?.navigationBar.isHidden = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.bookmarkCount()
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell: BookMarkCell = {
            if let theCell = tableView.dequeueReusableCell(withIdentifier: kBookmarkInfoCell) as? BookMarkCell {
                return theCell
            }
            return BookMarkCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: kBookmarkInfoCell)
        } ()
        
        if let bookmark = dataSource.bookmark(at: indexPath.item) {
            cell.textLabel?.text = bookmark.description
            cell.date = bookmark.createdDate
            let progress = String(format: "%.2f%%", bookmark.progress)
            cell.detailTextLabel?.text = "\(progress) through the chapter"
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            _ = self.dataSource.removeBookmark(index: indexPath.item)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }
    }
    
    // delegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let theIndex = indexPath.item
        let bookmarkList = self.dataSource.bookmarkList
        if theIndex < 0 || theIndex >= bookmarkList.count {return}
        let bookmark = self.dataSource.bookmarkList[theIndex]
        self.didSelectBookmark?(bookmark)
    }
}

class BookMarkCell: UITableViewCell {
    
    lazy var dateFormatter: DateFormatter = {
        
        let formatter = DateFormatter()
        formatter.dateFormat = "M/dd/yy, HH:mm"
        formatter.locale = Locale(identifier:"en") //.current
        
        return formatter
    } ()
    
    lazy var timeLabel: UILabel = {
        let label = UILabel()
        self.contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        if let detailLabel = self.detailTextLabel {
            label.textColor = detailLabel.textColor
            label.font = detailLabel.font
            
            NSLayoutConstraint.activate([
                label.bottomAnchor.constraint(equalTo: detailLabel.bottomAnchor),
                label.heightAnchor.constraint(equalTo: detailLabel.heightAnchor),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
            ])
        }
        
        return label
    } ()
    
    var date: Date? {
        didSet {
            self.timeLabel.text = {
                if let newDate = date{
                    return dateFormatter.string(from: newDate)
                } else {
                    return ""
                }
            } ()
            self.timeLabel.sizeToFit()
        }
    }
}
