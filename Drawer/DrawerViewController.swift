//
//  DrawerViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

protocol DrawerViewControllerDelegate: class {
    func didTriggerStateChange(to state: DrawerViewController.State)
    
    func didStartStateChange(to state: DrawerViewController.State)
    func didProgressStateChange(to state: DrawerViewController.State, fraction: CGFloat)
    func didContinueStateChange(to state: DrawerViewController.State, isReversed: Bool)
    func didFinishStateChange(to state: DrawerViewController.State)
}

class DrawerViewController : UIViewController, UIGestureRecognizerDelegate {
    
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
    
    @IBOutlet private var playerContainerView: UIView!
    @IBOutlet private var miniPlayerView: UIView!
    @IBOutlet private var playerView: UIView!

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
    /// All of the currently running animators.
    private var runningAnimators = [UIViewPropertyAnimator]()
    private var currentState: State = .closed {
        didSet {
            print("current state: \(currentState)")
        }
    }
    weak var delegate: DrawerViewControllerDelegate?
    
    private var popupCollapsedButtomInset: CGFloat { playerContainerView.bounds.height - view.safeAreaInsets.bottom  - miniPlayerView.bounds.height - 100}
    private let showPlayerAnimationDuration = TimeInterval(0.6)
    private var miniPlayerAnimationDuration: TimeInterval { return showPlayerAnimationDuration * 0.2 }
    private var playerAnimationDuration: TimeInterval { return showPlayerAnimationDuration * 0.1 }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        playerContainerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        playerContainerView.addGestureRecognizer(panGestureRecognizer)
        playerContainerView.addGestureRecognizer(tapGestureRecognizer)
        updateUI(with: currentState)
        miniPlayerView.alpha = currentState == .open ? 0 : 1
        playerView.alpha = currentState == .open ? 1 : 0
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            runningAnimators = createAnimations(for: currentState.reversed)
            startAnimations(for: currentState.reversed)
            runningAnimators.pauseAnimations()
            
            delegate?.didStartStateChange(to: currentState.reversed)
        case .changed:
            let translation = recognizer.translation(in: playerContainerView)
            var fraction = -translation.y / popupCollapsedButtomInset
            if currentState == .open { fraction *= -1 }
            runningAnimators.fractionComplete = fraction
            
            delegate?.didProgressStateChange(to: currentState.reversed, fraction: fraction)
        case .ended:
            runningAnimators.continueAnimations()
            
            // variable setup
            let yVelocity = recognizer.velocity(in: playerContainerView).y
            let shouldClose = yVelocity > 0
            
            // if there is no motion, continue all animations and exit early
            if yVelocity == 0 {
                runningAnimators.continueAnimations()
                delegate?.didContinueStateChange(to: currentState.reversed, isReversed: runningAnimators[0].isReversed)
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
            
            
            delegate?.didContinueStateChange(to: currentState.reversed, isReversed: runningAnimators[0].isReversed)
        default:
            ()
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return runningAnimators.isEmpty
    }
    
    @objc private func popupViewTapped(recognizer: UITapGestureRecognizer) {
        guard miniPlayerView.frame.contains(recognizer.location(in: self.playerContainerView)) else { return }
        runningAnimators = createAnimations(for: currentState.reversed)
        startAnimations(for: currentState.reversed)
        delegate?.didTriggerStateChange(to: currentState.reversed)
    }
    
    private func startAnimations(for finalState: State) {
        runningAnimators.startAnimations()
    }
    
    private func createAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
        return [
            transitionAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration),
            contentAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration)
        ]
    }
    
    private func transitionAnimator(for finalState: State, duration: TimeInterval) -> UIViewPropertyAnimator {
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 0.7, animations: {
            self.updateUI(with: finalState)
            self.view.layoutIfNeeded()
        })
        transitionAnimator.addCompletion { position in
            self.currentState = self.finalState(from: finalState.reversed, position: position)
            self.updateUI(with: self.currentState)
            
            self.delegate?.didFinishStateChange(to: self.currentState)
            
            // remove all running animators
            self.runningAnimators.removeAll()
        }
        return transitionAnimator
    }
    
    private func contentAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        return UIViewPropertyAnimator(duration: duration, curve: .linear) {
          UIView.animateKeyframes(withDuration: duration, delay: 0, animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.1) {
              self.miniPlayerView.alpha = finalState == .open ? 0 : 1
            }

            UIView.addKeyframe(withRelativeStartTime: 0.1, relativeDuration: 0.4) {
              self.playerView.alpha = finalState == .open ? 1 : 0
            }
          })
        }
    }
    
    private func updateUI(with state: State) {
        view.backgroundColor = state == .open ? UIColor.black.withAlphaComponent(0.3) : .clear
        playerContainerView.transform = state == .open ? .identity : CGAffineTransform(translationX: 0, y: popupCollapsedButtomInset)
        playerContainerView.layer.cornerRadius = state == .open ? 10 : 0
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

