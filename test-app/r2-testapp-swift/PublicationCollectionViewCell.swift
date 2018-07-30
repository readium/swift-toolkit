//
//  PublicationCollectionViewCell.swift
//  r2-testapp-swift
//
//  Created by Geoffrey Bugniot on 26/07/2018.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit

protocol PublicationCollectionViewCellDelegate: AnyObject {
    var lastFlippedCell: PublicationCollectionViewCell? { get set }
    
    func displayInformation(forCellAt indexPath: IndexPath)
    func removePublicationFromLibrary(forCellAt indexPath: IndexPath)
    func cellFlipped(_ cell: PublicationCollectionViewCell)
}

class PublicationCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var coverImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    
    weak var delegate: PublicationCollectionViewCellDelegate?
    
    var publicationMenuViewController = PublicationMenuViewController()
    var isMenuDisplayed = false
    
    var progress: Float = 0.0 {
        
        didSet {
            progressView.progress = progress
            let hidden = (progress == 0 || progress == 1)
            if hidden !=  progressView.isHidden {
                progressView.isHidden = hidden
                if hidden {
                    self.backgroundColor = UIColor.clear
                } else {
                    self.backgroundColor = UIColor.lightGray
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
        
        isAccessibilityElement = true
        accessibilityHint = "Hold to access options."
        
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        publicationMenuViewController.view.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
    }
    
}

extension PublicationCollectionViewCell {
    
    /// Flip the PublicationCell and display a user menu.
    func flipMenu() {
        
        var transitionOptions: UIViewAnimationOptions!
        
        if isMenuDisplayed {
            transitionOptions = UIViewAnimationOptions.transitionFlipFromLeft
            delegate?.lastFlippedCell = nil
        } else {
            transitionOptions = UIViewAnimationOptions.transitionFlipFromRight
            if delegate?.lastFlippedCell != self {
                delegate?.cellFlipped(self)
            }
        }
        
        UIView.transition(with: contentView, duration: 0.5, options: transitionOptions, animations: {
            self.coverImageView.superview!.isHidden = !self.isMenuDisplayed
            self.publicationMenuViewController.view.isHidden = self.isMenuDisplayed
        }, completion: { _ in
            self.isMenuDisplayed = !self.isMenuDisplayed
        })
        
    }
    
}

extension PublicationCollectionViewCell: PublicationMenuViewControllerDelegate {
    
    func infosButtonTapped() {
        guard let indexPath = (superview as? UICollectionView)?.indexPath(for: self) else {
            return
        }
        flipMenu()
        delegate?.displayInformation(forCellAt: indexPath)
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
