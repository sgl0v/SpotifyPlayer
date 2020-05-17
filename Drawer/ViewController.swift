//
//  ViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let viewController = UIViewController()
        viewController.view.backgroundColor = .yellow
        add(UINavigationController(rootViewController: viewController))
        add(DrawerViewController())
    }

}


