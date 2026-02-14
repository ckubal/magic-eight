//
//  MotionManager.swift
//  magic eight
//
//  Created by Charlie Kubal on 12/1/25.
//

import Foundation
import CoreMotion
import Combine

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var isFaceDown = false
    @Published var shakeIntensity: Double = 0.0
    @Published var tiltX: Double = 0.0
    @Published var tiltY: Double = 0.0
    
    // Throttled publishers for efficient updates
    var throttledTiltX: AnyPublisher<Double, Never> {
        $tiltX
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    var throttledTiltY: AnyPublisher<Double, Never> {
        $tiltY
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    var throttledShakeIntensity: AnyPublisher<Double, Never> {
        $shakeIntensity
            .throttle(for: .milliseconds(50), scheduler: DispatchQueue.main, latest: true)
            .eraseToAnyPublisher()
    }
    
    private var previousAcceleration: CMAcceleration?
    private var shakeHistory: [Double] = []
    private let shakeHistorySize = 10
    
    init() {
        setupMotionManager()
    }
    
    private func setupMotionManager() {
        guard motionManager.isAccelerometerAvailable else {
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.05 // 20 Hz for smoother updates
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            // Suppress CoreMotion permission warnings - they're harmless
            guard let self = self, let acceleration = data?.acceleration else { return }
            
            // Detect face down/face up orientation
            // When face down, z-axis acceleration is positive (gravity pulling down on screen)
            // When face up, z-axis acceleration is negative (gravity pulling up on screen)
            let isCurrentlyFaceDown = acceleration.z > 0.7
            
            if isCurrentlyFaceDown != self.isFaceDown {
                self.isFaceDown = isCurrentlyFaceDown
            }
            
            // Calculate shake intensity based on acceleration changes
            if let previous = self.previousAcceleration {
                let deltaX = abs(acceleration.x - previous.x)
                let deltaY = abs(acceleration.y - previous.y)
                let deltaZ = abs(acceleration.z - previous.z)
                let magnitude = sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
                
                self.shakeHistory.append(magnitude)
                if self.shakeHistory.count > self.shakeHistorySize {
                    self.shakeHistory.removeFirst()
                }
                
                // Average shake intensity over recent history
                let avgShake = self.shakeHistory.reduce(0, +) / Double(self.shakeHistory.count)
                self.shakeIntensity = min(avgShake * 10, 1.0) // Normalize to 0-1
            }
            
            self.previousAcceleration = acceleration
            
            // Track tilt for gravity effect (x and y accelerations when device is upright)
            // When device is tilted, these values change
            if !isCurrentlyFaceDown {
                self.tiltX = acceleration.x
                self.tiltY = acceleration.y
            } else {
                // When face down, reset tilt
                self.tiltX = 0.0
                self.tiltY = 0.0
            }
        }
    }
    
    deinit {
        motionManager.stopAccelerometerUpdates()
    }
}


