//
//  TransitionAnimator.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 22/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class TransitionAnimator: NSObject {
    
    enum State: Equatable {
        case closed
        case open
        
        var reversed: State {
            switch self {
            case .open: return .closed
            case .closed: return .open
            }
        }
    }
    
    private weak var tabBarViewController: TabViewController?
    private weak var drawerViewController: DrawerViewController?
    
    private lazy var panGestureRecognizer: UIPanGestureRecognizer = {
        let recognizer = UIPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
        recognizer.delegate = self
        return recognizer
    }()
    private lazy var tapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewTapped(recognizer:)))
        recognizer.delegate = self
        return recognizer
    }()
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var currentState: State = .closed
    private var popupCollapsedButtomInset: CGFloat {
        guard let drawerViewController = self.drawerViewController else { return 0 }
        return drawerViewController.playerContainerView.bounds.height - drawerViewController.view.safeAreaInsets.bottom  - drawerViewController.miniPlayerView.bounds.height - 100
    }
    private let animationDuration = TimeInterval(0.7)
    
    init(tabBarViewController: TabViewController, drawerViewController: DrawerViewController) {
        self.tabBarViewController = tabBarViewController
        self.drawerViewController = drawerViewController
        super.init()
        drawerViewController.playerContainerView.addGestureRecognizer(panGestureRecognizer)
        drawerViewController.playerContainerView.addGestureRecognizer(tapGestureRecognizer)
        updateUI(with: currentState)
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        guard let playerContainerView = drawerViewController?.playerContainerView else { return }
        
        switch recognizer.state {
        case .began:
            runningAnimators = createAnimations(for: currentState.reversed)
            startAnimations(for: currentState.reversed)
            runningAnimators.pauseAnimations()
            
        case .changed:
            let translation = recognizer.translation(in: playerContainerView)
            var fraction = -translation.y / popupCollapsedButtomInset
            if currentState == .open { fraction *= -1 }
            runningAnimators.fractionComplete = fraction
            
        case .ended:
            runningAnimators.continueAnimations()
            
            // variable setup
            let yVelocity = recognizer.velocity(in: playerContainerView).y
            let shouldClose = yVelocity > 0
            
            // if there is no motion, continue all animations and exit early
            if yVelocity == 0 {
                runningAnimators.continueAnimations()
                break
            }
            
            // reverse the animations based on their current state and pan motion
            switch (currentState, shouldClose) {
            case (.open, true), (.closed, false):
                if runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            case (.open, false), (.closed, true):
                if !runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            }
            
            // continue all animations
            runningAnimators.continueAnimations()
            
        default:
            break
        }
    }
    
    @objc private func popupViewTapped(recognizer: UITapGestureRecognizer) {
        guard let miniPlayerView = drawerViewController?.miniPlayerView,
            let playerContainerView = drawerViewController?.playerContainerView,
            miniPlayerView.frame.contains(recognizer.location(in: playerContainerView)) else { return }
        runningAnimators = createAnimations(for: currentState.reversed)
        startAnimations(for: currentState.reversed)
    }
    
    private func startAnimations(for finalState: State) {
        runningAnimators.startAnimations()
    }
    
    private func createAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
//            transitionAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration),
            contentAnimator(for: currentState.reversed, duration: animationDuration)
        ]
    }
    
//    private func transitionAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
//        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.7, animations: {
//            self.updatePlayerContainer(with: finalState)
//            self.drawerViewController?.view.layoutIfNeeded()
//        })
//        transitionAnimator.addCompletion { position in
//            self.currentState = self.finalState(from: finalState.reversed, position: position)
//            self.updatePlayerContainer(with: self.currentState)
//
//            // remove all running animators
//            self.runningAnimators.removeAll()
//        }
//        return transitionAnimator
//    }
    
    private func contentAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9, animations: {
            UIView.animateKeyframes(withDuration: duration, delay: 0, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                    self.updatePlayerContainer(with: finalState)
                    self.drawerViewController?.view.layoutIfNeeded()
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1) {
                    self.updateMiniPlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.1) {
                    self.updatePlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.9) {
                    self.updateTabBar(with: finalState)
                }
            })
        })
        animator.addCompletion { position in
            self.currentState = self.finalState(from: finalState.reversed, position: position)
            self.updateUI(with: self.currentState)
            
            // remove all running animators
            self.runningAnimators.removeAll()
        }
        animator.scrubsLinearly = false
        return animator
    }
    
    private func updateUI(with state: State) {
        updateTabBar(with: state)
        updatePlayer(with: state)
        updateMiniPlayer(with: state)
        updatePlayerContainer(with: state)
    }
    
    private func updateTabBar(with state: State) {
        guard let tabBar = tabBarViewController?.tabBar else { return }
        tabBar.transform = state == .closed ? .identity : CGAffineTransform(translationX: 0, y: tabBar.bounds.height)
    }

    private func updateMiniPlayer(with state: State) {
        drawerViewController?.miniPlayerView.alpha = state == .open ? 0 : 1
    }
    
    private func updatePlayer(with state: State) {
        drawerViewController?.playerView.alpha = state == .open ? 1 : 0
    }

    
    private func updatePlayerContainer(with state: State) {
        drawerViewController?.view.backgroundColor = state == .open ? UIColor.black.withAlphaComponent(0.3) : .clear
        drawerViewController?.playerContainerView.transform = state == .open ? .identity : CGAffineTransform(translationX: 0, y: popupCollapsedButtomInset)
        drawerViewController?.playerContainerView.layer.cornerRadius = state == .open ? 10 : 0
    }
    
    private func finalState(from initialState: State, position: UIViewAnimatingPosition) -> State {
        switch position {
        case .end:
            return initialState.reversed
        case .start, .current:
            return initialState
        @unknown default:
            return initialState
        }
    }
    
}

extension TransitionAnimator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return runningAnimators.isEmpty
    }
}
