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
    @IBOutlet var tabBar: UIView!
    private var animatior: TransitionAnimator!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        add(libraryViewController)
        add(drawerViewController)
        view.bringSubviewToFront(tabBar)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let additionalBottomInset = tabBar.bounds.height - view.safeAreaInsets.bottom
        drawerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: additionalBottomInset, right: 0)
        animatior = TransitionAnimator(tabBarViewController: self, drawerViewController: drawerViewController)
    }
    
}
