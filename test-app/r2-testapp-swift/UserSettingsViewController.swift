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
    func appearanceDidChange(to appearance: UserSettings.Appearances)
}

class UserSettingsViewController: UIViewController {
    let stackView: UIStackView!
    let fontSizeStepper: UIStepper!
    let appearanceSegmentedControl: UISegmentedControl!
    let userSettings: UserSettings!
    weak var delegate: UserSettingsDelegate?

    override func loadView() {
        //Stackview
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.spacing = 10
        stackView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view = stackView
    }

    init(frame: CGRect, userSettings: UserSettings) {
        stackView = UIStackView()
        fontSizeStepper = UIStepper(frame: CGRect(origin: CGPoint.zero,
                                                  size: CGSize(width: 150, height: 25)))
        appearanceSegmentedControl = UISegmentedControl(items: ["Default", "Sepia", "Night"])
        self.userSettings = userSettings
        super.init(nibName: nil, bundle: nil)
        stackView.spacing = 10
        stackView.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.addArrangedSubview(fontSizeStepper)
        stackView.addArrangedSubview(appearanceSegmentedControl)
    }

    override func viewDidAppear(_ animated: Bool) {
        /// Stepper.
        fontSizeStepper.stepValue = 12.5
        fontSizeStepper.minimumValue = 50
        fontSizeStepper.maximumValue = 250
        fontSizeStepper.addTarget(self, action: #selector(fontSizeChanged(_:)), for: .valueChanged)
        // Fetch value from userSettings if defined.
        if let initialFontSize = userSettings.getValue(forKey: .fontSize),
            let floatValue = Double(initialFontSize) {
            fontSizeStepper.value = floatValue
        } else {
            fontSizeStepper.value = 100
        }

        /// SegmentedControl.
        appearanceSegmentedControl.addTarget(self, action: #selector(appearanceChanged(_:)), for: .valueChanged)
    }

    internal func fontSizeChanged(_ sender: UIStepper) {
        delegate?.fontSizeDidChange(to: String(fontSizeStepper.value))
    }

    internal func appearanceChanged(_ sender: UISegmentedControl) {
        let index = appearanceSegmentedControl.selectedSegmentIndex
        let appearance = UserSettings.Appearances(index)

        delegate?.appearanceDidChange(to: appearance)
    }

    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
