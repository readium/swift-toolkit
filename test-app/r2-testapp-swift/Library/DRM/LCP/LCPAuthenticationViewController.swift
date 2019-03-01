//
//  LCPAuthenticationViewController.swift
//  r2-testapp-swift
//
//  Created by Mickaël Menu on 01.03.19.
//
//  Copyright 2019 Readium Foundation. All rights reserved.
//  Use of this source code is governed by a BSD-style license which is detailed
//  in the LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import ReadiumLCP


protocol LCPAuthenticationDelegate: AnyObject {
    
    func authenticate(_ license: LCPAuthenticatedLicense, with passphrase: String)
    func didCancelAuthentication(of license: LCPAuthenticatedLicense)

}

class LCPAuthenticationViewController: UIViewController {
    
    weak var delegate: LCPAuthenticationDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var passphraseField: UITextField!

    private let license: LCPAuthenticatedLicense
    private let reason: LCPAuthenticationReason
    
    init(license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason) {
        self.license = license
        self.reason = reason
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var provider = license.document.provider
        if let providerHost = URL(string: provider)?.host {
            provider = providerHost
        }
        
        switch reason {
        case .passphraseNotFound:
            titleLabel.text = "Passphrase Required"
        case .invalidPassphrase:
            titleLabel.text = "Incorrect Passphrase"
            passphraseField.layer.borderWidth = 1
            passphraseField.layer.borderColor = UIColor.red.cgColor
        }
        
        messageLabel.text = "In order to open it, we need to know the passphrase required by: \(provider).\nTo help you remember it, the following hint is available."
        hintLabel.text = license.hint
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        passphraseField.becomeFirstResponder()
    }

    @IBAction func authenticate(_ sender: Any) {
        let passphrase = passphraseField.text ?? ""
        delegate?.authenticate(license, with: passphrase)
        dismiss(animated: true)
    }
    
    @IBAction func cancel(_ sender: Any) {
        delegate?.didCancelAuthentication(of: license)
        dismiss(animated: true)
    }
    
    @IBAction func showHintLink(_ sender: Any) {
        guard let href = license.hintLink?.href, let url = URL(string: href) else {
            return
        }
        UIApplication.shared.openURL(url)
    }

}


extension LCPAuthenticationViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        authenticate(textField)
        return false
    }
    
}
