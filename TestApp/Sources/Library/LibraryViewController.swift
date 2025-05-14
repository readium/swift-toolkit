//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import Combine
import Kingfisher
import MobileCoreServices
import ReadiumNavigator
import ReadiumOPDS
import ReadiumShared
import ReadiumStreamer
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import WebKit

protocol LibraryViewControllerFactory {
    func make() -> LibraryViewController
}

class LibraryViewController: UIViewController, Loggable {
    private var books: [Book] = []

    weak var lastFlippedCell: PublicationCollectionViewCell?

    var library: LibraryService!

    weak var libraryDelegate: LibraryModuleDelegate?

    private var subscriptions = Set<AnyCancellable>()

    lazy var loadingIndicator = PublicationIndicator()

    private lazy var addBookButton = UIBarButtonItem(
        systemItem: .add,
        menu: UIMenu(
            children: [
                UIAction(title: "Import local publication") { [weak self] _ in
                    self?.addBookFromDevice()
                },
                UIAction(title: "Stream publication over HTTP") { [weak self] _ in
                    self?.addBookForStreaming()
                },
            ]
        )
    )

    @IBOutlet var collectionView: UICollectionView! {
        didSet {
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

        library.allBooks()
            .receive(on: DispatchQueue.main)
            .sink { completion in
                if case let .failure(error) = completion {
                    self.libraryDelegate?.presentError(UserError(error), from: self)
                }
            } receiveValue: { newBooks in
                self.books = newBooks
                self.collectionView.reloadData()
            }
            .store(in: &subscriptions)

        // Add long press gesture recognizer.
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))

        recognizer.minimumPressDuration = 0.5
        recognizer.delaysTouchesBegan = true
        collectionView.addGestureRecognizer(recognizer)
        collectionView.accessibilityLabel = NSLocalizedString("library_a11y_label", comment: "Accessibility label for the library collection view")

        navigationItem.rightBarButtonItem = addBookButton
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
        collectionView?.collectionViewLayout.invalidateLayout()
    }

    static let iPadLayoutNumberPerRow: [ScreenOrientation: Int] = [.portrait: 4, .landscape: 5]
    static let iPhoneLayoutNumberPerRow: [ScreenOrientation: Int] = [.portrait: 3, .landscape: 4]

    static let layoutNumberPerRow: [UIUserInterfaceIdiom: [ScreenOrientation: Int]] = [
        .pad: LibraryViewController.iPadLayoutNumberPerRow,
        .phone: LibraryViewController.iPhoneLayoutNumberPerRow,
    ]

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        let idiom = { () -> UIUserInterfaceIdiom in
            let tempIdion = UIDevice.current.userInterfaceIdiom
            return (tempIdion != .pad) ? .phone : .pad // ignnore carplay and others
        }()

        let layoutNumberPerRow: [UIUserInterfaceIdiom: [ScreenOrientation: Int]] = [
            .pad: LibraryViewController.iPadLayoutNumberPerRow,
            .phone: LibraryViewController.iPhoneLayoutNumberPerRow,
        ]

        guard let deviceLayoutNumberPerRow = layoutNumberPerRow[idiom] else { return }
        guard let numberPerRow = deviceLayoutNumberPerRow[.current] else { return }

        guard let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        let contentWith = collectionView.collectionViewLayout.collectionViewContentSize.width

        let minimumSpacing = CGFloat(5)
        let width = (contentWith - CGFloat(numberPerRow - 1) * minimumSpacing) / CGFloat(numberPerRow)
        let height = width * 1.9

        flowLayout.minimumLineSpacing = minimumSpacing * 2
        flowLayout.minimumInteritemSpacing = minimumSpacing
        flowLayout.itemSize = CGSize(width: width, height: height)
    }

    @objc func addBookFromDevice() {
        var types = DocumentTypes.main.supportedUTTypes
        types.append(UTType.text)

        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }

    @objc func addBookForStreaming() {
        let ac = UIAlertController(title: "Stream publication", message: nil, preferredStyle: .alert)
        ac.addTextField { tf in
            tf.placeholder = "HTTP URL"
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        let addAction = UIAlertAction(title: "Add", style: .default) { [unowned ac, weak self] _ in
            guard
                let urlText = ac.textFields?.getOrNil(0)?.text,
                let url = HTTPURL(string: urlText)
            else {
                self?.addBookForStreaming()
                return
            }

            self?.importPublication(from: url)
        }

        ac.addAction(cancelAction)
        ac.addAction(addAction)
        ac.preferredAction = addAction

        present(ac, animated: true)
    }

    private func importPublication(from url: HTTPURL) {
        Task {
            do {
                try await library.importPublication(from: url, sender: self, progress: { _ in })
            } catch {
                alert(UserError(error))
            }
        }
    }
}

extension LibraryViewController {
    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != UIGestureRecognizer.State.began {
            return
        }

        let location = gestureRecognizer.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: location) {
            let cell = collectionView.cellForItem(at: indexPath) as! PublicationCollectionViewCell
            cell.flipMenu()
        }
    }
}

// MARK: - UIDocumentPickerDelegate.

extension LibraryViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        importFiles(at: urls)
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        importFiles(at: [url])
    }

    private func importFiles(at urls: [URL]) {
        Task {
            do {
                try await library.importPublications(from: urls, sender: self)
            } catch {
                libraryDelegate?.presentError(UserError(error), from: self)
            }
        }
    }
}

// MARK: - CollectionView Datasource.

extension LibraryViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if books.isEmpty {
            let noPublicationLabel = UILabel(frame: collectionView.frame)
            noPublicationLabel.text = NSLocalizedString("library_empty_message", comment: "Hint message when the library is empty")
            noPublicationLabel.textColor = UIColor.gray
            noPublicationLabel.textAlignment = .center
            collectionView.backgroundView = noPublicationLabel
        } else {
            collectionView.backgroundView = nil
        }

        return books.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "publicationCollectionViewCell", for: indexPath) as! PublicationCollectionViewCell
        cell.coverImageView.image = nil
        cell.progress = 0

        cell.isAccessibilityElement = true
        cell.accessibilityHint = NSLocalizedString("library_publication_a11y_hint", comment: "Accessibility hint for the publication collection cell")

        let book = books[indexPath.item]
        cell.delegate = self
        cell.accessibilityLabel = book.title
        cell.titleLabel.text = book.title
        cell.authorLabel.text = book.authors

        // Load image and then apply the shadow.
        if
            let coverURL = book.cover,
            let data = try? Data(contentsOf: coverURL.url),
            let cover = UIImage(data: data)
        {
            cell.coverImageView.image = cover
        } else {
            let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout
            let description = book.title
            let textView = defaultCover(layout: flowLayout, description: description)
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
        titleTextView.text = description.appending("\n_________") // Dirty styling.

        return titleTextView
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        Task {
            guard
                let libraryDelegate = libraryDelegate,
                let cell = collectionView.cellForItem(at: indexPath)
            else {
                return
            }
            cell.contentView.addSubview(self.loadingIndicator)
            collectionView.isUserInteractionEnabled = false

            defer {
                loadingIndicator.removeFromSuperview()
                collectionView.isUserInteractionEnabled = true
            }

            let book = books[indexPath.item]

            do {
                guard let pub = try await library.openBook(book, sender: self) else {
                    return
                }
                libraryDelegate.libraryDidSelectPublication(pub, book: book)
            } catch {
                libraryDelegate.presentError(UserError(error), from: self)
            }
        }
    }
}

extension LibraryViewController: PublicationCollectionViewCellDelegate {
    func removePublicationFromLibrary(forCellAt indexPath: IndexPath) {
        let book = books[indexPath.item]

        let removePublicationAlert = UIAlertController(
            title: NSLocalizedString("library_delete_alert_title", comment: "Title of the publication remove confirmation alert"),
            message: NSLocalizedString("library_delete_alert_message", comment: "Message of the publication remove confirmation alert"),
            preferredStyle: .alert
        )
        let removeAction = UIAlertAction(title: NSLocalizedString("remove_button", comment: "Button to confirm the deletion of a publication"), style: .destructive, handler: { _ in
            Task {
                do {
                    try await self.library.remove(book)
                } catch {
                    self.libraryDelegate?.presentError(UserError(error), from: self)
                }
            }
        })
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel_button", comment: "Button to cancel the deletion of a publication"), style: .cancel)

        removePublicationAlert.addAction(removeAction)
        removePublicationAlert.addAction(cancelAction)
        present(removePublicationAlert, animated: true, completion: nil)
    }

    func presentMetadata(forCellAt indexPath: IndexPath) {
        let book = books[indexPath.row]

        Task {
            do {
                guard let pub = try await library.openBook(book, sender: self) else {
                    return
                }
                let pubMetadataViewController = UIHostingController(rootView: PublicationMetadataView(publication: pub))
                pubMetadataViewController.modalPresentationStyle = .popover
                self.navigationController?.pushViewController(pubMetadataViewController, animated: true)
            } catch {
                libraryDelegate?.presentError(UserError(error), from: self)
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

class PublicationIndicator: UIView {
    lazy var indicator: UIActivityIndicatorView = {
        let result = UIActivityIndicatorView(style: .large)
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

        guard let superView = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false

        let horizontalConstraint = NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal, toItem: superView, attribute: .centerX, multiplier: 1.0, constant: 0.0)
        let verticalConstraint = NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: superView, attribute: .centerY, multiplier: 1.0, constant: 0.0)
        let widthConstraint = NSLayoutConstraint(item: self, attribute: .width, relatedBy: .equal, toItem: superView, attribute: .width, multiplier: 1.0, constant: 0.0)
        let heightConstraint = NSLayoutConstraint(item: self, attribute: .height, relatedBy: .equal, toItem: superView, attribute: .height, multiplier: 1.0, constant: 0.0)

        superView.addConstraints([horizontalConstraint, verticalConstraint, widthConstraint, heightConstraint])

        indicator.startAnimating()
    }

    override func removeFromSuperview() {
        indicator.stopAnimating()
        super.removeFromSuperview()
    }
}
