//
//  DrawerViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

class DrawerViewController : UIViewController, UIGestureRecognizerDelegate {
    
    private enum State {
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
    @IBOutlet private var tapHandlerView: UIView!
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private var heightConstraint: NSLayoutConstraint!

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
    
    private var popupFullHeight : CGFloat { view.bounds.height - popupTopInset }
    private var popupBottomInset: CGFloat { view.safeAreaInsets.bottom } // extend background to safe area
    private var popupTopInset: CGFloat { view.safeAreaInsets.top + 24 }
    private var popupCollapsedHeight: CGFloat { miniPlayerView.bounds.height }
    private var popupCollapsedButtomInset: CGFloat { popupCollapsedHeight + popupBottomInset - popupFullHeight }
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
        bottomConstraint.constant = popupCollapsedButtomInset
        heightConstraint.constant = popupFullHeight
        playerContainerView.addGestureRecognizer(panGestureRecognizer)
        tapHandlerView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            runningAnimators = createAnimations(for: currentState.reversed)
            startAnimations(for: currentState.reversed)
            runningAnimators.pauseAnimations()
        case .changed:
            let translation = recognizer.translation(in: playerContainerView)
            var fraction = -translation.y / popupCollapsedButtomInset
            if currentState == .closed { fraction *= -1 }
            runningAnimators.fractionComplete = fraction
        case .ended:
            runningAnimators.continueAnimations()
        default:
            ()
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return runningAnimators.isEmpty
    }
    
    @objc private func popupViewTapped(recognizer: UITapGestureRecognizer) {
        runningAnimators = createAnimations(for: currentState.reversed)
        startAnimations(for: currentState.reversed)
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
            
            // remove all running animators
            self.runningAnimators.removeAll()
        }
        return transitionAnimator
    }
    
    private func miniPlayerAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let miniPlayerAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: {
            switch finalState {
            case .open:
                self.miniPlayerView.alpha = 0
            case .closed:
                self.miniPlayerView.alpha = 1
            }
        })
        miniPlayerAnimator.scrubsLinearly = false
        return miniPlayerAnimator
    }
    
    private func playerContentAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let outTitleAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: {
            switch finalState {
            case .open:
                self.playerView.alpha = 1
            case .closed:
                self.playerView.alpha = 0
            }
        })
        outTitleAnimator.scrubsLinearly = false
        return outTitleAnimator
    }
    
    private func updateUI(with state: State) {
        view.backgroundColor = color(from: state)
        bottomConstraint.constant = bottomOffset(from: state)
        playerContainerView.layer.cornerRadius = cornerRadius(from: state)
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

    private func color(from state: State) -> UIColor {
        switch state {
        case .open:
            return UIColor.black.withAlphaComponent(0.3)
        case .closed:
            return .clear
        }
    }
    
    private func bottomOffset(from state: State) -> CGFloat {
        switch state {
        case .open:
            return 0
        case .closed:
            return popupCollapsedButtomInset
        }
    }
    
    private func cornerRadius(from state: State) -> CGFloat {
        switch state {
        case .open:
            return 10
        case .closed:
            return 0
        }
    }
}

