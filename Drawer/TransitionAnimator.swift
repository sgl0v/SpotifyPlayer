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
    private weak var playerViewController: PlayerViewController?
    
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
    private var state: State = .closed
    private let animationDuration = TimeInterval(0.7)
    private var totalAnimationDistance: CGFloat {
        guard let playerViewController = playerViewController else { return 0 }
        return playerViewController.view.bounds.height - playerViewController.view.safeAreaInsets.bottom - playerViewController.miniPlayerView.bounds.height
    }

    init(tabBarViewController: TabViewController, playerViewController: PlayerViewController) {
        self.tabBarViewController = tabBarViewController
        self.playerViewController = playerViewController
        super.init()
        playerViewController.view.addGestureRecognizer(panGestureRecognizer)
        playerViewController.view.addGestureRecognizer(tapGestureRecognizer)
        updateUI(with: state)
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            startInteractiveTransition(for: !state)
        case .changed:
            let translation = recognizer.translation(in: recognizer.view!)
            updateInteractiveTransition(distanceTraveled: translation.y)
        case .ended:
            let velocity = recognizer.velocity(in: recognizer.view!).y
            let isCancelled = isGestureCancelled(with: velocity)
            continueInteractiveTransition(cancel: isCancelled)
        case .cancelled, .failed:
            continueInteractiveTransition(cancel: true)
        default:
            break
        }
    }
    
    @objc private func popupViewTapped(recognizer: UITapGestureRecognizer) {
        guard let miniPlayerView = playerViewController?.miniPlayerView,
            let closeButton = playerViewController?.closeButton,
            let view = playerViewController?.view else { return }
        
        let tapLocation = recognizer.location(in: view)
        let closeButtonFrame = closeButton.convert(closeButton.frame, to: view).insetBy(dx: -8, dy: -8)
        guard miniPlayerView.frame.contains(tapLocation) || closeButtonFrame.contains(tapLocation) else { return }
        
        startTransitionAnimations(for: !state)
    }

    private func startInteractiveTransition(for finalState: State) {
        startTransitionAnimations(for: finalState)
        runningAnimators.pauseAnimations()
    }
    
    private func startTransitionAnimations(for finalState: State) {
        switch finalState {
        case .opened: runningAnimators = createOpenAnimations(for: finalState)
        case .closed: runningAnimators = createCloseAnimations(for: finalState)
        }
        runningAnimators.startAnimations()
    }
    
    private func isGestureCancelled(with velocity: CGFloat) -> Bool {
        guard velocity != 0 else { return false }
        
        let isPanningDown = velocity > 0
        return (state == .closed && isPanningDown) || (state == .opened && !isPanningDown)
    }
    
    // Scrubs transition on pan .changed
    func updateInteractiveTransition(distanceTraveled: CGFloat) {
        var fraction = distanceTraveled / totalAnimationDistance
        if state == .closed { fraction *= -1 }
//            dump(fraction)
        runningAnimators.fractionComplete = fraction
    }
    
    // Continues or reverse transition on pan .ended
    func continueInteractiveTransition(cancel: Bool) {
        if cancel { runningAnimators.reverse() }
        
        runningAnimators.continueAnimations()
    }

    private func createOpenAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
            transformOpenAnimator(for: finalState, duration: animationDuration),
//            contentOpenAnimator(for: finalState, duration: animationDuration)
            fadeInPlayerAnimator(duration: animationDuration),
            fadeOutMiniPlayerAnimator(duration: animationDuration)
        ]
    }
    
    private func transformOpenAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0, animations: {
            self.updatePlayerContainer(with: finalState)
            self.updateTabBar(with: finalState)
        })
        animator.addCompletion { position in
            self.runningAnimators.remove(animator)
            
            self.state = self.finalState(from: !finalState, position: position)
            self.updateUI(with: self.state)
        }
        return animator
    }
    
    private func fadeInPlayerAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration / 2, curve: .easeIn, animations: {
            self.updatePlayer(with: .opened)
        })
        animator.addCompletion({ _ in self.runningAnimators.remove(animator) })
        animator.scrubsLinearly = false
        return animator
    }
    
    private func fadeOutMiniPlayerAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration / 2, curve: .easeOut, animations: {
            self.updateMiniPlayer(with: .opened)
        })
        animator.addCompletion({ _ in self.runningAnimators.remove(animator) })
        animator.scrubsLinearly = false
        return animator
    }
    
    private func contentOpenAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear, animations: {
            UIView.animateKeyframes(withDuration: 0, delay: 0, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.25) {
                    self.updateMiniPlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.25, relativeDuration: 0.25) {
                    self.updatePlayer(with: finalState)
                }
            })
        })
        animator.addCompletion({ _ in self.runningAnimators.remove(animator) })
        return animator
    }
    
    private func createCloseAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
            transformCloseAnimator(for: finalState, duration: animationDuration),
//            contentCloseAnimator(for: finalState, duration: animationDuration),
            fadeOutPlayerAnimator(duration: animationDuration),
            fadeInMiniPlayerAnimator(duration: animationDuration)
        ]
    }
    
    private func transformCloseAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9, animations: {
            self.updatePlayerContainer(with: finalState)
            self.updateTabBar(with: finalState)
        })
        animator.addCompletion { position in
            self.state = self.finalState(from: !finalState, position: position)
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
            
            // remove animator
            self.runningAnimators.remove(animator)
        }
        return animator
    }
    
    private func fadeOutPlayerAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: { })
        animator.addAnimations({ self.updatePlayer(with: .closed) }, delayFactor: 0.5)
        animator.addCompletion({ _ in self.runningAnimators.remove(animator) })
        animator.scrubsLinearly = false
        return animator
    }

    private func fadeInMiniPlayerAnimator(duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: { })
        animator.addAnimations({ self.updateMiniPlayer(with: .closed) }, delayFactor: 0.5)
        animator.addCompletion({ _ in self.runningAnimators.remove(animator) })
        animator.scrubsLinearly = false
        return animator
    }

    
    private func contentCloseAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .linear, animations: {
            UIView.animateKeyframes(withDuration: 0, delay: 0, animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.75, relativeDuration: 0.25) {
                    self.updateMiniPlayer(with: finalState)
                }
                
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.25) {
                    self.updatePlayer(with: finalState)
                }
            })
        })
        animator.addCompletion { position in
            self.state = self.finalState(from: !finalState, position: position)
            self.updateMiniPlayer(with: self.state)
            self.updatePlayer(with: self.state)
            
            // remove animator
            self.runningAnimators = self.runningAnimators.filter { $0 != animator }
        }
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
        playerViewController?.miniPlayerView.alpha = state == .opened ? 0 : 1
    }
    
    private func updatePlayer(with state: State) {
        guard let playerViewController = playerViewController,
            let tabBarViewController = tabBarViewController else { return }
        
        playerViewController.playerView.alpha = state == .opened ? 1 : 0
        playerViewController.view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        let cornerRadius: CGFloat = playerViewController.view.safeAreaInsets.bottom > tabBarViewController.tabBar.bounds.height ? 20 : 0
        playerViewController.view.layer.cornerRadius = state == .opened ? cornerRadius : 0
    }
    
    private func updatePlayerContainer(with state: State) {
        playerViewController?.view.transform = state == .opened ? .identity : CGAffineTransform(translationX: 0, y: totalAnimationDistance)
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
