//
//  DrawerViewController.swift
//  Drawer
//
//  Created by Maksym Shcheglov on 16/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

extension Array where Element: UIViewPropertyAnimator {
    
    func startAnimations() {
        forEach { $0.startAnimation() }
    }
    
    func pauseAnimations() {
        forEach { $0.pauseAnimation() }
    }
    
    func continueAnimations(withTimingParameters parameters: UITimingCurveProvider? = nil, durationFactor: CGFloat = 0) {
        forEach { $0.continueAnimation(withTimingParameters: parameters, durationFactor: durationFactor) }
    }
    
    var fractionComplete: CGFloat {
        set {
            forEach { $0.fractionComplete = newValue }
        }
        get {
            assertionFailure("The getter is not supported!")
            return 0
        }
    }
}

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
    
    private lazy var popupView: UIView = {
        let view = UIView()
        view.backgroundColor = .darkGray
        view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
        return view
    }()
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
    private var bottomConstraint = NSLayoutConstraint()
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
    
    private lazy var popupFullHeight = {
        return view.bounds.inset(by: view.safeAreaInsets).height - popupTopOffset + popupBottomInsetHeight
    }()
    private let popupCollapsedHeight = CGFloat(54)
    private lazy var popupOffset: CGFloat = {
        return popupFullHeight - popupCollapsedHeight
    }()
    private let popupBottomInsetHeight = CGFloat(100)
    private let popupTopOffset = CGFloat(24)
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
        popupView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(popupView)
        popupView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        popupView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        popupView.heightAnchor.constraint(equalToConstant: popupFullHeight).isActive = true
        bottomConstraint = popupView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: popupOffset)
        bottomConstraint.isActive = true
        popupView.addGestureRecognizer(panGestureRecognizer)
        popupView.addGestureRecognizer(tapGestureRecognizer)
        
        let miniView = UIView()
        miniView.backgroundColor = .clear
        miniView.translatesAutoresizingMaskIntoConstraints = false
        popupView.addSubview(miniView)
        miniView.topAnchor.constraint(equalTo: popupView.topAnchor).isActive = true
        miniView.leadingAnchor.constraint(equalTo: popupView.leadingAnchor).isActive = true
        miniView.trailingAnchor.constraint(equalTo: popupView.trailingAnchor).isActive = true
        miniView.heightAnchor.constraint(equalToConstant: popupCollapsedHeight).isActive = true

        popupView.addSubview(miniView)
        
        closedTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        miniView.addSubview(closedTitleLabel)
        closedTitleLabel.centerYAnchor.constraint(equalTo: miniView.centerYAnchor).isActive = true
        closedTitleLabel.centerXAnchor.constraint(equalTo: miniView.centerXAnchor).isActive = true
        
        openTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        miniView.addSubview(openTitleLabel)
        openTitleLabel.centerYAnchor.constraint(equalTo: miniView.centerYAnchor).isActive = true
        openTitleLabel.centerXAnchor.constraint(equalTo: miniView.centerXAnchor).isActive = true
    }
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            runningAnimators = createAnimations(for: currentState.reversed, duration: animationDuration)
            runningAnimators.startAnimations()
            runningAnimators.pauseAnimations()
        case .changed:
            let translation = recognizer.translation(in: popupView)
            var fraction = -translation.y / popupOffset
            if currentState == .open { fraction *= -1 }
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
        popupView.layer.cornerRadius = cornerRadius(from: state)
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
            return popupBottomInsetHeight
        case .closed:
            return popupOffset
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

extension UIViewController {
    public func add(_ child: UIViewController, insets: UIEdgeInsets = .zero) {
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        child.didMove(toParent: self)
    }
    
    public func remove(_ child: UIViewController) {
        guard child.parent != nil else {
            return
        }
        
        child.willMove(toParent: nil)
        child.view.removeFromSuperview()
        child.removeFromParent()
    }
}

