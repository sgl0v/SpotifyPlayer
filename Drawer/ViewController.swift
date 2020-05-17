//
//  ViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    private let drawerViewController = DrawerViewController()
    private lazy var libraryViewController: UIViewController = {
        let viewController = UIViewController()
        viewController.view.backgroundColor = UIColor(named: "primaryBackgroundColor")
        return UINavigationController(rootViewController: viewController)
    }()
    @IBOutlet private var tabbar: UIStackView!
    @IBOutlet private var tabbarContainer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        add(libraryViewController)
        add(drawerViewController)
        view.bringSubviewToFront(tabbarContainer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        drawerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: tabbar.bounds.height, right: 0)
    }
    
}


