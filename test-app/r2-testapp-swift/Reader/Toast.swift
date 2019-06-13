//
//  Toast.swift
//  r2-testapp-swift
//
//  Created by Aferdita Muriqi on 8/4/18.
//  Copyright © 2018 Readium. All rights reserved.
//

import UIKit
import MBProgressHUD

func toast(_ view:UIView, _ text:String, _ duration:TimeInterval) {
    let hud = MBProgressHUD.showAdded(to: view, animated: true)
    hud.mode = .text;
    hud.label.text = text
    hud.hide(animated: true, afterDelay: duration)
}

