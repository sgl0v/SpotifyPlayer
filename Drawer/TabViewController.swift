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
    private lazy var libraryViewController: UIViewController = {
        let viewController = UIViewController()
        viewController.view.backgroundColor = UIColor(named: "primaryBackgroundColor")
        return UINavigationController(rootViewController: viewController)
    }()
    @IBOutlet var tabBarContainer: UIView!
    @IBOutlet private var tabBar: UITabBar!
    private var animatior: TransitionAnimator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 13, *) {
            // iOS 13:
            let appearance = tabBar.standardAppearance
            appearance.configureWithTransparentBackground()
            appearance.shadowImage = nil
            appearance.shadowColor = nil
            tabBar.standardAppearance = appearance
        } else {
            // iOS 12 and below:
            tabBar.shadowImage = UIImage()
            tabBar.backgroundImage = UIImage()
        }
        tabBar.selectedItem = tabBar.items?.first
        add(libraryViewController)
        add(drawerViewController)
        view.bringSubviewToFront(tabBarContainer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let additionalBottomInset = tabBar.bounds.height
        drawerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: additionalBottomInset, right: 0)
        animatior = TransitionAnimator(tabBarViewController: self, drawerViewController: drawerViewController)
    }
    
}
