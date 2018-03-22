//
//  PublicationCell.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 6/13/17.
//  Copyright © 2017 European Digital Reading Lab. All rights reserved.
//

import UIKit

protocol PublicationCellDelegate: class {
    weak var lastFlippedCell: PublicationCell? { get set }

    func displayInformation(forCellAt indexPath: IndexPath)
    func removePublicationFromLibrary(forCellAt indexPath: IndexPath)
    func cellFlipped(_ cell: PublicationCell)
}

class PublicationCell: UICollectionViewCell {
    var imageView: UIImageView
    var menuView: CellMenuView
    var cardView: (frontView: UIView, backView: UIView)?
    //
    weak var delegate: PublicationCellDelegate?

    override init(frame: CGRect) {
        imageView = UIImageView()
        menuView = CellMenuView(frame: frame)
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityHint = "Hold to access options."
        imageView.contentMode = .scaleAspectFit
        imageView.frame = self.bounds
        menuView.delegate = self
        contentView.addSubview(imageView)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        contentView.frame = self.bounds
        imageView.frame = self.bounds
        imageView.layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: contentView.layer.cornerRadius).cgPath
        menuView.frame = self.bounds
        menuView.layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: contentView.layer.cornerRadius).cgPath
    }
}

extension PublicationCell {

    /// Flip the PublicationCell and display a user menu.
    func flipMenu() {
        var transitionOptions: UIViewAnimationOptions!

        if menuView.superview != nil {
            transitionOptions = UIViewAnimationOptions.transitionFlipFromLeft
            cardView = (frontView: imageView, backView: menuView)
            delegate?.lastFlippedCell = nil
        } else {
            transitionOptions = UIViewAnimationOptions.transitionFlipFromRight
            cardView = (frontView: menuView, backView: imageView)
            if delegate?.lastFlippedCell != self {
                delegate?.cellFlipped(self)
            }
        }

        UIView.transition(with: contentView, duration: 0.5, options: transitionOptions, animations: {
            self.cardView?.backView.removeFromSuperview()
            self.contentView.addSubview(self.cardView!.frontView)
        }, completion: nil)
    }

    // Add shadow to the views. To be called when the image has been loaded.
    public func applyShadows() {
        configureShadow(for: imageView, with: 0.3)
        configureShadow(for: menuView, with: 0.3)
    }

    public func configureShadow(for view: UIView, with opacity: Float) {
        view.layer.shadowColor = UIColor.lightGray.cgColor
        view.layer.shadowOffset = CGSize.init(width: 0, height: 3.0)
        view.layer.shadowOpacity = opacity
        view.layer.masksToBounds = false
    }

}

// MARK: - Responds to action which occured in the PublicationCell's MenuView.
extension PublicationCell: CellMenuViewDelegate {
    func infoTapped() {
        guard let indexPath = (superview as? UICollectionView)?.indexPath(for: self) else {
            return
        }
        flipMenu()
        delegate?.displayInformation(forCellAt: indexPath)
    }

    func removeTapped() {
        guard let indexPath = (superview as? UICollectionView)?.indexPath(for: self) else {
            return
        }
        flipMenu()
        delegate?.removePublicationFromLibrary(forCellAt: indexPath)
    }

    func cancelTapped() {
        flipMenu()
    }
}
