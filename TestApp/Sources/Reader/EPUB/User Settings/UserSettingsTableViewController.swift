//
//  UserSettingsTableViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 8/2/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//


import UIKit
import R2Navigator
import R2Shared

protocol UserSettingsDelegate: AnyObject {
    func fontSizeDidChange(increase: Bool)
    func appearanceDidChange(to appearanceIndex: Int)
    func scrollModeDidChange()
    func getFontSelectionViewController() -> FontSelectionViewController
    func getAdvancedSettingsViewController() -> AdvancedSettingsViewController
}

class UserSettingsTableViewController: UITableViewController {
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var fontSizeMinusButton: UIButton!
    @IBOutlet weak var fontSizePlusButton: UIButton!
    @IBOutlet weak var fontSelectionButton: UIButton!
    @IBOutlet weak var selectedFontLabel: UILabel!
    @IBOutlet weak var advancedSettingsButton: UIButton!
    @IBOutlet weak var appearanceSegmentedControl: UISegmentedControl!
    @IBOutlet weak var scrollSwitch: UISwitch!
    weak var delegate: UserSettingsDelegate?
    weak var userSettings: UserSettings?
    weak var publication: Publication?

    private var brightnessObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControlsValues()
        self.navigationController?.isNavigationBarHidden = true
        
        brightnessObserver = NotificationCenter.default.addObserver(forName: UIScreen.brightnessDidChangeNotification, object: nil, queue: nil) { (notification) in
            
            let brightness = Float(UIScreen.main.brightness)
            if (brightness != self.brightnessSlider.value) {
                self.brightnessSlider.value = brightness
            }
        }
        
        // Set font size variation
        if let currentFontSize = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.fontSize.rawValue) as? Incrementable {
            currentFontSize.max = 250.0
            currentFontSize.min = 75.0
            currentFontSize.step = 12.5
        }
        
        checkScrollMode()
      
      appearanceSegmentedControl.subviews[0].accessibilityLabel = NSLocalizedString("user_settings_appearance_default_a11y_label", comment: "Accessibility label for user settings appearance default")
      appearanceSegmentedControl.subviews[1].accessibilityLabel = NSLocalizedString("user_settings_appearance_sepia_a11y_label", comment: "Accessibility label for user settings appearance sepia")
      appearanceSegmentedControl.subviews[2].accessibilityLabel = NSLocalizedString("user_settings_appearance_night_a11y_label", comment: "Accessibility label for user settings appearance night")


    }
    
    func checkScrollMode() {
        if let scrollMode = publication?.userSettingsUIPreset?[.scroll] {
            scrollSwitch.isUserInteractionEnabled = false
            scrollSwitch.thumbTintColor = UIColor.gray
            scrollSwitch.tintColor = UIColor.lightGray
            scrollSwitch.onTintColor = UIColor.lightGray
            if scrollSwitch?.isOn != scrollMode {
                scrollModeSwitched()
            }
        }
    }
    
    deinit {
        if let theObserver = brightnessObserver {
            NotificationCenter.default.removeObserver(theObserver)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if let ppc = popoverPresentationController  {
            let preferredSize = self.preferredContentSize
            self.navigationController?.preferredContentSize = CGSize.zero
            self.navigationController?.preferredContentSize = preferredSize
            ppc.preferredContentSizeDidChange(forChildContentContainer: self)
        }
    }
        
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Update brightness slider in case the user modified it in the OS.
        brightnessSlider.value = Float(UIScreen.main.brightness)
        tableView.bounces = false
    }
    
    @IBAction func brightnessDidChange() {
        let brightness = brightnessSlider.value

        UIScreen.main.brightness = CGFloat(brightness)
    }

    @IBAction func decreaseFontSizeTapped() {
        delegate?.fontSizeDidChange(increase: false)
    }

    @IBAction func increaseFontSizeTapped() {
        delegate?.fontSizeDidChange(increase: true)
    }

    @IBAction func appearanceDidChange(_ sender: UISegmentedControl) {
        delegate?.appearanceDidChange(to: sender.selectedSegmentIndex)
    }

    @IBAction func fontSelectionTapped() {
        guard let fsvc = delegate?.getFontSelectionViewController() else {
            return
        }
        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(fsvc, animated: true)
    }

    @IBAction func advancedSettingsTapped() {
        guard let asvc = delegate?.getAdvancedSettingsViewController() else {
            return
        }
        let backItem = UIBarButtonItem()
        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        navigationController?.pushViewController(asvc, animated: true)
    }

    @IBAction func scrollModeSwitched() {
        delegate?.scrollModeDidChange()
    }
}

extension UserSettingsTableViewController {

    fileprivate func initializeControlsValues() {
        /// Appearance SegmentedControl.
        if let initialAppearance = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.appearance.rawValue) as? Enumerable {
            appearanceSegmentedControl.selectedSegmentIndex = initialAppearance.index
        }
        
        // Currently selected font.
        if let initialFontFamily = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.fontFamily.rawValue) as? Enumerable {
            setSelectedFontLabel(to: initialFontFamily.toString())
        }

        // Scroll switch.
        if let initialScroll = userSettings?.userProperties.getProperty(reference: ReadiumCSSReference.scroll.rawValue) as? Switchable {
            scrollSwitch.setOn(initialScroll.on, animated: false)
        }

    }

    internal func setSelectedFontLabel(to fontName: String) {
        selectedFontLabel.text = fontName
    }
}

