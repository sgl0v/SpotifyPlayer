//
//  ViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class TabViewController: UIViewController {
    private let drawerViewController = DrawerViewController()
    @IBOutlet var tabBarContainer: UIView!
    @IBOutlet var tabBar: UITabBar!
    var shouldHideStatusBar: Bool = false
    private var animatior: TransitionAnimator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        tabBar.selectedItem = tabBar.items?.first
        add(drawerViewController)
        view.bringSubviewToFront(tabBarContainer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let additionalBottomInset = tabBar.bounds.height
        drawerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: additionalBottomInset, right: 0)
        animatior = TransitionAnimator(tabBarViewController: self, drawerViewController: drawerViewController)
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
