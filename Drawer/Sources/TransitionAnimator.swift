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
    
    private weak var tabBarViewController: TabBarController?
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
extension TransitionAnimator {

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
        if state == .opened { fraction *= -1 }
        //            dump(fraction)
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
        runningAnimators = createTransitionsAnimators(with: TransitionAnimator.animationDuration)
        runningAnimators.startAnimations()
    }

    // Check if gesture is cancelled (reversed)
    private func isGestureCancelled(with velocity: CGFloat) -> Bool {
        guard velocity != 0 else { return false }

        let isPanningDown = velocity > 0
        return (state == .opened && isPanningDown) || (state == .closed && !isPanningDown)
    }
}

extension TransitionAnimator: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return runningAnimators.isEmpty
    }
}

// MARK: Animators
extension TransitionAnimator {

    private static let animationDuration = TimeInterval(0.7)

    private func createTransitionsAnimators(with duration: TimeInterval) -> [UIViewPropertyAnimator] {
        switch state {
        case .opened:
            return [
                transformOpenAnimator(with: duration),
                fadeInPlayerAnimator(with: duration),
                fadeOutMiniPlayerAnimator(with: duration)
            ]
        case .closed:
            return [
                transformCloseAnimator(with: duration),
                fadeOutPlayerAnimator(with: duration),
                fadeInMiniPlayerAnimator(with: duration)
            ]
        }
    }

    private func transformOpenAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0, animations: {
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
        })
        animator.addCompletion { position in
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
            self.runningAnimators.remove(animator)
        }
        return animator
    }

    private func fadeInPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: {
            UIView.animateKeyframes(withDuration: 0, delay: 0, options:[], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                    self.updatePlayer(with: self.state)
                }
            })
        })
        animator.addCompletion({ _ in
            self.updatePlayer(with: self.state)
            self.runningAnimators.remove(animator)
        })
        animator.scrubsLinearly = false
        return animator
    }

    private func fadeOutMiniPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: {
            UIView.animateKeyframes(withDuration: 0, delay: 0, options:[], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                    self.updateMiniPlayer(with: self.state)
                }
            })
        })
        animator.addCompletion({ _ in
            self.updateMiniPlayer(with: self.state)
            self.runningAnimators.remove(animator)
        })
        animator.scrubsLinearly = false
        return animator
    }

    private func transformCloseAnimator(with duration: TimeInterval) ->  UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.9, animations: {
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
        })
        animator.addCompletion { position in
            self.updatePlayerContainer(with: self.state)
            self.updateTabBar(with: self.state)
            self.runningAnimators.remove(animator)
        }
        return animator
    }

    private func fadeOutPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: {
            UIView.animateKeyframes(withDuration: 0, delay: 0, options:[], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    self.updatePlayer(with: self.state)
                }
            })
        })
        animator.addCompletion({ _ in
            self.updatePlayer(with: self.state)
            self.runningAnimators.remove(animator)
        })
        animator.scrubsLinearly = false
        return animator
    }

    private func fadeInMiniPlayerAnimator(with duration: TimeInterval) -> UIViewPropertyAnimator {
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: {
            UIView.animateKeyframes(withDuration: 0, delay: 0, options:[], animations: {
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    self.updateMiniPlayer(with: self.state)
                }
            })
        })
        animator.addCompletion({ _ in
            self.updateMiniPlayer(with: self.state)
            self.runningAnimators.remove(animator)
        })
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
}
