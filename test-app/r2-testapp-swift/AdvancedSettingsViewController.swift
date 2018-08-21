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

protocol AdvancedSettingsDelegate: class {
    
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
        view.pin(to: stackView)
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
        switchOffPublisherSettingsIfNeeded()
    }
}

public extension UIView {
    public func pin(to view: UIView) {
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: view.leadingAnchor),
            trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topAnchor.constraint(equalTo: view.topAnchor),
            bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
    }
}
