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
    
    @IBOutlet private var playerView: UIView!
    @IBOutlet private var miniPlayerView: UIView!
    @IBOutlet private var bottomConstraint: NSLayoutConstraint!
    @IBOutlet private var heightConstraint: NSLayoutConstraint!

    private lazy var closedTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Closed"
        label.font = UIFont.systemFont(ofSize: 16, weight: UIFont.Weight.medium)
        label.textColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
        label.textAlignment = .center
        return label
    }()
    
    private lazy var openTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Open"
        label.font = UIFont.systemFont(ofSize: 24, weight: UIFont.Weight.heavy)
        label.textColor = .black
        label.textAlignment = .center
        label.alpha = 0
        label.transform = CGAffineTransform(scaleX: 0.65, y: 0.65).concatenating(CGAffineTransform(translationX: 0, y: -15))
        return label
    }()
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
    private let animationDuration = TimeInterval(0.6)
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .clear
        playerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        bottomConstraint.constant = popupCollapsedButtomInset
        heightConstraint.constant = popupFullHeight
        playerView.addGestureRecognizer(panGestureRecognizer)
        miniPlayerView.addGestureRecognizer(tapGestureRecognizer)
        
        closedTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        miniPlayerView.addSubview(closedTitleLabel)
        closedTitleLabel.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor).isActive = true
        closedTitleLabel.centerXAnchor.constraint(equalTo: miniPlayerView.centerXAnchor).isActive = true
        
        openTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        miniPlayerView.addSubview(openTitleLabel)
        openTitleLabel.centerYAnchor.constraint(equalTo: miniPlayerView.centerYAnchor).isActive = true
        openTitleLabel.centerXAnchor.constraint(equalTo: miniPlayerView.centerXAnchor).isActive = true
        
        view.layoutIfNeeded()
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            runningAnimators = createAnimations(for: currentState.reversed, duration: animationDuration)
            runningAnimators.startAnimations()
            runningAnimators.pauseAnimations()
        case .changed:
            let translation = recognizer.translation(in: playerView)
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
        // ensure that the animators array is empty (which implies new animations need to be created)
        guard runningAnimators.isEmpty else { return }
        
        runningAnimators = createAnimations(for: currentState.reversed, duration: animationDuration)
        runningAnimators.startAnimations()
    }
    
    private func createAnimations(for finalState: State, duration: TimeInterval) -> [UIViewPropertyAnimator] {
        return [
            transitionAnimator(for: currentState.reversed, duration: animationDuration),
            inTitleAnimator(for: currentState.reversed, duration: animationDuration),
            outTitleAnimator(for: currentState.reversed, duration: animationDuration)
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
    
    // an animator for the title that is transitioning into view
    private func inTitleAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        let inTitleAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeIn, animations: {
            switch finalState {
            case .open:
                self.openTitleLabel.alpha = 1
            case .closed:
                self.closedTitleLabel.alpha = 1
            }
        })
        inTitleAnimator.scrubsLinearly = false
        return inTitleAnimator
    }
    private func outTitleAnimator(for finalState: State, duration: TimeInterval) ->  UIViewPropertyAnimator {
        // an animator for the title that is transitioning out of view
        let outTitleAnimator = UIViewPropertyAnimator(duration: duration, curve: .easeOut, animations: {
            switch finalState {
            case .open:
                self.closedTitleLabel.alpha = 0
            case .closed:
                self.openTitleLabel.alpha = 0
            }
        })
        outTitleAnimator.scrubsLinearly = false
        return outTitleAnimator
    }
    
    private func updateUI(with state: State) {
        view.backgroundColor = color(from: state)
        bottomConstraint.constant = bottomOffset(from: state)
        playerView.layer.cornerRadius = cornerRadius(from: state)
        closedTitleLabel.transform = closedTitleLabelTransform(from: state)
        openTitleLabel.transform = openTitleLabelTransform(from: state)
    }
    
    private func closedTitleLabelTransform(from state: State) -> CGAffineTransform {
        switch state {
        case .open:
            return CGAffineTransform(scaleX: 1.6, y: 1.6).concatenating(CGAffineTransform(translationX: 0, y: 15))
        case .closed:
            return .identity
        }
    }
    
    private func openTitleLabelTransform(from state: State) -> CGAffineTransform {
        switch state {
        case .open:
            return .identity
        case .closed:
            return CGAffineTransform(scaleX: 0.65, y: 0.65).concatenating(CGAffineTransform(translationX: 0, y: -15))
        }
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

