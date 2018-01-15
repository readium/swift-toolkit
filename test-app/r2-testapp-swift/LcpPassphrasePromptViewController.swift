//
//  LcpPassphrasePromptViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 1/10/18.
//  Copyright © 2018 Readium. All rights reserved.
//

import Foundation
import UIKit

class LcpPassphrasePromptViewController: UIViewController {
    let webview = UIWebView()
    @IBOutlet weak var hintTextView: UITextView!
    @IBOutlet weak var passwordTextField: UITextField!

    @IBAction func infoLinkTapped() {
        guard let url = URL(string: "https://www.edrlab.org/readium/readium-lcp/") else {
            return
        }
        let request = URLRequest(url: url)

        webview.loadRequest(request)
    }

    @IBAction func proceedTapped() {

    }
}
