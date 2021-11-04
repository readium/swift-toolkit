//
//  FontSelectionTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/20/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import R2Navigator
import R2Shared

protocol FontSelectionDelegate: AnyObject {
    func currentFontIndex() -> Int
    func fontDidChange(to fontIndex: Int)
}

class FontSelectionViewController: UIViewController {
    @IBOutlet weak var fontTableView: UITableView!
    weak var delegate: FontSelectionDelegate?
    var userSettings: UserSettings?
    var initialTableViewIndex: IndexPath?

    override func viewDidLoad() {
        super.viewDidLoad()
        fontTableView.delegate = self
        fontTableView.dataSource = self
        self.navigationController?.isNavigationBarHidden = true
        fontTableView.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let initialFontIndex = delegate?.currentFontIndex() {
            initialTableViewIndex = IndexPath.init(row: initialFontIndex, section: 0)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        // Update preferredContentSize only when fontTableView is populated
        self.preferredContentSize = CGSize(width: super.preferredContentSize.width, height: fontTableView.contentSize.height)
    }
}

extension FontSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let fontFamily = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable {
            return fontFamily.values.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fontTableViewCell")!
        
        let fontFamily = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable
        cell.textLabel?.text = fontFamily?.values[indexPath.row]

        return cell
    }
}

extension FontSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        delegate?.fontDidChange(to: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let oldIndex = tableView.indexPathForSelectedRow {
            tableView.cellForRow(at: oldIndex)?.accessoryType = .none
        } else {
            if let initialTableViewIndex = initialTableViewIndex {
                tableView.cellForRow(at: initialTableViewIndex)?.accessoryType = .none
            }
        }
        
        tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
        
        return indexPath
    }
    
    override func viewDidLayoutSubviews() {
        // Add initial checkmark on row only when view is resized according to its preferredContentSize
        if fontTableView.indexPathForSelectedRow == nil && initialTableViewIndex != nil {
            fontTableView.cellForRow(at: initialTableViewIndex!)?.accessoryType = .checkmark
        }
    }
    
}
