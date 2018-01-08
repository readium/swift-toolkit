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

let bookPerRow = 3
let insets = 5 // In px.

let supportedProfiles = ["http://readium.org/lcp/basic-profile"]

protocol LibraryViewControllerDelegate: class {
    func loadPublication(withId id: String?, completion: @escaping (Drm?) -> Void) throws
    func remove(_ publication: Publication)
}

class LibraryViewController: UICollectionViewController {
    var publications: [Publication]
    weak var delegate: LibraryViewControllerDelegate?
    weak var lastFlippedCell: PublicationCell?

    init?(_ publications: [Publication]) {
        self.publications = publications
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let flowLayout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: UIScreen.main.bounds,
                                              collectionViewLayout: flowLayout)
        let layout = (collectionView.collectionViewLayout as! UICollectionViewFlowLayout)

        collectionView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        collectionView.contentInset = UIEdgeInsets(top: 15, left: 20,
                                                   bottom: 20, right: 20)
        collectionView.register(PublicationCell.self,
                                forCellWithReuseIdentifier: "publicationCell")
        collectionView.delegate = self
        let width = (Int(UIScreen.main.bounds.width) / bookPerRow) - (bookPerRow * 2 * insets)
        let height = Int(Double(width) * 1.5) // Height/width ratio == 1.5
        layout.itemSize = CGSize(width: width, height: height)
        self.collectionView = collectionView
        view = collectionView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        clearsSelectionOnViewWillAppear = true
        installsStandardGestureForInteractiveMovement = false
        // Add long press gesture recognizer.
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))

        recognizer.minimumPressDuration = 0.5
        recognizer.delaysTouchesBegan = true
        collectionView?.addGestureRecognizer(recognizer)
        collectionView?.accessibilityLabel = "Library"
    }

    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        lastFlippedCell?.flipMenu()
        super.viewWillDisappear(animated)
    }
}

// MARK: - Misc.
extension LibraryViewController {

    func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if (gestureRecognizer.state != UIGestureRecognizerState.began) {
            return
        }
        let location = gestureRecognizer.location(in: collectionView)
        if let indexPath = collectionView?.indexPathForItem(at: location) {
            let cell = collectionView?.cellForItem(at: indexPath) as! PublicationCell

            cell.flipMenu()
        }
    }
}

// MARK: - CollectionView Datasource.
extension LibraryViewController: UICollectionViewDelegateFlowLayout {
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
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "publicationCell", for: indexPath) as! PublicationCell
        let publication = publications[indexPath.row]

        cell.delegate = self
        cell.accessibilityLabel = publication.metadata.title
        // Load image and then apply the shadow.
        if let coverUrl = publication.uriTo(link: publication.coverLink) {
            cell.imageView.kf.setImage(with: coverUrl, placeholder: nil,
                                       options: [.transition(ImageTransition.fade(0.5))],
                                       progressBlock: nil, completionHandler: { error in
                                        cell.applyShadows()
            })
        } else {
            let width = (Int(UIScreen.main.bounds.width) / bookPerRow) - (bookPerRow * 2 * insets)
            let height = Int(Double(width) * 1.5) // Height/width ratio == 1.5
            let titleTextView = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: height))

            titleTextView.layer.borderWidth = 5.0
            titleTextView.layer.borderColor = #colorLiteral(red: 0.08269290555, green: 0.2627741129, blue: 0.3623990017, alpha: 1).cgColor
            titleTextView.backgroundColor = #colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1)
            titleTextView.textColor = #colorLiteral(red: 0.8639426257, green: 0.8639426257, blue: 0.8639426257, alpha: 1)
            titleTextView.text = publication.metadata.title.appending("\n_________") //Dirty styling.
            cell.imageView.image = UIImage.imageWithTextView(textView: titleTextView)
            cell.applyShadows()
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

        // Get publication type.
        guard let publicationType = publication.internalData["type"] else {
            return
        }
        let backItem = UIBarButtonItem()

        backItem.title = ""
        navigationItem.backBarButtonItem = backItem
        // Instanciate and push the appropriated renderer.
        switch publicationType {
        case "cbz":
            let cbzViewer = CbzViewController(for: publication, initialIndex: 0)

            navigationController?.pushViewController(cbzViewer, animated: true)
        case "epub":
            guard let publicationIdentifier = publication.metadata.identifier else {
                return
            }
            // Retrieve last read document/progression in that document.
            let userDefaults = UserDefaults.standard
            let index = userDefaults.integer(forKey: "\(publicationIdentifier)-document")
            let progression = userDefaults.double(forKey: "\(publicationIdentifier)-documentProgression")
            do {
                // Ask delegate to load that document.
                try delegate?.loadPublication(withId: publicationIdentifier, completion: { drm in
                    // Check if profile is supported.
                    if let profile = drm?.profile, !supportedProfiles.contains(profile) {
                        self.infoAlert(title: "Error", message: "The profile of this DRM is not supported.")
                        return
                    }
                    let epubViewer = EpubViewController(with: publication,
                                                        atIndex: index,
                                                        progression: progression, drm)

                    self.navigationController?.pushViewController(epubViewer, animated: true)

                })
            } catch {
                infoAlert(title: "Error", message: error.localizedDescription)
            }
        default:
            break
        }
    }

    internal func infoAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let dismissButton = UIAlertAction(title: "Ok", style: .cancel)

        alert.addAction(dismissButton)
        // Present alert.
        present(alert, animated: true)
    }
}

extension LibraryViewController: PublicationCellDelegate {

    func removePublicationFromLibrary(forCellAt indexPath: IndexPath) {
        let removePublicationAlert = UIAlertController(title: "Are you sure?",
                                                       message: "This will remove the Publication from your library.",
                                                       preferredStyle: UIAlertControllerStyle.alert)
        let removeAction = UIAlertAction(title: "Remove", style: .destructive, handler: { alert in
            // Remove the publication from publicationServer and Documents folder.
            self.delegate?.remove(self.publications[indexPath.row])
            // Remove item from UI colletionView.
            self.collectionView?.deleteItems(at: [indexPath])
        })
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: { alert in
            return
        })

        removePublicationAlert.addAction(removeAction)
        removePublicationAlert.addAction(cancelAction)
        present(removePublicationAlert, animated: true, completion: nil)
    }

    func displayInformation(forCellAt indexPath: IndexPath) {
        
        let storyboard = UIStoryboard(name: "Details", bundle: nil)
        let detailsView = storyboard.instantiateViewController(withIdentifier: "DetailsTableViewController") as! DetailsTableViewController
        let publication = publications[indexPath.row]

        detailsView.setup(publication: publication)
        navigationController?.pushViewController(detailsView, animated: true)
    }
    
    func cellFlipped(_ cell: PublicationCell) {
        lastFlippedCell?.flipMenu()
        lastFlippedCell = cell
    }
}


