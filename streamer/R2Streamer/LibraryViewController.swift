//
//  RootViewController.swift
//  R2Streamer
//
//  Created by Olivier Körner on 28/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import UIKit

class LibraryViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var publications: [RDPublication] = [RDPublication]()
    var tableView: UITableView?
    
    init(publications: [RDPublication]) {
        super.init(nibName: nil, bundle: nil)
        self.publications = publications
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(nibName: nil, bundle: nil)
    }
    
    
    override func loadView() {
        self.view = UIView()
        view.backgroundColor = UIColor.red
        
        tableView = UITableView(frame: self.view.frame)
        tableView?.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.register(UITableViewCell.self, forCellReuseIdentifier: "LibraryCell")
        view.addSubview(tableView!)
        
        title = "Library"
    }
    
    override func viewDidLoad() {
        tableView?.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return publications.count
        }
        return 0
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LibraryCell")
        let publication = publications[indexPath.row]
        cell?.textLabel?.text = publication.metadata.title
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let publication = publications[indexPath.row]
        let spineViewController = SpineViewController(publication: publication)
        navigationController?.pushViewController(spineViewController, animated: true)
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
