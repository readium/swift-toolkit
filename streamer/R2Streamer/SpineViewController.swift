//
//  SpineViewController.swift
//  R2Streamer
//
//  Created by Olivier Körner on 27/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import UIKit


class SpineViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var publication: RDPublication?
    var tableView: UITableView?
    
    init(publication: RDPublication) {
        super.init(nibName: nil, bundle: nil)
        self.publication = publication
        title = publication.metadata.title
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(nibName: nil, bundle: nil)
    }
    
    override func loadView() {
        self.view = UIView()
        
        tableView = UITableView(frame: self.view.frame)
        tableView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.register(UITableViewCell.self, forCellReuseIdentifier: "SpineItemCell")
        view.addSubview(tableView!)
    }
    
    override func viewDidLoad() {
        tableView?.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let publication = publication {
            return publication.spine.count
        }
        return 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if publication != nil {
            return 1
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpineItemCell")
        let spineLink = publication!.spine[indexPath.item]
        cell?.textLabel?.text = spineLink.href
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let spineItem = publication!.spine[indexPath.item]
        let selfLink = publication?.link(withRel: "self")
        let selfLinkHref = selfLink?.href
        let pubURL = URL(string: selfLinkHref!)?.deletingLastPathComponent()
        let spineItemViewController = SpineItemViewController(spineItemURL: pubURL! .appendingPathComponent(spineItem.href!))
        
        navigationController?.pushViewController(spineItemViewController, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
}
