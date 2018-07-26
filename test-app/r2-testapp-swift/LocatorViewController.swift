//
//  LocatorViewController.swift
//  r2-testapp-swift
//
//  Created by Senda Li on 2018/7/26.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import Foundation
import UIKit

class LocatorViewController: UIViewController {
    lazy var segment:UISegmentedControl = {
        let array = ["Contents", "Bookmarks"]
        let result = UISegmentedControl(items: array)
        result.backgroundColor = UIColor.clear
        result.addTarget(self, action: #selector(segementSelected), for: UIControlEvents.valueChanged)
        result.translatesAutoresizingMaskIntoConstraints = false
        result.tintColor = UIColor.lightGray
        self.view.addSubview(result)
        
        if #available(iOS 11, *) {
            let area = self.view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                result.topAnchor.constraint(equalTo: area.topAnchor),
                result.leadingAnchor.constraint(equalTo: area.leadingAnchor),
                result.heightAnchor.constraint(equalToConstant: 44),
                result.trailingAnchor.constraint(equalTo: area.trailingAnchor)
                ])
        } else {
            let area:UIView = self.view
            NSLayoutConstraint.activate([
                result.topAnchor.constraint(equalTo: area.topAnchor),
                result.leadingAnchor.constraint(equalTo: area.leadingAnchor),
                result.heightAnchor.constraint(equalToConstant: 44),
                result.trailingAnchor.constraint(equalTo: area.trailingAnchor)
                ])
        }
        return result
    } ()
    
    private var tocVC: TableOfContentsTableViewController?
    private var bookmarkVC: BookmarkViewController?
    
    func setContent(tocVC:TableOfContentsTableViewController, bookmarkVC:BookmarkViewController) {
        self.tocVC = tocVC
        self.bookmarkVC = bookmarkVC
        self.segment.selectedSegmentIndex = 0
        self.segementSelected(sender: self.segment)
    }
    
    lazy var containerView:UIView = {
        let result = UIView()
        result.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(result)
        result.backgroundColor = UIColor.red
        
        if #available(iOS 11, *) {
            let area = self.view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                result.topAnchor.constraint(equalTo: self.segment.bottomAnchor),
                result.leadingAnchor.constraint(equalTo: area.leadingAnchor),
                result.trailingAnchor.constraint(equalTo: area.trailingAnchor),
                result.bottomAnchor.constraint(equalTo: area.bottomAnchor)
                ])
        } else {
            let area:UIView = self.view
            NSLayoutConstraint.activate([
                result.topAnchor.constraint(equalTo: self.segment.bottomAnchor),
                result.leadingAnchor.constraint(equalTo: area.leadingAnchor),
                result.trailingAnchor.constraint(equalTo: area.trailingAnchor),
                result.bottomAnchor.constraint(equalTo: area.bottomAnchor)
                ])
        }
        return result
    } ()
    
    @objc func segementSelected(sender:UISegmentedControl) {
        
        guard let childVC:UIViewController = {
            if sender.selectedSegmentIndex == 0 {
                return self.tocVC
            } else {
                return self.bookmarkVC
            }
            } () else {return}
        self.containerView.subviews.forEach { (subview) in
            subview.removeFromSuperview()
        }
        childVC.view.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        childVC.view.frame = containerView.bounds
        self.containerView.addSubview(childVC.view)
        childVC.didMove(toParentViewController: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
    }
}
