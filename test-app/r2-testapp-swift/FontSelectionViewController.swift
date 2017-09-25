//
//  FontSelectionTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/20/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Navigator

protocol FontSelectionDelegate {
    func currentFont() -> UserSettings.Font?
    func fontDidChange(to font: UserSettings.Font)
}

class FontSelectionViewController: UIViewController {
    @IBOutlet weak var fontTableView: UITableView!
    var delegate: FontSelectionDelegate?

    override func viewDidLoad() {
        fontTableView.delegate = self
        fontTableView.dataSource = self

        if let initialFont = delegate?.currentFont() {
            let index = IndexPath.init(row: initialFont.rawValue, section: 0)

            fontTableView.selectRow(at: index, animated: false, scrollPosition: .none)
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
        delegate?.fontDidChange(to: font)
    }
}
