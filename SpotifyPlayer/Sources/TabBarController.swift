//
//  TabBarController.swift
//  SpotifyPlayer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class TabBarController: UIViewController {
    private let playerViewController = PlayerViewController()
    @IBOutlet var tabBarContainer: UIView!
    @IBOutlet var tabBar: UITabBar!
    var shouldHideStatusBar: Bool = false
    private var coordinator: TransitionCoordinator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        tabBar.selectedItem = tabBar.items?.first
        add(playerViewController)
        view.bringSubviewToFront(tabBarContainer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let additionalBottomInset = tabBar.bounds.height
        playerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: additionalBottomInset, right: 0)
        coordinator = TransitionCoordinator(tabBarViewController: self, playerViewController: playerViewController)
    }
    
    override var prefersStatusBarHidden: Bool {
        return shouldHideStatusBar
    }
    
    private func setupUI() {
        if #available(iOS 13, *) {
            let appearance = tabBar.standardAppearance
            appearance.configureWithTransparentBackground()
            appearance.shadowImage = nil
            appearance.shadowColor = nil
            tabBar.standardAppearance = appearance
        } else {
            tabBar.shadowImage = UIImage()
            tabBar.backgroundImage = UIImage()
        }
    }
    
}
