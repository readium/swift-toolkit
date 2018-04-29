//
//  UserSettingsTableViewController.swift
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
    
    weak var popoverController: UIPopoverPresentationController?

    let maxFontSize: Float = 250.0
    let minFontSize: Float = 75.0
    let fontSizeStep: Float = 12.5
    
    private var brightnessObserver: NSObjectProtocol?

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeControlsValues()
        self.navigationController?.isNavigationBarHidden = true
        
        brightnessObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIScreenBrightnessDidChange, object: nil, queue: nil) { (notification) in
            
            let brightness = Float(UIScreen.main.brightness)
            if (brightness != self.brightnessSlider.value) {
                self.brightnessSlider.value = brightness
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
        if let ppc = popoverController  {
            let preferredSize = self.preferredContentSize
            self.navigationController?.preferredContentSize = CGSize.zero
            self.navigationController?.preferredContentSize = preferredSize
            ppc.preferredContentSizeDidChange(forChildContentContainer: self)
        }
    }
    
//    override var preferredContentSize: CGSize {
//        get {
//            return CGSize(width: 250, height: 260)
//        }
//        set { super.preferredContentSize = newValue }
//    }
    
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
        guard let currentFontSize = userSettings?.value(forKey: .fontSize),
            let currentFontSizeFloat = Float(currentFontSize),
            currentFontSizeFloat > minFontSize  else {
                return
        }
        let newFontSize = currentFontSizeFloat - fontSizeStep // Font Size Step.

        delegate?.fontSizeDidChange(to: String(newFontSize))
    }

    @IBAction func increaseFontSizeTapped() {
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
        
        asvc.popoverController = self.popoverController
        navigationController?.pushViewController(asvc, animated: true)
//        present(asvc, animated: true, completion: nil)
    }

    @IBAction func scrollSwitched() {
        let scroll = (scrollSwitch.isOn ? UserSettings.Scroll.on : UserSettings.Scroll.off)

        delegate?.scrollDidChange(to: scroll)
    }
}

extension UserSettingsTableViewController {

    fileprivate func initializeControlsValues() {
        /// Appearance SegmentedControl.
        if let initialAppearance = userSettings?.value(forKey: .appearance) {
            let appearance = UserSettings.Appearance.init(with: initialAppearance)

            appearanceSegmentedControl.selectedSegmentIndex = appearance.rawValue
        }
        
        // Currently selected font.
        if let font = userSettings?.value(forKey: .font) {
            setSelectedFontLabel(to: font)
        }

        // Scroll switch.
        if let initialScroll = userSettings?.value(forKey: .scroll) {
            let scroll = UserSettings.Scroll.init(with: initialScroll)

            scrollSwitch.setOn(scroll.bool(), animated: false)
        }

    }

    internal func setSelectedFontLabel(to fontName: String) {
        selectedFontLabel.text = fontName
    }
}

