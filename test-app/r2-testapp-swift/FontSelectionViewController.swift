//
//  FontSelectionTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/20/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Navigator

protocol FontSelectionDelegate: class {
    func currentFont() -> UserSettings.Font?
    func fontDidChange(to font: UserSettings.Font)

}

class FontSelectionViewController: UIViewController {
    @IBOutlet weak var fontTableView: UITableView!
    weak var delegate: FontSelectionDelegate?

    override func viewDidLoad() {
        fontTableView.delegate = self
        fontTableView.dataSource = self
    }

    override func viewDidAppear(_ animated: Bool) {
        if let initialFont = delegate?.currentFont() {
            let index = IndexPath.init(row: initialFont.rawValue, section: 0)
            fontTableView.cellForRow(at: index)?.accessoryType = .checkmark
        }
    }

    @IBAction func backTapped() {
        dismiss(animated: true, completion: nil)
    }
}

extension FontSelectionViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return UserSettings.Font.allValues.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fontTableViewCell")!
        let fontName = UserSettings.Font(rawValue: indexPath.row)?.name() ?? "Error"

        cell.textLabel?.text = fontName
        return cell
    }
}

extension FontSelectionViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let font = UserSettings.Font(rawValue: indexPath.row) else {
            return
        }
        let cell = tableView.cellForRow(at: indexPath)

        uncheckAllRows()
        cell?.accessoryType = .checkmark
        delegate?.fontDidChange(to: font)
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
