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
    func incrementWordSpacing()
    func decrementWordSpacing()
    func updateWordSpacingLabel()

    func incrementLetterSpacing()
    func decrementLetterSpacing()
    func updateLetterSpacingLabel()

    func columnCountDidChange(to columnCount: UserSettings.ColumnCount)

    func incrementPageMargins()
    func decrementPageMargins()
    func updatePageMarginsLabel()
}

class AdvancedSettingsViewController: UIViewController {
    @IBOutlet weak var wordSpacingLabel: UILabel!
    @IBOutlet weak var letterSpacingLabel: UILabel!
    @IBOutlet weak var pageMarginsLabel: UILabel!
    weak var delegate: AdvancedSettingsDelegate?

    override func viewDidAppear(_ animated: Bool) {
        delegate?.updateWordSpacingLabel()
        delegate?.updatePageMarginsLabel()
        delegate?.updateLetterSpacingLabel()
    }

    @IBAction func backTapped() {
        dismiss(animated: true, completion: nil)
    }

    /// Word Spacing.

    @IBAction func wordSpacingPlusTapped() {
        delegate?.incrementWordSpacing()
        delegate?.updateWordSpacingLabel()
    }

    @IBAction func wordSpacingMinusTapped() {
        delegate?.decrementWordSpacing()
        delegate?.updateWordSpacingLabel()
    }

    public func updateWordSpacing(value: String) {
        wordSpacingLabel.text = value
    }

    /// Letter spacing.

    @IBAction func letterSpacingPlusTapped() {
        delegate?.incrementLetterSpacing()
        delegate?.updateLetterSpacingLabel()
    }

    @IBAction func letterSpacingMinusTapped() {
        delegate?.decrementLetterSpacing()
        delegate?.updateLetterSpacingLabel()
    }

    public func updateLetterSpacing(value: String) {
        letterSpacingLabel.text = value
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

    public func updatePageMargins(value: String) {
        pageMarginsLabel.text = value
    }

}

