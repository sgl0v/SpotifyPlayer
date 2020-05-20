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
    @IBOutlet private var tabBar: UIView!
    @IBOutlet private var progressView: UIView!
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!
    private var tabbarAnimator: UIViewPropertyAnimator!
    private let animationDuration = TimeInterval(0.6)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        add(libraryViewController)
        add(drawerViewController)
        view.bringSubviewToFront(tabBar)
        
        drawerViewController.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let additionalBottomInset = tabBar.bounds.height - view.safeAreaInsets.bottom
        drawerViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: additionalBottomInset, right: 0)
    }
    
}

extension TabViewController: DrawerViewControllerDelegate {
    func didTriggerStateChange(to state: DrawerViewController.State) {
        tabbarAnimator = transitionAnimator(for: state, duration: animationDuration)
        tabbarAnimator.startAnimation()
    }
    
    func didStartStateChange(to state: DrawerViewController.State) {
        tabbarAnimator = transitionAnimator(for: state, duration: animationDuration)
        tabbarAnimator.startAnimation()
        tabbarAnimator.pauseAnimation()
    }
    
    func didProgressStateChange(to state: DrawerViewController.State, fraction: CGFloat) {
        tabbarAnimator.fractionComplete = fraction
    }
    
    func didContinueStateChange(to state: DrawerViewController.State, isReversed: Bool) {
        tabbarAnimator.isReversed = isReversed
        tabbarAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
    }
    
    func didFinishStateChange(to state: DrawerViewController.State) {
        updateUI(with: state)
    }
    
    private func transitionAnimator(for finalState: DrawerViewController.State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
            self.updateUI(with: finalState)
        })
        return transitionAnimator
    }

    private func updateUI(with state: DrawerViewController.State) {
        switch state {
        case .open:
            tabBar.transform = CGAffineTransform(translationX: 0, y: tabBar.bounds.height)
            progressView.alpha = 0
        case .closed:
            tabBar.transform = .identity
            progressView.alpha = 1
        }
    }
}


