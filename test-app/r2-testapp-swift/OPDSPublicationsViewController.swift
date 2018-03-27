//
//  LibraryViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 8/24/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import UIKit
import WebKit
import R2Shared
import R2Streamer
import R2Navigator
//import ReadiumLCP
import Kingfisher
import PromiseKit
import ReadiumOPDS

let opdsBookPerRow = 3
let opdsInsets = 5 // In px.

protocol OPDSPublicationsViewControllerDelegate: class {
    func remove(_ publication: Publication)
    func loadPublication(withId id: String?, completion: @escaping () -> Void) throws
}

class OPDSPublicationsViewController: UICollectionViewController {
    var publications: [Publication]
    var viewFrame: CGRect
    var catalogViewController: OPDSCatalogViewController
    weak var delegate: OPDSPublicationsViewControllerDelegate?

    init?(_ publications: [Publication], frame: CGRect, catalogViewController: OPDSCatalogViewController) {
        self.publications = publications
        self.viewFrame = frame
        self.catalogViewController = catalogViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        //view = UIView(frame: UIScreen.main.bounds)
        view = UIView(frame: self.viewFrame)
        view.autoresizesSubviews = true
        //let flowFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height-44)
        //let flowFrame = CGRect(x: 0, y: 0, width: self.viewFrame.width, height: self.viewFrame.height-44)

        let flowLayout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: view.bounds,
                                              collectionViewLayout: flowLayout)
        let layout = (collectionView.collectionViewLayout as! UICollectionViewFlowLayout)

        collectionView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        collectionView.contentInset = UIEdgeInsets(top: 15, left: 20,
                                                   bottom: 20, right: 20)
        collectionView.register(OPDSPublicationCell.self, forCellWithReuseIdentifier: "opdsPublicationCell")
        collectionView.delegate = self
        let width = (Int(UIScreen.main.bounds.width) / opdsBookPerRow) - (opdsBookPerRow * 2 * opdsInsets)
        let height = Int(Double(width) * 1.5) // Height/width ratio == 1.5
        layout.itemSize = CGSize(width: width, height: height)
        self.collectionView = collectionView
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(collectionView)


    }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        collectionView?.accessibilityLabel = "Catalog"
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        super.viewWillDisappear(animated)
    }
}

// MARK: - CollectionView Datasource.
extension OPDSPublicationsViewController: UICollectionViewDelegateFlowLayout {
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // No data to display.
        if publications.count == 0 {
            let noPublicationLabel = UILabel(frame: collectionView.frame)

            noPublicationLabel.text = "📖 Open EPUB/CBZ file to import"
            noPublicationLabel.textColor = UIColor.gray
            noPublicationLabel.textAlignment = .center
            collectionView.backgroundView = noPublicationLabel
        }
        return publications.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "opdsPublicationCell", for: indexPath) as! OPDSPublicationCell
        let publication = publications[indexPath.row]

        cell.accessibilityLabel = publication.metadata.title
        // Load image and then apply the shadow.
        var coverUrl: URL? = nil
        if publication.coverLink != nil {
            coverUrl = publication.uriTo(link: publication.coverLink)
        }
        else if publication.images.count > 0 {
            coverUrl = URL(string: publication.images[0].href!)
        }
        if coverUrl != nil {
            cell.imageView!.kf.setImage(with: coverUrl, placeholder: nil,
                                       options: [.transition(ImageTransition.fade(0.5))],
                                       progressBlock: nil, completionHandler: { error in
                                        cell.applyShadows()
            })
        } else {
            let width = (Int(UIScreen.main.bounds.width) / opdsBookPerRow) - (opdsBookPerRow * 2 * opdsInsets)
            let height = Int(Double(width) * 1.5) // Height/width ratio == 1.5
            let titleTextView = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: height))

            titleTextView.layer.borderWidth = 5.0
            titleTextView.layer.borderColor = #colorLiteral(red: 0.08269290555, green: 0.2627741129, blue: 0.3623990017, alpha: 1).cgColor
            titleTextView.backgroundColor = #colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1)
            titleTextView.textColor = #colorLiteral(red: 0.8639426257, green: 0.8639426257, blue: 0.8639426257, alpha: 1)
            titleTextView.text = publication.metadata.title.appending("\n_________") //Dirty styling.
            cell.imageView!.image = UIImage.imageWithTextView(textView: titleTextView)
            cell.applyShadows()
        }
        cell.infoViewController.titleLabel.text = publication.metadata.title
        cell.infoViewController.authorLabel.text = publication.metadata.authors.map({$0.name ?? ""}).joined(separator: ", ")

        if indexPath.row == publications.count - 1 && !catalogViewController.isLoadingNextPage {
            // When the last cell has been reached, load the next page of the feed
            catalogViewController.loadNextPage()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        let inset = CGFloat(insets)

        return UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let publication = publications[indexPath.row]
        let publicationInfoViewController = OPDSPublicationInfoViewController(publication, catalogViewController: self.catalogViewController)
        self.catalogViewController.navigationController?.pushViewController(publicationInfoViewController!, animated: true)

    }

    func changePublications(newPublications: [Publication]) {
        self.publications = newPublications
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
}


