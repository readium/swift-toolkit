//
//  OPDSGroupTableViewCell.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 24/04/2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared
import Kingfisher

class OPDSGroupTableViewCell: UITableViewCell {

    var group: Group?
    weak var opdsRootTableViewController: OPDSRootTableViewController?
    weak var collectionView: UICollectionView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        collectionView?.setContentOffset(.zero, animated: false)
        collectionView?.reloadData()
    }

}

extension OPDSGroupTableViewCell: UICollectionViewDataSource {
    
    // MARK: - Collection view data source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return group?.publications.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        self.collectionView = collectionView
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "opdsPublicationCollectionViewCell",
                                                      for: indexPath) as! OPDSGroupCollectionViewCell
        
        if let publication = group?.publications[indexPath.row] {
            
            cell.accessibilityLabel = publication.metadata.title
            
            let titleTextView = OPDSPlaceholderListView(frame: cell.frame,
                                                        title: publication.metadata.title,
                                                        author: publication.metadata.authors.map({$0.name ?? ""}).joined(separator: ", "))
            
            var coverURL: URL?
            if publication.coverLink != nil {
                coverURL = publication.uriTo(link: publication.coverLink)
            } else if publication.images.count > 0 {
                coverURL = URL(string: publication.images[0].absoluteHref!)
            }
            
            if let coverURL = coverURL {
                cell.imageView.kf.setImage(with: coverURL,
                                           placeholder: titleTextView,
                                           options: [.transition(ImageTransition.fade(0.5))],
                                           progressBlock: nil,
                                           completionHandler: nil)
            }
            
            cell.titleLabel.text = publication.metadata.title
            cell.authorLabel.text = publication.metadata.authors.map({$0.name ?? ""}).joined(separator: ", ")
            
        }
        
        return cell
    }
    
}

extension OPDSGroupTableViewCell: UICollectionViewDelegateFlowLayout {
    
    // MARK: - Collection view delegate
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let itemsInset: CGFloat = 5
        let itemHeight = collectionView.bounds.height - 2 * itemsInset
        let itemWidth = itemHeight / 1.5
        
        return CGSize(width: itemWidth, height: itemHeight)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let publication = group?.publications[indexPath.row] {
            let opdsStoryboard = UIStoryboard(name: "OPDS", bundle: nil)
            let opdsPublicationInfoViewController =
                opdsStoryboard.instantiateViewController(withIdentifier: "opdsPublicationInfoViewController") as? OPDSPublicationInfoViewController
            if let opdsPublicationInfoViewController = opdsPublicationInfoViewController {
                opdsPublicationInfoViewController.publication = publication
                opdsRootTableViewController?.navigationController?.pushViewController(opdsPublicationInfoViewController, animated: true)
            }
        }
    }
    
}
