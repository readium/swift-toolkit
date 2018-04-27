//
//  AboutTableViewController.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 27/04/2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit

class AboutTableViewController: UITableViewController {

    @IBOutlet weak var versionNumberCell: UITableViewCell!
    @IBOutlet weak var buildNumberCell: UITableViewCell!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            versionNumberCell.textLabel?.text = "Version \(version)"
            buildNumberCell.textLabel?.text = "Build \(build)"
        } else {
            versionNumberCell.textLabel?.text = "Version unknown"
            buildNumberCell.textLabel?.text = "Build unknown"
        }
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var url: URL?
        
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                url = URL(string: "https://www.edrlab.org/")
            } else {
                url = URL(string: "https://opensource.org/licenses/BSD-3-Clause")
            }
        } else if indexPath.section == 2 {
            if indexPath.row == 0 {
                url = URL(string: "http://www.centrenationaldulivre.fr/")
            }
        }
        
        if let url = url {
            UIApplication.shared.openURL(url)
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }

    /*
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)

         Configure the cell...

        return cell
    }
    */

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
