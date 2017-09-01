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
    func fontDidChange(to font: UserSettings.Font)
    func appearanceDidChange(to appearance: UserSettings.Appearance)
}

class UserSettingsViewController: UIViewController {
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var appearanceSegmentedControl: UISegmentedControl!
    @IBOutlet weak var fontPickerView: UIPickerView!
    weak var delegate: UserSettingsDelegate?
    weak var userSettings: UserSettings?

    let maxFontSize: Float = 200.0
    let minFontSize: Float = 50.0
    let fontSizeStep: Float = 12.5

    override func viewDidLoad() {
        initializeControlsValues()
    }

    fileprivate func initializeControlsValues() {
        /// Appearance SegmentedControl.
        if let initialAppearance = userSettings?.value(forKey: .appearance) {
            let appearance = UserSettings.Appearance.init(with: initialAppearance)

            appearanceSegmentedControl.selectedSegmentIndex = appearance.rawValue
        }

        /// Font  PickerView.
        fontPickerView.dataSource = self
        fontPickerView.delegate = self
        if let initialFont = userSettings?.value(forKey: .font) {
            let font = UserSettings.Font.init(with: initialFont)

            fontPickerView.selectRow(font.rawValue, inComponent: 0, animated: false)
        }
    }

    @IBAction func brightnessDidChanged(_ sender: UISlider) {
        let brightness = brightnessSlider.value

        UIScreen.main.brightness = CGFloat(brightness)
    }

    @IBAction func decreaseFontSizeTapped() {
        guard let currentFontSize = userSettings?.value(forKey: .fontSize),
            let currentFontSizeFloat = Float(currentFontSize),
            currentFontSizeFloat > minFontSize  else {
                return
        }
        let newFontSize = currentFontSizeFloat - fontSizeStep // Font Size Step.

        delegate?.fontSizeDidChange(to: String(newFontSize))
    }

    @IBAction func increaseFontSize() {
        guard let currentFontSize = userSettings?.value(forKey: .fontSize),
            let currentFontSizeFloat = Float(currentFontSize),
            currentFontSizeFloat < maxFontSize  else {
                return
        }
        let newFontSize = currentFontSizeFloat + fontSizeStep // Font Size Step.

        delegate?.fontSizeDidChange(to: String(newFontSize))
    }

    @IBAction func appearanceDidChange(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        guard let appearance = UserSettings.Appearance(rawValue: index) else {
            return
        }
        delegate?.appearanceDidChange(to: appearance)
    }
}

extension UserSettingsViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let font = UserSettings.Font(rawValue: row) else {
            return
        }
        delegate?.fontDidChange(to: font)
    }
}

extension UserSettingsViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return UserSettings.Font.allValues.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return UserSettings.Font(rawValue: row)?.name()
    }
}
