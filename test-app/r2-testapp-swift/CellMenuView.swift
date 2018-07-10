//
//  CellMenuView.swift
//  r2-navigator
//
//  Created by Alexandre Camilleri on 6/23/17.
//
//  Copyright 2018 European Digital Reading Lab. All rights reserved.
//  Licensed to the Readium Foundation under one or more contributor license agreements.
//  Use of this source code is governed by a BSD-style license which is detailed in the
//  LICENSE file present in the project repository where this source code is maintained.
//

import UIKit

protocol CellMenuViewDelegate: class {
    func infoTapped()
    func removeTapped()
    func cancelTapped()
}

class CellMenuView: UIView {
    let infoButton = UIButton()
    let removeButton = UIButton()
    let cancelButton = UIButton()

    weak var delegate: CellMenuViewDelegate?

    override init(frame: CGRect) {
        var modifiedFrame = frame
        modifiedFrame.origin = CGPoint.zero
        super.init(frame: modifiedFrame)
        backgroundColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        infoButton.isAccessibilityElement = true
        infoButton.setTitle("Infos", for: .normal)
        infoButton.setTitleColor(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1), for: .normal)
        infoButton.addTarget(self, action: #selector(infoButtonTapped), for: .touchDown)
        removeButton.isAccessibilityElement = true
        removeButton.setTitle("Remove", for: .normal)
        removeButton.setTitleColor(#colorLiteral(red: 0.7450980544, green: 0.1568627506, blue: 0.07450980693, alpha: 1), for: .normal)
        removeButton.addTarget(self, action: #selector(removeButtonTapped), for: .touchDown)
        cancelButton.isAccessibilityElement = true
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(#colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchDown)
        addSubview(infoButton)
        addSubview(removeButton)
        addSubview(cancelButton)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        let width = frame.size.width
        let height = frame.size.height / 3
        let offset = height
        
        infoButton.frame = CGRect(x: 0, y: 0, width: width, height: height)
        removeButton.frame = CGRect(x: 0, y: offset, width: width, height: height)
        cancelButton.frame = CGRect(x: 0, y: offset * 2, width: width, height: height)
    }
}

extension CellMenuView {
    @objc func infoButtonTapped() {
        delegate?.infoTapped()
    }

    @objc func removeButtonTapped() {
        delegate?.removeTapped()
    }
    
    @objc func cancelButtonTapped() {
        delegate?.cancelTapped()
    }
}
