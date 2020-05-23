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
    private let popupCollapsedButtomInset: CGFloat
    private let animationDuration = TimeInterval(0.7)
    
    init(tabBarViewController: TabViewController, drawerViewController: DrawerViewController) {
        self.tabBarViewController = tabBarViewController
        self.drawerViewController = drawerViewController
        self.popupCollapsedButtomInset = drawerViewController.view.bounds.height - drawerViewController.view.safeAreaInsets.bottom - drawerViewController.miniPlayerView.bounds.height
        super.init()
        drawerViewController.view.addGestureRecognizer(panGestureRecognizer)
        drawerViewController.view.addGestureRecognizer(tapGestureRecognizer)
        updateUI(with: currentState)
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        guard let playerContainerView = drawerViewController?.view else { return }
        
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
            let closeButton = drawerViewController?.closeButton,
            let view = drawerViewController?.view else { return }
        
        let tapLocation = recognizer.location(in: view)
        let closeButtonFrame = closeButton.convert(closeButton.frame, to: view).insetBy(dx: -8, dy: -8)
        guard miniPlayerView.frame.contains(tapLocation) || closeButtonFrame.contains(tapLocation) else { return }
        
        runningAnimators = createAnimations(for: currentState.reversed)
        startAnimations(for: currentState.reversed)
    }
    
    private func startAnimations(for finalState: State) {
        runningAnimators.startAnimations()
    }
    
    private func createAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
            transitionAnimator(for: currentState.reversed, duration: animationDuration),
            contentAnimator(for: currentState.reversed, duration: animationDuration)
        ]
    }
    
    private func transitionAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9, animations: {
            self.updatePlayerContainer(with: finalState)
            self.drawerViewController?.view.layoutIfNeeded()
        })
        transitionAnimator.addAnimations({
            self.updateTabBar(with: finalState)
        }, delayFactor: 0.1)
        return transitionAnimator
    }
    
    private func contentAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear, animations: {
            UIView.animateKeyframes(withDuration: duration, delay: 0, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1) {
                    self.updateMiniPlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.1) {
                    self.updatePlayer(with: finalState)
                }

                //                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                //                    self.updatePlayerContainer(with: finalState)
                //                    self.drawerViewController?.view.layoutIfNeeded()
                //                }
                                
//                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.9) {
//                    self.updateTabBar(with: finalState)
//                }
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
        guard let tabBarContainer = tabBarViewController?.tabBarContainer else { return }
        tabBarContainer.transform = state == .closed ? .identity : CGAffineTransform(translationX: 0, y: tabBarContainer.bounds.height)
    }

    private func updateMiniPlayer(with state: State) {
        drawerViewController?.miniPlayerView.alpha = state == .open ? 0 : 1
    }
    
    private func updatePlayer(with state: State) {
        drawerViewController?.playerView.alpha = state == .open ? 1 : 0
        drawerViewController?.view.layer.cornerRadius = state == .open ? 20 : 0
    }

    
    private func updatePlayerContainer(with state: State) {
        drawerViewController?.view.transform = state == .open ? .identity : CGAffineTransform(translationX: 0, y: popupCollapsedButtomInset)
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
