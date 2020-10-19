//
//  LibraryViewController.swift
//  r2-testapp-swift
//
//  Created by Alexandre Camilleri on 8/24/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit
import MobileCoreServices
import WebKit
import R2Shared
import R2Streamer
import R2Navigator
import Kingfisher
import ReadiumOPDS


protocol LibraryViewControllerFactory {
    func make() -> LibraryViewController
}

class LibraryViewController: UIViewController, Loggable {
    
    typealias Factory = DetailsTableViewControllerFactory
    
    var factory: Factory!
    private var books: [Book]!
    
    weak var lastFlippedCell: PublicationCollectionViewCell?
    
    var library: LibraryService! {
        didSet {
            oldValue?.delegate = nil
            library.delegate = self
        }
    }
    
    weak var libraryDelegate: LibraryModuleDelegate?
    
    lazy var loadingIndicator = PublicationIndicator()
    
    private var downloadSet =  NSMutableOrderedSet()
    private var downloadTaskToRatio = [URLSessionDownloadTask:Float]()
    private var downloadTaskDescription = [URLSessionDownloadTask:String]()
    private lazy var addBookButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBook))
    
    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            // The contentInset of collectionVIew might be changed by iOS 9/10.
            // This property has been set as false on storyboard.
            // In case it's changed by mistake somewhere, set it again here.
            self.automaticallyAdjustsScrollViewInsets = false
            
            collectionView.backgroundColor = #colorLiteral(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
            collectionView.contentInset = UIEdgeInsets(top: 15, left: 20,
                                                       bottom: 20, right: 20)
            collectionView.register(UINib(nibName: "PublicationCollectionViewCell", bundle: nil),
                                    forCellWithReuseIdentifier: "publicationCollectionViewCell")
            collectionView.delegate = self
            collectionView.dataSource = self
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        books = try! BooksDatabase.shared.books.all()
        
        // Add long press gesture recognizer.
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        
        recognizer.minimumPressDuration = 0.5
        recognizer.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(recognizer)
        collectionView.accessibilityLabel = NSLocalizedString("library_a11y_label", comment: "Accessibility label for the library collection view")
        
        DownloadSession.shared.displayDelegate = self
        
        self.navigationItem.rightBarButtonItem = addBookButton
        
        navigationController?.navigationBar.tintColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
        navigationController?.navigationBar.barTintColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        lastFlippedCell?.flipMenu()
        super.viewWillDisappear(animated)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        collectionView.collectionViewLayout.invalidateLayout()
    }

    static let iPadLayoutNumberPerRow:[ScreenOrientation: Int] = [.portrait: 4, .landscape: 5]
    static let iPhoneLayoutNumberPerRow:[ScreenOrientation: Int] = [.portrait: 3, .landscape: 4]
    
    static let layoutNumberPerRow:[UIUserInterfaceIdiom:[ScreenOrientation: Int]] = [
        .pad : LibraryViewController.iPadLayoutNumberPerRow,
        .phone : LibraryViewController.iPhoneLayoutNumberPerRow
    ]
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        
        let idiom = { () -> UIUserInterfaceIdiom in
            let tempIdion = UIDevice.current.userInterfaceIdiom
            return (tempIdion != .pad) ? .phone:.pad // ignnore carplay and others
        } ()
        
        let layoutNumberPerRow:[UIUserInterfaceIdiom:[ScreenOrientation: Int]] = [
            .pad : LibraryViewController.iPadLayoutNumberPerRow,
            .phone : LibraryViewController.iPhoneLayoutNumberPerRow
        ]

        guard let deviceLayoutNumberPerRow = layoutNumberPerRow[idiom] else {return}
        guard let numberPerRow = deviceLayoutNumberPerRow[.current] else {return}
        
        guard let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {return}
        let contentWith = collectionView.collectionViewLayout.collectionViewContentSize.width
        
        let minimumSpacing = CGFloat(5)
        let width = (contentWith - CGFloat(numberPerRow-1) * minimumSpacing) / CGFloat(numberPerRow)
        let height = width * 1.9
        
        flowLayout.minimumLineSpacing = minimumSpacing * 2
        flowLayout.minimumInteritemSpacing = minimumSpacing
        flowLayout.itemSize = CGSize(width: width, height: height)
    }
    
    @objc func addBook() {
        let alert = UIAlertController(title: NSLocalizedString("library_add_book_title", comment: "Title for the Add book alert"), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("library_add_book_from_device_button", comment: "`Add a book from your device` button"), style: .default, handler: { _ in self.addBookFromDevice() }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("library_add_book_from_url_button", comment: "`Add a book from a URL` button"), style: .default, handler: { _ in self.addBookFromURL() }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel adding a book from a URL"), style: .cancel))
        alert.popoverPresentationController?.barButtonItem = addBookButton
        present(alert, animated: true)
    }
    
    private func addBookFromDevice() {
        var utis = DocumentTypes.main.supportedUTIs
        utis.append(String(kUTTypeText))
        let documentPicker = UIDocumentPickerViewController(documentTypes: utis, in: .import)
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    private func addBookFromURL(url: String? = nil, message: String? = nil) {
        let alert = UIAlertController(
            title: NSLocalizedString("library_add_book_from_url_title", comment: "Title for the `Add book from URL` alert"),
            message: message,
            preferredStyle: .alert
        )
        
        func retry(message: String? = nil) {
            addBookFromURL(url: alert.textFields?[0].text, message: message)
        }
        
        func add(_ action: UIAlertAction) {
            let optionalURLString = alert.textFields?[0].text
            guard let urlString = optionalURLString,
                let url = URL(string: urlString) else
            {
                retry(message: NSLocalizedString("library_add_book_from_url_failure_message", comment: "Error message when trying to add a book from a URL"))
                return
            }
            
            func tryAdd(from url: URL) {
                library.importPublication(from: url, sender: self) { result in
                    if case .failure(let error) = result {
                        retry(message: error.localizedDescription)
                    }
                }
            }

            let hideActivity = toastActivity(on: view)
            OPDSParser.parseURL(url: url) { data, _ in
                DispatchQueue.main.async {
                    hideActivity()

                    if let downloadLink = data?.publication?.downloadLinks.first, let downloadURL = URL(string: downloadLink.href) {
                        tryAdd(from: downloadURL)
                    } else {
                        tryAdd(from: url)
                    }
                }
            }
        }
        
        alert.addTextField { textField in
            textField.placeholder = NSLocalizedString("library_add_book_from_url_placeholder", comment: "Placeholder for the URL field in the `Add book from URL` alert")
            textField.text = url
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("add_button", comment: "Add a book from a URL button"), style: .default, handler: add))
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel adding a boom from a URL button"), style: .cancel))
        present(alert, animated: true, completion: nil)
    }
    
}

extension LibraryViewController {
    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if (gestureRecognizer.state != UIGestureRecognizer.State.began) {
            return
        }
        
        let location = gestureRecognizer.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: location) {
            if indexPath.item < downloadSet.count {return}
            let cell = collectionView.cellForItem(at: indexPath) as! PublicationCollectionViewCell
            cell.flipMenu()
        }
    }
}

// MARK: - UIDocumentPickerDelegate.
extension LibraryViewController: UIDocumentPickerDelegate {

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard controller.documentPickerMode == .import else {
            return
        }
        library.importPublications(from: urls, sender: self) { result in
            if case .failure(let error) = result {
                self.libraryDelegate?.presentError(error, from: self)
            }
        }
    }
    
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        library.importPublication(from: url, sender: self) { result in
            if case .failure(let error) = result {
                self.libraryDelegate?.presentError(error, from: self)
            }
        }
    }
    
}

// MARK: - CollectionView Datasource.
extension LibraryViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // No data to display.
        if downloadSet.count == 0 && books.count == 0 {
            let noPublicationLabel = UILabel(frame: collectionView.frame)
            
            noPublicationLabel.text = NSLocalizedString("library_empty_message", comment: "Hint message when the library is empty")
            noPublicationLabel.textColor = UIColor.gray
            noPublicationLabel.textAlignment = .center
            collectionView.backgroundView = noPublicationLabel
            
            return 0
        } else {
            collectionView.backgroundView = nil
            return downloadSet.count + books.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "publicationCollectionViewCell", for: indexPath) as! PublicationCollectionViewCell
        cell.coverImageView.image = nil
        cell.progress = 0
        
        cell.isAccessibilityElement = true
        cell.accessibilityHint = NSLocalizedString("library_publication_a11y_hint", comment: "Accessibility hint for the publication collection cell")

        if indexPath.item < downloadSet.count {
            guard let task = downloadSet.object(at: indexPath.item) as? URLSessionDownloadTask else {return cell}
            if let ratio = downloadTaskToRatio[task] {
                cell.progress = ratio
            }
            
            let downloadDescription = downloadTaskDescription[task] ?? "..."
            let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
            let textView = defaultCover(layout: flowLayout, description: downloadDescription)
            cell.coverImageView.image = UIImage.imageWithTextView(textView: textView)
            cell.accessibilityLabel = nil
            cell.titleLabel.text = nil
            cell.authorLabel.text = nil
            
            return cell
        }
        
        let offset = indexPath.item-downloadSet.count
        let book = books[offset]
        
        cell.delegate = self
        cell.accessibilityLabel = book.title
        cell.titleLabel.text = book.title
        cell.authorLabel.text = book.author
        
        // Load image and then apply the shadow.
        if let cover = book.cover {
            cell.coverImageView.image = UIImage(data: cover)
        } else {
            
            let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
            let description = book.title
            let textView = defaultCover(layout: flowLayout, description:description)
            cell.coverImageView.image = UIImage.imageWithTextView(textView: textView)
        }
        
        return cell
    }
    
    internal func defaultCover(layout: UICollectionViewFlowLayout?, description: String) -> UITextView {
        let width = layout?.itemSize.width ?? 0
        let height = layout?.itemSize.height ?? 0
        let titleTextView = UITextView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        
        titleTextView.layer.borderWidth = 5.0
        titleTextView.layer.borderColor = #colorLiteral(red: 0.08269290555, green: 0.2627741129, blue: 0.3623990017, alpha: 1).cgColor
        titleTextView.backgroundColor = #colorLiteral(red: 0.05882352963, green: 0.180392161, blue: 0.2470588237, alpha: 1)
        titleTextView.textColor = #colorLiteral(red: 0.8639426257, green: 0.8639426257, blue: 0.8639426257, alpha: 1)
        titleTextView.text = description.appending("\n_________") //Dirty styling.
        
        return titleTextView
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let libraryDelegate = libraryDelegate else {
            return
        }
        
        let offset = downloadSet.count
        let index = indexPath.item - offset
        if (index < 0 || index >= books.count) {return}
        
        let book = books[index]
        
        guard let cell = collectionView.cellForItem(at: indexPath) else {return}
        cell.contentView.addSubview(self.loadingIndicator)
        collectionView.isUserInteractionEnabled = false
        
        func done() {
            self.loadingIndicator.removeFromSuperview()
            collectionView.isUserInteractionEnabled = true
        }
        
        library.openBook(book, forPresentation: true, sender: self) { result in
            switch result {
            case .success(let publication):
                libraryDelegate.libraryDidSelectPublication(publication, book: book, completion: done)

            case .cancelled:
                done()
                
            case .failure(let error):
                self.libraryDelegate?.presentError(error, from: self)
                done()
            }
        }
    }
    
}

extension LibraryViewController: PublicationCollectionViewCellDelegate {
    
    func removePublicationFromLibrary(forCellAt indexPath: IndexPath) {
        let offset = downloadSet.count
        let index = indexPath.item-offset
        if index >= self.books.count {return}
        
        let book = self.books[index]
        
        let removePublicationAlert = UIAlertController(
            title: NSLocalizedString("library_delete_alert_title", comment: "Title of the publication remove confirmation alert"),
            message: NSLocalizedString("library_delete_alert_message", comment: "Message of the publication remove confirmation alert"),
            preferredStyle: .alert
        )
        let removeAction = UIAlertAction(title: NSLocalizedString("remove_button", comment: "Button to confirm the deletion of a publication"), style: .destructive, handler: { alert in
            // Remove the publication from publicationServer and Documents folder.
            let newOffset = self.downloadSet.count
            guard let newIndex = self.books.firstIndex(where: { (element) -> Bool in
                book.id == element.id
            }) else {return}
            let newIndexPath = IndexPath(item: newOffset+newIndex, section: 0)
            
            do {
                try self.library.remove(book)
                self.books.remove(at: index)
                
                self.collectionView.performBatchUpdates({
                    self.collectionView.deleteItems(at: [newIndexPath])
                }, completion: nil)
                
            } catch {
                self.libraryDelegate?.presentError(error, from: self)
            }
        })
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Button to cancel the deletion of a publication"), style: .cancel, handler: { alert in
            return
        })
        
        removePublicationAlert.addAction(removeAction)
        removePublicationAlert.addAction(cancelAction)
        present(removePublicationAlert, animated: true, completion: nil)
    }
    
    func displayInformation(forCellAt indexPath: IndexPath) {
        let book = books[indexPath.row]
        
        library.openBook(book, forPresentation: false, sender: self) { result in
            switch result {
            case .success(let publication):
                let detailsViewController = self.factory.make(publication: publication)
                detailsViewController.modalPresentationStyle = .popover
                self.navigationController?.pushViewController(detailsViewController, animated: true)
                
            case .failure(let error):
                self.libraryDelegate?.presentError(error, from: self)
                
            case .cancelled:
                break
            }
        }
    }
    
    // Used to reset ui of the last flipped cell, we must not have two cells
    // flipped at the same time
    func cellFlipped(_ cell: PublicationCollectionViewCell) {
        lastFlippedCell?.flipMenu()
        lastFlippedCell = cell
    }
}

extension LibraryViewController: DownloadDisplayDelegate {
    
    func didStartDownload(task: URLSessionDownloadTask, description: String) {
        let offset = downloadSet.count
        downloadSet.add(task)
        downloadTaskToRatio[task] = 0
        downloadTaskDescription[task] = description
        let newIndexPath = IndexPath(item: offset, section: 0)
        
        self.collectionView.performBatchUpdates({
            self.collectionView.insertItems(at: [newIndexPath])
        }, completion: nil)
    }
    
    func didFinishDownload(task:URLSessionDownloadTask) {
        books = try! BooksDatabase.shared.books.all()
        
        let offset = downloadSet.index(of: task)
        downloadSet.remove(task)
        downloadTaskToRatio.removeValue(forKey: task)
        downloadTaskDescription.removeValue(forKey: task)
        
        let theIndexPath = IndexPath(item: offset, section: 0)
        let newIndexPath = IndexPath(item: downloadSet.count, section: 0)
        
        if newIndexPath == theIndexPath {
            self.collectionView.reloadItems(at: [newIndexPath])
            return
        }
        
        self.collectionView.performBatchUpdates({
            collectionView.moveItem(at: theIndexPath, to: newIndexPath)
        }, completion: { (_) in
            self.collectionView.reloadItems(at: [newIndexPath])
        })
    }
    
    func didFailWithError(task:URLSessionDownloadTask, error: Error?) {
        let offset = downloadSet.index(of: task)
        guard offset != NSNotFound else {
            return
        }
        
        downloadSet.remove(task)
        downloadTaskToRatio.removeValue(forKey: task)
        let description = downloadTaskDescription[task] ?? ""
        downloadTaskDescription.removeValue(forKey: task)
        
        let indexPath = IndexPath(item: offset, section: 0)
        self.collectionView.performBatchUpdates({
            collectionView.deleteItems(at: [indexPath])
        }) { [weak self] _ in
            guard let self = self else {
                return
            }
            self.libraryDelegate?.presentError(LibraryError.downloadFailed(description), from: self)
        }
    }
    
    func didUpdateDownloadPercentage(task:URLSessionDownloadTask, percentage: Float) {
        
        downloadTaskToRatio[task] = percentage
        
        let index = downloadSet.index(of: task)
        let indexPath = IndexPath(item: index, section: 0)
        
        DispatchQueue.main.async {
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? PublicationCollectionViewCell else {return}
            cell.progress = percentage
        }
    }
    
    func insertNewItemWithUpdatedDataSource() {
        books = try! BooksDatabase.shared.books.all()
        
        let offset = downloadSet.count
        let newIndexPath = IndexPath(item: offset, section: 0)
        collectionView.performBatchUpdates({
            collectionView.insertItems(at: [newIndexPath])
        }, completion: { [weak self] _ in
            guard let `self` = self else { return }
            self.libraryDelegate?.presentAlert(
                NSLocalizedString("success_title", comment: "Title of the alert when a publication is successfully imported"),
                message: NSLocalizedString("library_import_success_message", comment: "Title of the alert when a publication is successfully imported"),
                from: self
            )
        })
    }
    
    func didCancel(task: URLSessionDownloadTask) {
        let offset = downloadSet.index(of: task)
        downloadSet.remove(task)
        downloadTaskToRatio.removeValue(forKey: task)
        downloadTaskDescription.removeValue(forKey: task)
        
        let theIndexPath = IndexPath(item: offset, section: 0)
        
        self.collectionView.performBatchUpdates({
            collectionView.deleteItems(at: [theIndexPath])
        })
    }
    
}

extension LibraryViewController: LibraryServiceDelegate {
    
    func reloadLibrary() {
        // FIXME: More efficient reloading
        books = try! BooksDatabase.shared.books.all()
        collectionView.reloadData()
    }

    func confirmImportingDuplicatePublication(withTitle title: String) -> Deferred<Void, Error> {
        return deferred(on: .main) { success, _, cancel in
            let confirmAction = UIAlertAction(title: NSLocalizedString("add_button", comment: "Confirmation button to import a duplicated publication"), style: .default) { _ in
                success(())
            }
            
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Cancel the confirmation alert"), style: .cancel) { _ in
                cancel()
            }
    
            let alert = UIAlertController(
                title: NSLocalizedString("library_duplicate_alert_title", comment: "Title of the import confirmation alert when the publication already exists in the library"),
                message: NSLocalizedString("library_duplicate_alert_message", comment: "Message of the import confirmation alert when the publication already exists in the library"),
                preferredStyle: .alert
            )
            alert.addAction(confirmAction)
            alert.addAction(cancelAction)
            
            self.present(alert, animated: true)
        }
    }
    
}

class PublicationIndicator: UIView  {
    
    lazy var indicator: UIActivityIndicatorView =  {
        
        let result = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.whiteLarge)
        result.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor(white: 0.3, alpha: 0.7)
        self.addSubview(result)
        
        let horizontalConstraint = NSLayoutConstraint(item: result, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        let verticalConstraint = NSLayoutConstraint(item: result, attribute: .centerY, relatedBy: .equal, toItem: self, attribute: .centerY, multiplier: 1.0, constant: 0.0)
        self.addConstraints([horizontalConstraint, verticalConstraint])
        
        return result
    }()
    
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

