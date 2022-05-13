//
//  Copyright 2020 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import SafariServices
import UIKit

final class LCPDialogViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var promptLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var passphraseField: UITextField!
    @IBOutlet weak var supportButton: UIButton!
    @IBOutlet weak var forgotPassphraseButton: UIButton!
    @IBOutlet weak var continueButton: UIButton!
 
    private let license: LCPAuthenticatedLicense
    private let reason: LCPAuthenticationReason
    private let completion: (String?) -> Void
    private let supportLinks: [(Link, URL)]
    
    init(license: LCPAuthenticatedLicense, reason: LCPAuthenticationReason, completion: @escaping (String?) -> Void) {
        self.license = license
        self.reason = reason
        self.completion = completion
        self.supportLinks = license.supportLinks
            .compactMap { link -> (Link, URL)? in
                guard let url = URL(string: link.href), UIApplication.shared.canOpenURL(url) else {
                    return nil
                }
                return (link, url)
            }

        super.init(nibName: nil, bundle: Bundle.module)

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
        
        if #available(iOS 13.0, *) {
            // Prevents swipe down to dismiss the dialog on iOS 13+
            isModalInPresentation = true
        }
        
        var provider = license.document.provider
        if let providerHost = URL(string: provider)?.host {
            provider = providerHost
        }
        
        supportButton.isHidden = supportLinks.isEmpty

        let label = UILabel()

        switch reason {
        case .passphraseNotFound:
            label.text = R2LCPLocalizedString("dialog.reason.passphraseNotFound")
        case .invalidPassphrase:
            label.text = R2LCPLocalizedString("dialog.reason.invalidPassphrase")
            passphraseField.layer.borderWidth = 1
            passphraseField.layer.borderColor = UIColor.red.cgColor
        }
      
        label.sizeToFit()
        if #available(iOS 13.0, *) {
            label.textColor = .label
            navigationController?.navigationBar.backgroundColor = .systemBackground
        }
        
        let leftItem = UIBarButtonItem(customView: label)
        self.navigationItem.leftBarButtonItem = leftItem

        promptLabel.text = R2LCPLocalizedString("dialog.prompt.message1")
        messageLabel.text = String(format: R2LCPLocalizedString("dialog.prompt.message2"), provider)
        forgotPassphraseButton.setTitle(R2LCPLocalizedString("dialog.prompt.forgotPassphrase"), for: .normal)
        supportButton.setTitle(R2LCPLocalizedString("dialog.prompt.support"), for: .normal)
        continueButton.setTitle(R2LCPLocalizedString("dialog.prompt.continue"), for: .normal)
        passphraseField.placeholder = R2LCPLocalizedString("dialog.prompt.passphrase")
        hintLabel.text = license.hint
      
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(LCPDialogViewController.cancel(_:))
        )
    }

    @IBAction func authenticate(_ sender: Any) {
        let passphrase = passphraseField.text ?? ""
        complete(with: passphrase)
    }
    
    @IBAction func cancel(_ sender: Any) {
        complete(with: nil)
    }
    
    private var isCompleted = false
    
    private func complete(with passphrase: String?) {
        guard !isCompleted else {
            return
        }
        isCompleted = true
        completion(passphrase)
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
                        return R2LCPLocalizedString("dialog.support.website")
                    case "tel":
                        return R2LCPLocalizedString("dialog.support.phone")
                    case "mailto":
                        return R2LCPLocalizedString("dialog.support.mail")
                    default:
                        break
                    }
                }
                return R2LCPLocalizedString("dialog.support")
            }()
            
            let action = UIAlertAction(title: title, style: .default) { _ in
                open(url)
            }
            alert.addAction(action)
        }
        alert.addAction(UIAlertAction(title: R2LCPLocalizedString("dialog.cancel"), style: .cancel))

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


extension LCPDialogViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        authenticate(textField)
        return false
    }
    
}
