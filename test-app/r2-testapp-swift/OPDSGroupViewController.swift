//
//  OPDSGroupViewController.swift
//  r2-testapp-swift
//
//  Created by Nikita Aizikovskyi on Mar-23-2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared
import R2Streamer
import R2Navigator
import Kingfisher
import PromiseKit
import ReadiumOPDS

class OPDSGroupViewController: UIViewController {
    var group: Group
    var catalogViewController: OPDSCatalogViewController
    var collectionViewController: OPDSGroupCollectionViewController?
    var stackView: UIView
    init?(_ group: Group, stackView: UIView, catalogViewController: OPDSCatalogViewController) {
        self.group = group
        self.catalogViewController = catalogViewController
        self.stackView = stackView
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        //view = UIView(frame: UIScreen.main.bounds)
        view = UIView(frame: CGRect(x:100, y:0, width: stackView.frame.width, height: 100))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white
        
        let nameLabel = UILabel(frame: CGRect(x: 10, y: 10, width: 200, height: 30))
        nameLabel.text = group.metadata.title
        view.addSubview(nameLabel)

        let moreButton = UIButton(type: UIButtonType.system)
        moreButton.frame = CGRect(x: stackView.frame.width - 110, y: 10, width: 100, height: 30)
        moreButton.setTitle("More", for: UIControlState.normal)
        moreButton.addTarget(self, action: #selector(moreButtonPressed), for: UIControlEvents.touchUpInside)
        view.addSubview(moreButton)

        let collectionViewFrame = CGRect(x:0, y:50, width:stackView.frame.width, height: 100)
        collectionViewController = OPDSGroupCollectionViewController(group.publications, frame: collectionViewFrame, catalogViewController: catalogViewController)
        view.addSubview(collectionViewController!.view)
    }

    @objc func moreButtonPressed(sender: Any) {
        if self.group.links.count == 0 {
            return
        }
        let opdsCatalog = OPDSCatalogViewController(url: URL(string: self.group.links[0].href!)!)
        self.catalogViewController.navigationController?.pushViewController(opdsCatalog!, animated: true)
    }

}
