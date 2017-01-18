//
//  SpineItemViewController.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import UIKit
import WebKit


class SpineItemViewController: UIViewController {
    
    var webView: WKWebView?
    var spineItemURL: URL?
    
    init(spineItemURL: URL) {
        super.init(nibName: nil, bundle: nil)
        self.spineItemURL = spineItemURL
        title = spineItemURL.lastPathComponent
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        super.loadView()
        
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: view.bounds, configuration: config)
        webView?.navigationDelegate = self
        view.addSubview(webView!)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSLog("webView loading \(spineItemURL)")
        let _ = webView?.load(URLRequest(url: spineItemURL!))
    }
}


extension SpineItemViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("SpineItemWebView navigation failed \(error)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        NSLog("SpineItemWebView provisional navigation failed \(error)")
    }
}
