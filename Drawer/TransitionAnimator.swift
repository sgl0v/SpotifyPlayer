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
        case opened
        
        static prefix func !(_ state: State) -> State {
            return state == .opened ? .closed : .opened
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
    private let animationDuration = TimeInterval(0.7)
    private var totalAnimationDistance: CGFloat {
        guard let drawerViewController = drawerViewController else { return 0 }
        return drawerViewController.view.bounds.height - drawerViewController.view.safeAreaInsets.bottom - drawerViewController.miniPlayerView.bounds.height
    }

    init(tabBarViewController: TabViewController, drawerViewController: DrawerViewController) {
        self.tabBarViewController = tabBarViewController
        self.drawerViewController = drawerViewController
        super.init()
        drawerViewController.view.addGestureRecognizer(panGestureRecognizer)
        drawerViewController.view.addGestureRecognizer(tapGestureRecognizer)
        updateUI(with: currentState)
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        guard let playerContainerView = drawerViewController?.view else { return }
        
        switch recognizer.state {
        case .began:
            startTransitionAnimations(for: !currentState)
            runningAnimators.pauseAnimations()
        case .changed:
            let translation = recognizer.translation(in: playerContainerView)
            updateInteractiveTransition(distanceTraveled: translation.y)
        case .ended:
            let velocity = recognizer.velocity(in: playerContainerView).y
            let isCancelled = isGestureCancelled(with: velocity, state: currentState)
            continueInteractiveTransition(cancel: isCancelled)
            
//            // variable setup
//            let yVelocity = recognizer.velocity(in: playerContainerView).y
//            let shouldClose = yVelocity > 0
//
//            // if there is no motion, continue all animations and exit early
//            if yVelocity == 0 {
//                runningAnimators.continueAnimations()
//                break
//            }
//
//            // reverse the animations based on their current state and pan motion
//            switch (currentState, shouldClose) {
//            case (.open, true), (.closed, false):
//                if runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
//            case (.open, false), (.closed, true):
//                if !runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
//            }
//
//            // continue all animations
//            runningAnimators.continueAnimations()
        case .cancelled, .failed:
            continueInteractiveTransition(cancel: true)
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
        
        startTransitionAnimations(for: !currentState)
    }
    
    private func startTransitionAnimations(for finalState: State) {
        switch finalState {
        case .opened: runningAnimators = createOpenAnimations(for: finalState)
        case .closed: runningAnimators = createCloseAnimations(for: finalState)
        }
        runningAnimators.startAnimations()
    }
    
    private func isGestureCancelled(with velocity: CGFloat, state: State) -> Bool {
        guard velocity != 0 else { return false }
        
        let isPanningDown = velocity > 0
        return (state == .closed && isPanningDown) || (state == .opened && !isPanningDown)
    }
    
    func updateInteractiveTransition(distanceTraveled: CGFloat) {
        var fraction = distanceTraveled / totalAnimationDistance
        if currentState == .closed { fraction *= -1 }
//            dump(fraction)
        runningAnimators.fractionComplete = fraction
    }
    
    // Continues or reverse transition on pan .ended
    func continueInteractiveTransition(cancel: Bool) {
        if cancel {
            runningAnimators.reverse()
        }
        
//        let timing = UICubicTimingParameters(animationCurve: .easeOut)
//        for animator in runningAnimators {
//            animator.continueAnimation(withTimingParameters: timing, durationFactor: 0)
//        }
        runningAnimators.continueAnimations()
    }

    private func createOpenAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
            contentOpenAnimator(for: finalState, duration: animationDuration)
        ]
    }
    
    private func contentOpenAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0, animations: {
            self.updatePlayerContainer(with: finalState)
        })
        animator.addAnimations {
            UIView.animateKeyframes(withDuration: 0, delay: 0, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1) {
                    self.updateMiniPlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.1) {
                    self.updatePlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.8) {
                    self.updateTabBar(with: finalState)
                }
            })
        }
        animator.addCompletion { position in
            self.currentState = self.finalState(from: !finalState, position: position)
            self.updateUI(with: self.currentState)
            
            // remove all running animators
            self.runningAnimators.removeAll()
        }
        return animator
    }
    
    private func createCloseAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
            contentCloseAnimator(for: finalState, duration: animationDuration)
        ]
    }
    
    private func transitionCloseAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9, animations: {
            self.updatePlayerContainer(with: finalState)
            self.updateTabBar(with: finalState)
        })
    }
    
    private func contentCloseAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9, animations: {
            self.updatePlayerContainer(with: finalState)
            self.updateTabBar(with: finalState)
            
            UIView.animateKeyframes(withDuration: 0, delay: 0, options: [], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    self.updateMiniPlayer(with: finalState)
                }

                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    self.updatePlayer(with: finalState)
                }
            })
        })
        animator.addCompletion { position in
            self.currentState = self.finalState(from: !finalState, position: position)
            self.updateUI(with: self.currentState)
            
            // remove all running animators
            self.runningAnimators.removeAll()
        }
//        animator.scrubsLinearly = false
        return animator
    }
    
    private func updateUI(with state: State) {
        updateTabBar(with: state)
        updatePlayer(with: state)
        updateMiniPlayer(with: state)
        updatePlayerContainer(with: state)
    }
    
    private func updateTabBar(with state: State) {
        guard let tabBarViewController = tabBarViewController, let tabBarContainer = tabBarViewController.tabBarContainer else { return }
        tabBarContainer.transform = state == .closed ? .identity : CGAffineTransform(translationX: 0, y: tabBarContainer.bounds.height)
        tabBarViewController.shouldHideStatusBar = state == .opened
        tabBarViewController.setNeedsStatusBarAppearanceUpdate()
    }

    private func updateMiniPlayer(with state: State) {
        drawerViewController?.miniPlayerView.alpha = state == .opened ? 0 : 1
    }
    
    private func updatePlayer(with state: State) {
        guard let drawerViewController = drawerViewController,
            let tabBarViewController = tabBarViewController else { return }
        
        drawerViewController.playerView.alpha = state == .opened ? 1 : 0
        drawerViewController.view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        let cornerRadius: CGFloat = drawerViewController.view.safeAreaInsets.bottom > tabBarViewController.tabBar.bounds.height ? 20 : 0
        drawerViewController.view.layer.cornerRadius = state == .opened ? cornerRadius : 0
    }
    
    private func updatePlayerContainer(with state: State) {
        drawerViewController?.view.transform = state == .opened ? .identity : CGAffineTransform(translationX: 0, y: totalAnimationDistance)
    }
    
    private func finalState(from initialState: State, position: UIViewAnimatingPosition) -> State {
        switch position {
        case .end:
            return !initialState
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
