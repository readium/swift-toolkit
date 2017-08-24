//
//  UserSettingsViewController.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 8/2/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//

import UIKit

protocol UserSettingsDelegate {
    func fontSizeUpdated(to: Int)
}

class UserSettingsViewController: UIViewController {
    let stackView: UIStackView!
    let fontSizeSlider: UISlider!
    
    init(frame: CGRect) {
        stackView = UIStackView(frame: frame)
        fontSizeSlider = UISlider(frame: CGRect(origin: CGPoint.zero,
                                                size: CGSize(width: 100, height: 50)))
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        stackView.axis = .vertical
        stackView.distribution = .fill //.spacing stuff
        stackView.spacing = 10
        stackView.autoresizingMask = [.flexibleHeight, .flexibleWidth]

//        stackView.addArrangedSubview()

        view.addSubview(stackView)

    }
}
