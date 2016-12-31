//
//  SpineItemViewController.swift
//  R2Streamer
//
//  Created by Olivier Körner on 14/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import UIKit

class SpineItemViewController: UIViewController, UIWebViewDelegate {
    
    var webView: UIWebView?
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
        
        webView = UIWebView(frame: view.bounds)
        webView?.delegate = self
        view.addSubview(webView!)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        NSLog("webView loading \(spineItemURL)")
        webView?.loadRequest(URLRequest(url: spineItemURL!))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        NSLog("webView didFailLoadWithError \(error)")
    }
}

