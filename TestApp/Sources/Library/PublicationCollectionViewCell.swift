//
//  Copyright 2025 Readium Foundation. All rights reserved.
//  Use of this source code is governed by the BSD-style license
//  available in the top-level LICENSE file of the project.
//

import UIKit

protocol PublicationCollectionViewCellDelegate: AnyObject {
    var lastFlippedCell: PublicationCollectionViewCell? { get set }

    func presentMetadata(forCellAt indexPath: IndexPath)
    func removePublicationFromLibrary(forCellAt indexPath: IndexPath)
    func cellFlipped(_ cell: PublicationCollectionViewCell)
}

class PublicationCollectionViewCell: UICollectionViewCell {
    @IBOutlet var coverImageView: UIImageView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var authorLabel: UILabel!

    weak var delegate: PublicationCollectionViewCellDelegate?

    var publicationMenuViewController = PublicationMenuViewController()
    var isMenuDisplayed = false

    var progress: Float = 0.0 {
        didSet {
            progressView.progress = progress
            let hidden = (progress == 0 || progress == 1)
            if hidden != progressView.isHidden {
                progressView.isHidden = hidden
                if hidden {
                    backgroundColor = UIColor.clear
                } else {
                    backgroundColor = UIColor.lightGray
                }
            }
        }
    }

    private lazy var progressView: UIProgressView = {
        let pView = UIProgressView(progressViewStyle: .bar)
        pView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(pView)

        let leftConstraint = NSLayoutConstraint(item: pView, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 0.0)
        let rightConstraint = NSLayoutConstraint(item: pView, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: 0.0)
        let verticalConstraint = NSLayoutConstraint(item: pView, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1.0, constant: 0.0)

        self.addConstraints([leftConstraint, rightConstraint, verticalConstraint])

        return pView

    }()

    override func awakeFromNib() {
        super.awakeFromNib()

        publicationMenuViewController.delegate = self
        publicationMenuViewController.view.isHidden = !isMenuDisplayed
        contentView.addSubview(publicationMenuViewController.view)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        publicationMenuViewController.view.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
    }
}

extension PublicationCollectionViewCell {
    /// Flip the PublicationCollectionViewCell and display a user menu.
    func flipMenu() {
        var transitionOptions: UIView.AnimationOptions!

        if isMenuDisplayed {
            transitionOptions = UIView.AnimationOptions.transitionFlipFromLeft
            delegate?.lastFlippedCell = nil
            isAccessibilityElement = true
        } else {
            isAccessibilityElement = false
            transitionOptions = UIView.AnimationOptions.transitionFlipFromRight
            if delegate?.lastFlippedCell != self {
                delegate?.cellFlipped(self)
            }
        }

        // Reverse the UI. Display the menu and hide the cover or vice versa
        UIView.transition(with: contentView, duration: 0.5, options: transitionOptions, animations: {
            // coverImageView.superview is the stack view embedding the cover image,
            // the title label and the author label.
            self.coverImageView.superview!.isHidden = !self.isMenuDisplayed
            self.publicationMenuViewController.view.isHidden = self.isMenuDisplayed
        }, completion: { _ in
            self.isMenuDisplayed = !self.isMenuDisplayed
        })
    }
}

extension PublicationCollectionViewCell: PublicationMenuViewControllerDelegate {
    func metadataButtonTapped() {
        guard let indexPath = (superview as? UICollectionView)?.indexPath(for: self) else {
            return
        }
        flipMenu()
        delegate?.presentMetadata(forCellAt: indexPath)
    }

    func removeButtonTapped() {
        guard let indexPath = (superview as? UICollectionView)?.indexPath(for: self) else {
            return
        }
        flipMenu()
        delegate?.removePublicationFromLibrary(forCellAt: indexPath)
    }

    func cancelButtonTapped() {
        flipMenu()
    }
}
