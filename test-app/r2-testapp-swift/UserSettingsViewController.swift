//
//  UserSettingsViewController.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 8/2/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//


import UIKit
import R2Navigator

protocol UserSettingsDelegate: class {
    func fontSizeDidChange(to value: String)
    func appearanceDidChange(to appearance: UserSettings.Appearance)
    func scrollDidChange(to scroll: UserSettings.Scroll)
    func publisherSettingsDidChange(to state: Bool)
    func getFontSelectionViewController() -> FontSelectionViewController
    func getAdvancedSettingsViewController() -> AdvancedSettingsViewController
}

class UserSettingsViewController: UIViewController {
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var defaultSwitch: UISwitch!

    @IBOutlet weak var fontSizeMinusButton: UIButton!
    @IBOutlet weak var fontSizePlusButton: UIButton!
    @IBOutlet weak var fontSelectionButton: UIButton!
    @IBOutlet weak var advancedSettingsButton: UIButton!
    @IBOutlet weak var appearanceSegmentedControl: UISegmentedControl!
    @IBOutlet weak var scrollSwitch: UISwitch!
    weak var delegate: UserSettingsDelegate?
    weak var userSettings: UserSettings?

    let maxFontSize: Float = 250.0
    let minFontSize: Float = 75.0
    let fontSizeStep: Float = 12.5

    override func viewDidLoad() {
        initializeControlsValues()
    }

    override func viewDidAppear(_ animated: Bool) {
        // Update brightness slider in case the user modified it in the OS.
        brightnessSlider.value = Float(UIScreen.main.brightness)
    }

    @IBAction func brightnessDidChange() {
        let brightness = brightnessSlider.value

        UIScreen.main.brightness = CGFloat(brightness)
    }

    @IBAction func defaultSwitched() {
        let state = defaultSwitch.isOn

        delegate?.publisherSettingsDidChange(to: state)
    }

    @IBAction func decreaseFontSizeTapped() {
        guard let currentFontSize = userSettings?.value(forKey: .fontSize),
            let currentFontSizeFloat = Float(currentFontSize),
            currentFontSizeFloat > minFontSize  else {
                return
        }
        let newFontSize = currentFontSizeFloat - fontSizeStep // Font Size Step.

        switchOffPublisherSettingsIfNeeded()
        delegate?.fontSizeDidChange(to: String(newFontSize))
    }

    @IBAction func increaseFontSizeTapped() {
        guard let currentFontSize = userSettings?.value(forKey: .fontSize),
            let currentFontSizeFloat = Float(currentFontSize),
            currentFontSizeFloat < maxFontSize  else {
                return
        }
        let newFontSize = currentFontSizeFloat + fontSizeStep // Font Size Step.

        switchOffPublisherSettingsIfNeeded()
        delegate?.fontSizeDidChange(to: String(newFontSize))
    }

    @IBAction func appearanceDidChange(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard let appearance = UserSettings.Appearance(rawValue: index) else {
            return
        }
        switchOffPublisherSettingsIfNeeded()
        delegate?.appearanceDidChange(to: appearance)
    }

    @IBAction func fontSelectionTapped() {
        guard let fsvc = delegate?.getFontSelectionViewController() else {
            return
        }
        switchOffPublisherSettingsIfNeeded()
        present(fsvc, animated: true, completion: nil)
    }

    @IBAction func advancedSettingsTapped() {
        guard let asvc = delegate?.getAdvancedSettingsViewController() else {
            return
        }
        switchOffPublisherSettingsIfNeeded()
        present(asvc, animated: true, completion: nil)
    }

    @IBAction func scrollSwitched() {
        let scroll = (scrollSwitch.isOn ? UserSettings.Scroll.on : UserSettings.Scroll.off)

        delegate?.scrollDidChange(to: scroll)
    }
}

extension UserSettingsViewController {

    fileprivate func initializeControlsValues() {
        /// Appearance SegmentedControl.
        if let initialAppearance = userSettings?.value(forKey: .appearance) {
            let appearance = UserSettings.Appearance.init(with: initialAppearance)

            appearanceSegmentedControl.selectedSegmentIndex = appearance.rawValue
        }
        // Publisher setting switch.
        if let publisherSettings = userSettings?.value(forKey: .publisherSettings) {
            let state = Bool.init(publisherSettings) ?? false

            defaultSwitch.isOn = state
        }

        // Scroll switch.
        if let initialScroll = userSettings?.value(forKey: .scroll) {
            let scroll = UserSettings.Scroll.init(with: initialScroll)

            scrollSwitch.setOn(scroll.bool(), animated: false)
        }
    }

    internal func switchOffPublisherSettingsIfNeeded() {
        if defaultSwitch.isOn {
            defaultSwitch.setOn(false, animated: true)
            delegate?.publisherSettingsDidChange(to: false)
        }
    }
}

