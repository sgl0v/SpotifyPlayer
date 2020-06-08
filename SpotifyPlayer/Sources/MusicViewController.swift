//
//  MusicViewController.swift
//  SpotifyPlayer
//
//  Created by Maksym Shcheglov on 27/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class MusicViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "primaryBackgroundColor")
        title = "Music"
        navigationController?.navigationBar.barTintColor = UIColor(named: "primaryBackgroundColor")
        navigationController?.navigationBar.isTranslucent = false
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationController?.navigationBar.backgroundColor = UIColor(named: "primaryBackgroundColor")
    }
}
