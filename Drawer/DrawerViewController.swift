//
//  DrawerViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class DrawerViewController : UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet var playerContainerView: UIView!
    @IBOutlet var miniPlayerView: UIView!
    @IBOutlet var playerView: UIView!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        playerContainerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    }
}
