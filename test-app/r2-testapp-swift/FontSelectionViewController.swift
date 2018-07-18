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

protocol FontSelectionDelegate: class {
    func currentFontIndex() -> Int
    func fontDidChange(to fontIndex: Int)
}

class FontSelectionViewController: UIViewController {
    @IBOutlet weak var fontTableView: UITableView!
    weak var delegate: FontSelectionDelegate?
    var userSettings: UserSettings?

    override func viewDidLoad() {
        super.viewDidLoad()
        fontTableView.delegate = self
        fontTableView.dataSource = self
        self.navigationController?.isNavigationBarHidden = true
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let initialFontIndex = delegate?.currentFontIndex() {
            let index = IndexPath.init(row: initialFontIndex, section: 0)
            fontTableView.cellForRow(at: index)?.accessoryType = .checkmark
        }
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
        
        var fontName: String
        if let fontFamily = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable {
            fontName = fontFamily.values[indexPath.row]
        } else {
            fontName = "Error"
        }
        
        cell.textLabel?.text = fontName
        return cell
    }
}

extension FontSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath)
        uncheckAllRows()
        cell?.accessoryType = .checkmark
        delegate?.fontDidChange(to: indexPath.row)
    }

    fileprivate func uncheckAllRows() {
        let rows = fontTableView.numberOfRows(inSection: 0)
        var row = 0

        while row < rows {
            if let cell =  fontTableView.cellForRow(at: IndexPath(row: row, section: 0)) {

                cell.accessoryType = .none
            }
            row = row + 1
        }
    }
}
