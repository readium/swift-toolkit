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
    
    func publisherSettingsDidChange(to state: Bool)
    
    func textAlignementDidChange(to textAlignement: UserSettings.TextAlignement)
    func columnCountDidChange(to columnCount: UserSettings.ColumnCount)

    func incrementWordSpacing()
    func decrementWordSpacing()
    func updateWordSpacingLabel()

    func incrementLetterSpacing()
    func decrementLetterSpacing()
    func updateLetterSpacingLabel()

    func incrementPageMargins()
    func decrementPageMargins()
    func updatePageMarginsLabel()
}

class AdvancedSettingsViewController: UIViewController {
    
    @IBOutlet weak var defaultSwitch: UISwitch!
    
    @IBOutlet weak var wordSpacingLabel: UILabel!
    @IBOutlet weak var letterSpacingLabel: UILabel!
    @IBOutlet weak var pageMarginsLabel: UILabel!
    weak var delegate: AdvancedSettingsDelegate?
    weak var userSettings: UserSettings?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        delegate?.updateWordSpacingLabel()
        delegate?.updatePageMarginsLabel()
        delegate?.updateLetterSpacingLabel()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        if let ppc = popoverPresentationController  {
            let preferredSize = self.preferredContentSize
            self.navigationController?.preferredContentSize = CGSize.zero
            self.navigationController?.preferredContentSize = preferredSize
            ppc.preferredContentSizeDidChange(forChildContentContainer: self)
        }
        
        // Publisher setting switch.
        if let publisherSettings = userSettings?.value(forKey: .publisherSettings) {
            let state = Bool.init(publisherSettings) ?? false
            defaultSwitch.isOn = state
        }
    }
    
    /// Publisher's default
    
    @IBAction func defaultSwitched() {
        let state = defaultSwitch.isOn
        delegate?.publisherSettingsDidChange(to: state)
    }
    
    internal func switchOffPublisherSettingsIfNeeded() {
        if defaultSwitch.isOn {
            defaultSwitch.setOn(false, animated: true)
            delegate?.publisherSettingsDidChange(to: false)
        }
    }

    /// Text alignement.

    @IBAction func textAlignementValueChanged(_ sender: UISegmentedControl) {
            let segmentIndex = sender.selectedSegmentIndex

        guard let textAlignement = UserSettings.TextAlignement.init(rawValue: segmentIndex) else {
                return
            }
            delegate?.textAlignementDidChange(to: textAlignement)
        
        switchOffPublisherSettingsIfNeeded()
    }

    /// Word Spacing.

    @IBAction func wordSpacingPlusTapped() {
        delegate?.incrementWordSpacing()
        delegate?.updateWordSpacingLabel()
        switchOffPublisherSettingsIfNeeded()
    }

    @IBAction func wordSpacingMinusTapped() {
        delegate?.decrementWordSpacing()
        delegate?.updateWordSpacingLabel()
        switchOffPublisherSettingsIfNeeded()
    }

    public func updateWordSpacing(value: String) {
        wordSpacingLabel.text = value
    }

    /// Letter spacing.

    @IBAction func letterSpacingPlusTapped() {
        delegate?.incrementLetterSpacing()
        delegate?.updateLetterSpacingLabel()
        switchOffPublisherSettingsIfNeeded()
    }

    @IBAction func letterSpacingMinusTapped() {
        delegate?.decrementLetterSpacing()
        delegate?.updateLetterSpacingLabel()
        switchOffPublisherSettingsIfNeeded()
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
        switchOffPublisherSettingsIfNeeded()
    }

    @IBAction func pageMarginsPlusTapped() {
        delegate?.incrementPageMargins()
        delegate?.updatePageMarginsLabel()
        switchOffPublisherSettingsIfNeeded()
    }

    @IBAction func pageMarginsMinusTapped() {
        delegate?.decrementPageMargins()
        delegate?.updatePageMarginsLabel()
        switchOffPublisherSettingsIfNeeded()
    }

    public func updatePageMargins(value: String) {
        pageMarginsLabel.text = value
    }
}

