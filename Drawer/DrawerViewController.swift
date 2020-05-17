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
    func didContinueStateChange(to state: DrawerViewController.State)
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
        updateUI(with: .closed)
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
            
            delegate?.didContinueStateChange(to: currentState.reversed)
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
//        switch finalState {
//        case .open:
//            runningAnimators[0].startAnimation()
//            runningAnimators[1].startAnimation()
//            runningAnimators[2].startAnimation(afterDelay: miniPlayerAnimationDuration)
//        case .closed:
//            runningAnimators[0].startAnimation()
//            runningAnimators[1].startAnimation(afterDelay: showPlayerAnimationDuration - miniPlayerAnimationDuration)
//            runningAnimators[2].startAnimation(afterDelay: showPlayerAnimationDuration - miniPlayerAnimationDuration - playerAnimationDuration)
//        }
        runningAnimators.startAnimations()
    }
    
    private func createAnimations(for finalState: State) -> [UIViewPropertyAnimator] {
//        return [
//            transitionAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration),
//            miniPlayerAnimator(for: currentState.reversed, duration: miniPlayerAnimationDuration),
//            playerContentAnimator(for: currentState.reversed, duration: playerAnimationDuration)
//        ]
        return [
            transitionAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration),
            miniPlayerAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration),
            playerContentAnimator(for: currentState.reversed, duration: showPlayerAnimationDuration)
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
    
    private func miniPlayerAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let miniPlayerAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: {
            self.miniPlayerView.alpha = finalState == .open ? 0 : 1
        })
        miniPlayerAnimator.scrubsLinearly = false
        return miniPlayerAnimator
    }
    
    private func playerContentAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let playerContentAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: {
            self.playerView.alpha = finalState == .open ? 1 : 0
        })
        playerContentAnimator.scrubsLinearly = false
        return playerContentAnimator
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

