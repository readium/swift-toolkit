//
//  AdvancedSettingsViewController.swift
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

protocol AdvancedSettingsDelegate: AnyObject {
    
    func publisherSettingsDidChange()
    
    func textAlignementDidChange(to textAlignementIndex: Int)
    func columnCountDidChange(to columnCountIndex: Int)

    func incrementWordSpacing()
    func decrementWordSpacing()
    func updateWordSpacingLabel()

    func incrementLetterSpacing()
    func decrementLetterSpacing()
    func updateLetterSpacingLabel()

    func incrementPageMargins()
    func decrementPageMargins()
    func updatePageMarginsLabel()
    
    func incrementLineHeight()
    func decrementLineHeight()
    func updateLineHeightLabel()
}

class AdvancedSettingsViewController: UIViewController {
    
    @IBOutlet weak var defaultSwitch: UISwitch!
    @IBOutlet weak var alignSegment: UISegmentedControl!
    @IBOutlet weak var columnsSegment: UISegmentedControl!
    
    @IBOutlet weak var wordSpacingLabel: UILabel!
    @IBOutlet weak var letterSpacingLabel: UILabel!
    @IBOutlet weak var pageMarginsLabel: UILabel!
    @IBOutlet weak var lineHeightLabel: UILabel!
    weak var delegate: AdvancedSettingsDelegate?
    weak var userSettings: UserSettings?
    weak var publication: Publication?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        delegate?.updateWordSpacingLabel()
        delegate?.updatePageMarginsLabel()
        delegate?.updateLineHeightLabel()
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
        if let publisherDefault = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.publisherDefault.rawValue) as? Switchable {
            defaultSwitch.isOn = publisherDefault.on
        }
    }
    
    private func pinForeground(_ view: UIView, to stackView: UIStackView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        stackView.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            view.topAnchor.constraint(equalTo: stackView.topAnchor),
            view.bottomAnchor.constraint(equalTo: stackView.bottomAnchor)
        ])
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let settingsUIPreset:[ReadiumCSSName: UIView?] = [
            
            ReadiumCSSName.hyphens: nil,
            ReadiumCSSName.ligatures: nil,
            ReadiumCSSName.paraIndent: nil,
            ReadiumCSSName.columnCount: columnsSegment.superview,
            ReadiumCSSName.textAlignment: alignSegment,
            
            ReadiumCSSName.lineHeight: lineHeightLabel.superview?.superview,
            ReadiumCSSName.pageMargins: pageMarginsLabel.superview?.superview,
            ReadiumCSSName.wordSpacing: wordSpacingLabel.superview?.superview,
            ReadiumCSSName.letterSpacing: letterSpacingLabel.superview?.superview
        ]
        
        publication?.userSettingsUIPreset?.forEach({ (key, value) in
            if let theUIComponent = settingsUIPreset[key] {
                if !value {
                    let disabledColor = UIColor(white: 0.6, alpha: 0.4)
                    theUIComponent?.isUserInteractionEnabled = false
                    theUIComponent?.backgroundColor = disabledColor
                    
                    if let stack = theUIComponent as? UIStackView {
                        let foreGround = UIView()
                        foreGround.backgroundColor = disabledColor
                        pinForeground(foreGround, to: stack)
                    }
                }
            }
        })
      
      alignSegment.subviews[0].accessibilityLabel = NSLocalizedString("user_settings_alignment_justify_a11y_label", comment: "Accessibility label for user settings aligment justify")
      alignSegment.subviews[1].accessibilityLabel = NSLocalizedString("user_settings_alignment_left_a11y_label", comment: "Accessibility label for user settings aligment left")

      columnsSegment.subviews[0].accessibilityLabel = NSLocalizedString("user_settings_column_auto_a11y_label", comment: "Accessibility label for user settings columns auto")
      columnsSegment.subviews[1].accessibilityLabel = NSLocalizedString("user_settings_column_1_a11y_label", comment: "Accessibility label for user settings columns 1")
      columnsSegment.subviews[2].accessibilityLabel = NSLocalizedString("user_settings_column_2_a11y_label", comment: "Accessibility label for user settings columns 2")

    }
    
    /// Publisher's default
    
    @IBAction func defaultSwitched() {
        delegate?.publisherSettingsDidChange()
    }
    
    internal func switchOffPublisherSettingsIfNeeded() {
        if defaultSwitch.isOn {
            defaultSwitch.setOn(false, animated: true)
            delegate?.publisherSettingsDidChange()
        }
    }

    /// Text alignement.

    @IBAction func textAlignementValueChanged(_ sender: UISegmentedControl) {
        delegate?.textAlignementDidChange(to: sender.selectedSegmentIndex)
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

    /// Page margins.
    
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
    
    /// Line height.
    
    @IBAction func lineHeightPlusTapped() {
        delegate?.incrementLineHeight()
        delegate?.updateLineHeightLabel()
        switchOffPublisherSettingsIfNeeded()
    }
    
    @IBAction func lineHeightMinusTapped() {
        delegate?.decrementLineHeight()
        delegate?.updateLineHeightLabel()
        switchOffPublisherSettingsIfNeeded()
    }
    
    public func updateLineHeight(value: String) {
        lineHeightLabel.text = value
    }
    
    /// Column count.
    
    @IBAction func columnCountValueChanged(_ sender: UISegmentedControl) {
        delegate?.columnCountDidChange(to: sender.selectedSegmentIndex)
    }
}
