//
//  Array+UIViewPropertyAnimator.swift
//  SpotifyPlayer
//
//  Created by Maksym Shcheglov on 17/05/2020.
//  Copyright © 2020 Maksym Shcheglov. All rights reserved.
//

import UIKit

extension Array where Element: UIViewPropertyAnimator {
    
    var isReversed: Bool {
        set {
            forEach { $0.isReversed = newValue }
        }
        get {
            assertionFailure("The getter is not supported!")
            return false
        }
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
    
    func startAnimations() {
        forEach { $0.startAnimation() }
    }
    
    func pauseAnimations() {
        forEach { $0.pauseAnimation() }
    }
    
    func continueAnimations(withTimingParameters parameters: UITimingCurveProvider? = nil, durationFactor: CGFloat = 0) {
        forEach { $0.continueAnimation(withTimingParameters: parameters, durationFactor: durationFactor) }
    }
    
    func reverse() {
        forEach { $0.isReversed = !$0.isReversed }
    }
    
    mutating func remove(_ element: Element) {
        self = self.filter { $0 != element }
    }
}
