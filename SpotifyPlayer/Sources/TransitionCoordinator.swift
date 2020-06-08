//
//  TransitionCoordinator.swift
//  SpotifyPlayer
//
//  Created by Maksym Shcheglov on 22/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class TransitionCoordinator: NSObject {
    
    enum State: Equatable {
        case open
        case closed
        
        static prefix func !(_ state: State) -> State {
            return state == .open ? .closed : .open
        }
    }
    
    private weak var tabBarViewController: TabBarController!
    private weak var playerViewController: PlayerViewController!
    
    private lazy var panGestureRecognizer = createPanGestureRecognizer()
    private lazy var tapGestureRecognizer = createTapGestureRecognizer()
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var state: State = .closed
    private var totalAnimationDistance: CGFloat {
        guard let playerViewController = playerViewController else { return 0 }
        return playerViewController.view.bounds.height - playerViewController.view.safeAreaInsets.bottom - playerViewController.miniPlayerView.bounds.height
    }

    init(tabBarViewController: TabBarController, playerViewController: PlayerViewController) {
        self.tabBarViewController = tabBarViewController
        self.playerViewController = playerViewController
        super.init()
        playerViewController.view.addGestureRecognizer(panGestureRecognizer)
        playerViewController.view.addGestureRecognizer(tapGestureRecognizer)
        updateUI(with: state)
    }
}

// MARK: Tap and Pan gestures handling
extension TransitionCoordinator {

    @objc private func didPanPlayer(recognizer: UIPanGestureRecognizer) {
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

    @objc private func didTapPlayer(recognizer: UITapGestureRecognizer) {
        animateTransition(for: !state)
    }

    // Starts transition and pauses on pan .begin
    private func startInteractiveTransition(for state: State) {
        animateTransition(for: state)
        runningAnimators.pauseAnimations()
    }

    // Scrubs transition on pan .changed
    private func updateInteractiveTransition(distanceTraveled: CGFloat) {
        var fraction = distanceTraveled / totalAnimationDistance
        if state == .open { fraction *= -1 }
        runningAnimators.fractionComplete = fraction
    }

    // Continues or reverse transition on pan .ended
    private func continueInteractiveTransition(cancel: Bool) {
        if cancel {
            runningAnimators.reverse()
            state = !state
        }

        runningAnimators.continueAnimations()
    }

    // Perform all animations with animators
    private func animateTransition(for newState: State) {
        state = newState
        runningAnimators = createTransitionAnimators(with: TransitionCoordinator.animationDuration)
        runningAnimators.startAnimations()
    }

    // Check if gesture is cancelled (reversed)
    private func isGestureCancelled(with velocity: CGFloat) -> Bool {
        guard velocity != 0 else { return false }

        let isPanningDown = velocity > 0
        return (state == .open && isPanningDown) || (state == .closed && !isPanningDown)
    }
}

extension TransitionCoordinator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let tapGestureRecognizer = gestureRecognizer as? UITapGestureRecognizer else { return runningAnimators.isEmpty }

        guard let miniPlayerView = playerViewController.miniPlayerView,
            let closeButton = playerViewController.closeButton,
            let view = playerViewController.view else { return false }

        let tapLocation = tapGestureRecognizer.location(in: view)
        let closeButtonFrame = closeButton.convert(closeButton.frame, to: view).insetBy(dx: -8, dy: -8)
        
        return runningAnimators.isEmpty && (miniPlayerView.frame.contains(tapLocation) || closeButtonFrame.contains(tapLocation))
    }

    private func createPanGestureRecognizer() -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(didPanPlayer(recognizer:)))
        recognizer.delegate = self
        return recognizer
    }

    private func createTapGestureRecognizer() -> UITapGestureRecognizer {
        let recognizer = UITapGestureRecognizer()
        recognizer.addTarget(self, action: #selector(didTapPlayer(recognizer:)))
        recognizer.delegate = self
        return recognizer
    }

}

// MARK: Animators
extension TransitionCoordinator {

    private static let animationDuration = TimeInterval(0.7)

    private func createTransitionAnimators(with duration: TimeInterval) -> [UIViewPropertyAnimator] {
        switch state {
        case .open:
            return [
                openPlayerAnimator(with: duration),
                fadeInPlayerAnimator(with: duration),
                fadeOutMiniPlayerAnimator(with: duration)
            ]
        case .closed:
            return [
                closePlayerAnimator(with: duration),
                fadeOutPlayerAnimator(with: duration),
                fadeInMiniPlayerAnimator(with: duration)
            ]
        }
    }

    private func openPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0)
        addAnimation(to: animator, animations: {
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
        })
        return animator
    }

    private func fadeInPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeIn)
        addKeyframeAnimation(to: animator, withRelativeStartTime: 0.0, relativeDuration: 0.5) {
            self.updatePlayer(with: self.state)
        }
        animator.scrubsLinearly = false
        return animator
    }

    private func fadeOutMiniPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut)
        addKeyframeAnimation(to: animator, withRelativeStartTime: 0.0, relativeDuration: 0.5) {
            self.updateMiniPlayer(with: self.state)
        }
        animator.scrubsLinearly = false
        return animator
    }

    private func closePlayerAnimator(with duration: TimeInterval) ->  UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9)
        addAnimation(to: animator, animations: {
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
        })
        return animator
    }

    private func fadeOutPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut)
        addKeyframeAnimation(to: animator, withRelativeStartTime: 0.5, relativeDuration: 0.5) {
            self.updatePlayer(with: self.state)
        }
        animator.scrubsLinearly = false
        return animator
    }

    private func fadeInMiniPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeIn)
        addKeyframeAnimation(to: animator, withRelativeStartTime: 0.5, relativeDuration: 0.5) {
            self.updateMiniPlayer(with: self.state)
        }
        animator.scrubsLinearly = false
        return animator
    }

    private func addAnimation(to animator: UIViewPropertyAnimator, animations: @escaping () -> Void) {
        animator.addAnimations { animations() }
        animator.addCompletion({ _ in
            animations()
            self.runningAnimators.remove(animator)
        })
    }

    private func addKeyframeAnimation(to animator: UIViewPropertyAnimator, withRelativeStartTime frameStartTime: Double = 0.0, relativeDuration frameDuration: Double = 1.0, animations: @escaping () -> Void) {
        animator.addAnimations {
            UIView.animateKeyframes(withDuration: 0, delay: 0, options:[], animations: {
                UIView.addKeyframe(withRelativeStartTime: frameStartTime, relativeDuration: frameDuration) {
                    animations()
                }
            })
        }
        animator.addCompletion({ _ in
            animations()
            self.runningAnimators.remove(animator)
        })
    }
}


// MARK: UI state rendering
extension TransitionCoordinator {

    private func updateUI(with state: State) {
        updatePlayer(with: state)
        updateMiniPlayer(with: state)
        updatePlayerContainer(with: state)
        updateTabBar(with: state)
    }

    private func updateTabBar(with state: State) {
        guard let tabBarViewController = tabBarViewController, let tabBarContainer = tabBarViewController.tabBarContainer else { return }
        tabBarContainer.transform = state == .closed ? .identity : CGAffineTransform(translationX: 0, y: tabBarContainer.bounds.height)
        tabBarViewController.shouldHideStatusBar = state == .open
        tabBarViewController.setNeedsStatusBarAppearanceUpdate()
    }

    private func updateMiniPlayer(with state: State) {
        playerViewController?.miniPlayerView.alpha = state == .open ? 0 : 1
    }

    private func updatePlayer(with state: State) {
        guard let playerViewController = playerViewController,
            let tabBarViewController = tabBarViewController else { return }

        playerViewController.playerView.alpha = state == .open ? 1 : 0
        playerViewController.view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        let cornerRadius: CGFloat = playerViewController.view.safeAreaInsets.bottom > tabBarViewController.tabBar.bounds.height ? 20 : 0
        playerViewController.view.layer.cornerRadius = state == .open ? cornerRadius : 0
    }

    private func updatePlayerContainer(with state: State) {
        playerViewController?.view.transform = state == .open ? .identity : CGAffineTransform(translationX: 0, y: totalAnimationDistance)
    }
}
