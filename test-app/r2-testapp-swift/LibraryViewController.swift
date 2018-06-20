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
import Kingfisher
import PromiseKit
import ReadiumOPDS

/// To modify depending of the profile of the liblcp.a used
let supportedProfiles = ["http://readium.org/lcp/basic-profile",
                         "http://readium.org/lcp/profile-1.0"]

protocol LibraryViewControllerDelegate: class {
    func loadPublication(withId id: String?, completion: @escaping (Drm?, Error?) -> Void) throws
    func remove(_ publication: Publication)
}

class LibraryViewController: UICollectionViewController {
    var publications: [Publication]!
    weak var delegate: LibraryViewControllerDelegate?
    weak var lastFlippedCell: PublicationCell?
    
    lazy var loadingIndicator = PublicationIndicator()

  override func loadView() {
    // What is the reason creating another flowLayout?
    // What is the reason creating another collectionView?
    // Why not use the build in properites from UICollectionViewController?
    let flowLayout = UICollectionViewFlowLayout()
    let collectionView = UICollectionView(frame: UIScreen.main.bounds,
                                          collectionViewLayout: flowLayout)
    
    collectionView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    collectionView.contentInset = UIEdgeInsets(top: 15, left: 20,
                                               bottom: 20, right: 20)
    collectionView.register(PublicationCell.self,
                            forCellWithReuseIdentifier: "publicationCell")
    collectionView.delegate = self
    
    self.collectionView = collectionView
    view = collectionView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    
    let appDelegate = UIApplication.shared.delegate as! AppDelegate
    
    delegate = appDelegate

    publications = appDelegate.items.compactMap() { $0.value.0.publication }.sorted { (pA, pB) -> Bool in
          pA.metadata.title < pB.metadata.title
      }

    appDelegate.libraryViewController = self
    
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
  
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)
    collectionView?.collectionViewLayout.invalidateLayout()
  }
  
  enum GeneralScreenOrientation: String {
    case landscape
    case portrait
  }
  
  static let iPadLayoutNumberPerRow:[GeneralScreenOrientation: Int] = [.portrait: 4, .landscape: 5]
  static let iPhoneLayoutNumberPerRow:[GeneralScreenOrientation: Int] = [.portrait: 3, .landscape: 4]
  
  static let layoutNumberPerRow:[UIUserInterfaceIdiom:[GeneralScreenOrientation: Int]] = [
    .pad : LibraryViewController.iPadLayoutNumberPerRow,
    .phone : LibraryViewController.iPhoneLayoutNumberPerRow
  ]
  
  private var previousScreenOrientation: GeneralScreenOrientation?
  
  override func viewWillLayoutSubviews() {
    super.viewWillLayoutSubviews()
    
    let idiom = { () -> UIUserInterfaceIdiom in
      let tempIdion = UIDevice.current.userInterfaceIdiom
      return (tempIdion != .pad) ? .phone:.pad // ignnore carplay and others
    } ()
    
    let orientation = { () -> GeneralScreenOrientation in
      let deviceOrientation = UIDevice.current.orientation
      
      switch deviceOrientation {
      case .unknown, .portrait, .portraitUpsideDown:
        return GeneralScreenOrientation.portrait
      case .landscapeLeft, .landscapeRight:
        return GeneralScreenOrientation.landscape
      case .faceUp, .faceDown:
        return previousScreenOrientation ?? .portrait
      }
    } ()
    
    var layoutNumberPerRow:[UIUserInterfaceIdiom:[GeneralScreenOrientation: Int]] = [
        .pad : LibraryViewController.iPadLayoutNumberPerRow,
        .phone : LibraryViewController.iPhoneLayoutNumberPerRow
    ]
    
    previousScreenOrientation = orientation
    
    guard let deviceLayoutNumberPerRow = layoutNumberPerRow[idiom] else {return}
    guard let numberPerRow = deviceLayoutNumberPerRow[orientation] else {return}
    
    guard let flowLayout = self.collectionView?.collectionViewLayout as? UICollectionViewFlowLayout else {return}
    let contentWith = collectionView?.collectionViewLayout.collectionViewContentSize.width ?? 0
    
    let minimumSpacing = CGFloat(5)
    let width = (contentWith - CGFloat(numberPerRow-1) * minimumSpacing) / CGFloat(numberPerRow)
    let height = width * 1.5 // Height/width ratio == 1.5
    
    flowLayout.minimumLineSpacing = minimumSpacing * 2
    flowLayout.minimumInteritemSpacing = minimumSpacing
    flowLayout.itemSize = CGSize(width: width, height: height)
  }
}

// MARK: - Misc.
extension LibraryViewController {

    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
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
    
    let publication = publications[indexPath.item]
    
    cell.delegate = self
    cell.accessibilityLabel = publication.metadata.title
    
    let updateCellImage = { (theImage: UIImage) -> Void in
      let currentPubInfo = self.publications[indexPath.item]
      if (currentPubInfo.coverLink === publication.coverLink) {
        cell.imageView.image = theImage
        cell.applyShadows()
      }
    }
    
    // Load image and then apply the shadow.
    if let coverUrl = publication.uriTo(link: publication.coverLink) {
      
      let cacheKey = coverUrl.absoluteString
      if (ImageCache.default.imageCachedType(forKey: cacheKey).cached) {
        
        ImageCache.default.retrieveImage(forKey: cacheKey, options: nil) {
          image, cacheType in
          if let theImage = image {
            updateCellImage(theImage)
          } else {
            print("Not exist in cache.")
          }
        }
        
      } else {
        
        ImageDownloader.default.downloadImage(with: coverUrl, options: [], progressBlock: nil) { (image, error, url, data) in
            if error != nil {
                let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
                let textView = self.defaultCover(layout: flowLayout, publication: publication)
                cell.imageView.image = UIImage.imageWithTextView(textView: textView)
                cell.applyShadows()
            } else {
                guard let newImage = image else {return}
                ImageCache.default.store(newImage, forKey: cacheKey)
                updateCellImage(newImage)
            }
        }
      } // check cache
      
    } else {
      
      let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
      let textView = defaultCover(layout: flowLayout, publication: publication)
      cell.imageView.image = UIImage.imageWithTextView(textView: textView)
      cell.applyShadows()
    }
    
    return cell
  }
    
  internal func defaultCover(layout: UICollectionViewFlowLayout?, publication: Publication) -> UITextView {
    let width = layout?.itemSize.width ?? 0
    let height = layout?.itemSize.height ?? 0
    let titleTextView = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: height))

    titleTextView.layer.borderWidth = 5.0
    titleTextView.layer.borderColor = #colorLiteral(red: 0.08269290555, green: 0.2627741129, blue: 0.3623990017, alpha: 1).cgColor
    titleTextView.backgroundColor = #colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1)
    titleTextView.textColor = #colorLiteral(red: 0.8639426257, green: 0.8639426257, blue: 0.8639426257, alpha: 1)
    titleTextView.text = publication.metadata.title.appending("\n_________") //Dirty styling.
        
    return titleTextView
  }

  override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
    let publication = publications[indexPath.row]
    
    guard let cell = collectionView.cellForItem(at: indexPath) else {return}
    cell.contentView.addSubview(self.loadingIndicator)
    collectionView.isUserInteractionEnabled = false
    
    let cleanup = {
      self.loadingIndicator.removeFromSuperview()
      collectionView.isUserInteractionEnabled = true
    }
    
    let successCallback = { (contentVC: UIViewController) in
      cleanup()
      let backItem = UIBarButtonItem()
      backItem.title = ""
      self.navigationItem.backBarButtonItem = backItem
      self.navigationController?.pushViewController(contentVC, animated: true)
    }
    
    let failCallback = { (message: String?) in
      cleanup()
      guard let failMessage = message else {return}
      self.infoAlert(title: "Error", message: failMessage)
    }
    
    loadPublication(publication: publication, success: successCallback, fail: failCallback)
  }
  
  func loadPublication(publication: Publication,
                       success: ((UIViewController)->Void)? = nil,
                       fail: ((String?) -> Void)? = nil) {
    
    // Get publication type
    let publicationType = PublicationType(rawString: publication.internalData["type"])
    
    switch publicationType {
    case .cbz:
      let cbzViewer = CbzViewController(for: publication, initialIndex: 0)
      success?(cbzViewer)
    case .epub:
      guard let publicationIdentifier = publication.metadata.identifier else {
        fail?("Invalid EPUB file")
        return
      }
      // Retrieve last read document/progression in that document.
      let userDefaults = UserDefaults.standard
      let index = userDefaults.integer(forKey: "\(publicationIdentifier)-document")
      let progression = userDefaults.double(forKey: "\(publicationIdentifier)-documentProgression")
      do {
        // Ask delegate to load that document.
        try delegate?.loadPublication(withId: publicationIdentifier, completion: { drm, error in
          // Check if profile is supported.
          
          if let _ = error {
            fail?(nil) // slient error
            return
          }
          
          if let profile = drm?.profile, !supportedProfiles.contains(profile) {
            let message = "The profile of this DRM is not supported."
            fail?(message)
            return
          }
          
          let epubViewer = EpubViewController(with: publication,
                                              atIndex: index,
                                              progression: progression, drm)
          epubViewer.hidesBottomBarWhenPushed = true
          success?(epubViewer)
        })
      } catch {
        fail?(error.localizedDescription)
      }
    default:
      fail?("Unsupported format")
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
      //self.collectionView.deleteItems(at: [indexPath])
        self.collectionView?.performBatchUpdates({
            self.collectionView?.reloadData()
        }, completion: nil)
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

class PublicationIndicator: UIView  {
  
  lazy var indicator: UIActivityIndicatorView =  {
    
    let result = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.whiteLarge)
    result.translatesAutoresizingMaskIntoConstraints = false
    self.backgroundColor = UIColor(white: 0.3, alpha: 0.7)
    self.addSubview(result)
    
    let horizontalConstraint = NSLayoutConstraint(item: result, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0)
    let verticalConstraint = NSLayoutConstraint(item: result, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0.0)
    self.addConstraints([horizontalConstraint, verticalConstraint])
    
    return result
  } ()
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    
    guard let superView = self.superview else {return}
    self.translatesAutoresizingMaskIntoConstraints = false
    
    let horizontalConstraint = NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal, toItem: superView, attribute: .centerX, multiplier: 1.0, constant: 0.0)
    let verticalConstraint = NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: superView, attribute: .centerY, multiplier: 1.0, constant: 0.0)
    let widthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: superView, attribute: .width, multiplier: 1.0, constant: 0.0)
    let heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: superView, attribute: .height, multiplier: 1.0, constant: 0.0)
    
    superView.addConstraints([horizontalConstraint, verticalConstraint, widthConstraint, heightConstraint])
    
    self.indicator.startAnimating()
  }
  
  override func removeFromSuperview() {
    self.indicator.stopAnimating()
    super.removeFromSuperview()
  }
}
