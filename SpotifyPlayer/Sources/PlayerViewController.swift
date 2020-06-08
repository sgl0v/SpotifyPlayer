//
//  PlayerViewController.swift
//  SpotifyPlayer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class PlayerViewController : UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet var miniPlayerView: UIView!
    @IBOutlet var playerView: UIView!
    @IBOutlet var closeButton: UIButton!
    @IBOutlet var artwork: UIView!
    @IBOutlet var progressIndicator: UIView!
    private lazy var bgLayer: CALayer = {
        let layer = CAGradientLayer()
        layer.colors = [UIColor(named: "gradientStart")!.cgColor, UIColor(named: "gradientEnd")!.cgColor]
        return layer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        playerView.layer.insertSublayer(bgLayer, at: 0)
            
        artwork.layer.shadowPath = UIBezierPath(rect: artwork.bounds).cgPath
        artwork.layer.shadowColor = UIColor.black.cgColor
        artwork.layer.shadowRadius = 16
        artwork.layer.shadowOffset = .zero
        artwork.layer.shadowOpacity = 0.1
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bgLayer.frame = playerView.bounds
    }
    
}
