//
//  AdvancedSettingsViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 9/20/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import R2Navigator

let pageMarginsStepValue: Double = 0.25

protocol AdvancedSettingsDelegate: class {
    func wordSpacingDidChange(to wordSpacing: UserSettings.WordSpacing)
    func letterSpacingDidChange(to letterSpacing: UserSettings.LetterSpacing)
    func columnCountDidChange(to columnCount: UserSettings.ColumnCount)
    func incrementPageMargins()
    func decrementPageMargins()
    func updatePageMarginsLabel()
}

class AdvancedSettingsViewController: UIViewController {
    @IBOutlet weak var pageMarginsLabel: UILabel!
    weak var delegate: AdvancedSettingsDelegate?

    override func viewDidAppear(_ animated: Bool) {
        delegate?.updatePageMarginsLabel()
    }

    @IBAction func backTapped() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func wordSpacingValueChanged(_ sender: UISegmentedControl) {
        let segmentIndex = sender.selectedSegmentIndex

        guard let wordSpacing = UserSettings.WordSpacing.init(rawValue: segmentIndex) else {
            return
        }
        delegate?.wordSpacingDidChange(to: wordSpacing)
    }

    @IBAction func letterSpacingValueChanged(_ sender: UISegmentedControl) {
        let segmentIndex = sender.selectedSegmentIndex

        guard let letterSpacing = UserSettings.LetterSpacing.init(rawValue: segmentIndex) else {
            return
        }
        delegate?.letterSpacingDidChange(to: letterSpacing)
    }

    @IBAction func columnCountValueChanged(_ sender: UISegmentedControl) {
        let segmentIndex = sender.selectedSegmentIndex
        
        guard let columnCount = UserSettings.ColumnCount.init(rawValue: segmentIndex) else {
            return
        }
        delegate?.columnCountDidChange(to: columnCount)
    }

    @IBAction func pageMarginsPlusTapped() {
        delegate?.incrementPageMargins()
        delegate?.updatePageMarginsLabel()
    }

    @IBAction func pageMarginsMinusTapped() {
        delegate?.decrementPageMargins()
        delegate?.updatePageMarginsLabel()
    }

    public func updatePageMargins(value: Double) {
        pageMarginsLabel.text = String.init(describing: value)
    }

}

