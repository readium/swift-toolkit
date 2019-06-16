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

#if LCP

import SafariServices
import UIKit
import ReadiumLCP


protocol LCPAuthenticationDelegate: AnyObject {
    
    func authenticate(_ license: LCPAuthenticatedLicense, with passphrase: String)
    func didCancelAuthentication(of license: LCPAuthenticatedLicense)

}

class LCPAuthenticationViewController: UIViewController {
    
    weak var delegate: LCPAuthenticationDelegate?
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var passphraseField: UITextField!
    @IBOutlet weak var supportButton: UIButton!
    
    private let license: LCPAuthenticatedLicense
    private let reason: LCPAuthenticationReason
    private let supportLinks: [(Link, URL)]
    
    init(license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason) {
        self.license = license
        self.reason = reason
        self.supportLinks = license.supportLinks
            .compactMap { link -> (Link, URL)? in
                guard let url = URL(string: link.href), UIApplication.shared.canOpenURL(url) else {
                    return nil
                }
                return (link, url)
            }

        super.init(nibName: nil, bundle: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        var provider = license.document.provider
        if let providerHost = URL(string: provider)?.host {
            provider = providerHost
        }
        
        supportButton.isHidden = supportLinks.isEmpty

        let label = UILabel()

        switch reason {
        case .passphraseNotFound:
            label.text = NSLocalizedString("lcp_passphraseNotFound_message", comment: "Reason to ask for the passphrase when it was not found ")
        case .invalidPassphrase:
            label.text = NSLocalizedString("lcp_invalidPassphrase_message", comment: "Reason to ask for the passphrase when the one entered was incorrect")
            passphraseField.layer.borderWidth = 1
            passphraseField.layer.borderColor = UIColor.red.cgColor
        }
      
        label.sizeToFit()
        let leftItem = UIBarButtonItem(customView: label)
        self.navigationItem.leftBarButtonItem = leftItem

        promptLabel.text = NSLocalizedString("lcp_prompt_message1", comment: "Prompt message when asking for the passphrase")
        messageLabel.text = String(format: NSLocalizedString("lcp_prompt_message2", comment: "More instructions about the passphrase"), provider)
        hintLabel.text = license.hint
      
        let cancelItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(LCPAuthenticationViewController.cancel(_:)));
        navigationItem.rightBarButtonItem = cancelItem;
      
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
    
    @IBAction func showSupportLink(_ sender: Any) {
        guard !supportLinks.isEmpty else {
            return
        }
        
        func open(_ url: URL) {
            if #available(iOS 10, *) {
                UIApplication.shared.open(url)
            } else {
                UIApplication.shared.openURL(url)
            }
        }
        
        if let (_, url) = supportLinks.first, supportLinks.count == 1 {
            open(url)
            return
        }
        
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        for (link, url) in supportLinks {
            let title: String = {
                if let title = link.title {
                    return title
                }
                if let scheme = url.scheme {
                    switch scheme {
                    case "http", "https":
                        return NSLocalizedString("lcp_support_website", comment: "Contact the support through a website")
                    case "tel":
                        return NSLocalizedString("lcp_support_phone", comment: "Contact the support by phone")
                    case "mailto":
                        return NSLocalizedString("lcp_support_mail", comment: "Contact the support by mail")
                    default:
                        break
                    }
                }
                return NSLocalizedString("lcp_support_button", comment: "Button to contact the support when entering the passphrase")
            }()
            
            let action = UIAlertAction(title: title, style: .default) { _ in
                open(url)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel opening the LCP protected publication"), style: .cancel))

        if let popover = alert.popoverPresentationController, let sender = sender as? UIView {
            popover.sourceView = sender
            var rect = sender.bounds
            rect.origin.x = sender.center.x - 1
            rect.size.width = 2
            popover.sourceRect = rect
        }
        present(alert, animated: true)
    }
    
    @IBAction func showHintLink(_ sender: Any) {
        guard let href = license.hintLink?.href, let url = URL(string: href) else {
            return
        }
        
        let browser = SFSafariViewController(url: url)
        browser.modalPresentationStyle = .currentContext
        present(browser, animated: true)
    }
    
    /// Makes sure the form contents in scrollable when the keyboard is visible.
    @objc func keyboardWillChangeFrame(_ note: Notification) {
        guard let window = UIApplication.shared.keyWindow, let scrollView = scrollView, let scrollViewSuperview = scrollView.superview, let info = note.userInfo else {
            return
        }

        var keyboardHeight: CGFloat = 0
        if note.name == UIResponder.keyboardWillChangeFrameNotification {
            guard let keyboardFrame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
                return
            }
            keyboardHeight = keyboardFrame.height
        }
        
        // Calculates the scroll view offsets in the coordinate space of of our window
        let scrollViewFrame = scrollViewSuperview.convert(scrollView.frame, to: window)

        var contentInset = scrollView.contentInset
        // Bottom inset is the part of keyboard that is covering the tableView
        contentInset.bottom = keyboardHeight - (window.frame.height - scrollViewFrame.height - scrollViewFrame.origin.y) + 16

        self.scrollView.contentInset = contentInset
        self.scrollView.scrollIndicatorInsets = contentInset
    }

}


extension LCPAuthenticationViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        authenticate(textField)
        return false
    }
    
}

#endif
