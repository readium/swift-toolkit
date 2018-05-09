//
//  OPDSPublicationTableViewCell.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 23/04/2018.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import R2Shared
import Kingfisher

class OPDSPublicationTableViewCell: UITableViewCell {
    
    var feed: Feed?
    weak var opdsRootTableViewController: OPDSRootTableViewController?

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}

extension OPDSPublicationTableViewCell: UICollectionViewDataSource {
    
    // MARK: - Collection view data source
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return feed?.publications.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "opdsPublicationCollectionViewCell",
                                                      for: indexPath) as! OPDSPublicationCollectionViewCell
        
        if let publications = feed?.publications, let publication = feed?.publications[indexPath.row] {
            
            cell.accessibilityLabel = publication.metadata.title

            var coverURL: URL?
            if publication.coverLink != nil {
                coverURL = publication.uriTo(link: publication.coverLink)
            } else if publication.images.count > 0 {
                coverURL = URL(string: publication.images[0].absoluteHref!)
            }
            
            if let coverURL = coverURL {
                cell.imageView.kf.setImage(with: coverURL,
                                           placeholder: nil,
                                           options: [.transition(ImageTransition.fade(0.5))],
                                           progressBlock: nil,
                                           completionHandler: nil)
            }
            
            cell.titleLabel.text = publication.metadata.title
            cell.authorLabel.text = publication.metadata.authors.map({$0.name ?? ""}).joined(separator: ", ")
            
            if indexPath.row == publications.count - 3 {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
                opdsRootTableViewController?.loadNextPage(completionHandler: { (feed) in
                    self.feed = feed
                    collectionView.reloadData()
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                })
            }
            
        }
        
        return cell
    }
    
}

extension OPDSPublicationTableViewCell: UICollectionViewDelegateFlowLayout {
    
    // MARK: - Collection view delegate
    
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let itemsRatio: CGFloat = 3
        let itemsInset: CGFloat = 5
        let labelsHeight: CGFloat = 40
        let itemWidth = (collectionView.bounds.width / itemsRatio) - (itemsRatio * 2 * itemsInset)
        let itemHeight = (itemWidth * 1.5) + labelsHeight

        return CGSize(width: itemWidth, height: itemHeight)

    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let publication = feed?.publications[indexPath.row] {
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
