//
//  VIewController+FocusSquare.swift
//  ARKit-Drawing
//
//  Created by Ivan Nikitin on 08/04/2019.
//  Copyright © 2019 Chad Zeluff. All rights reserved.
//

import ARKit

extension ViewController {
    
    
    // MARK: - Focus Square
    
    func updateFocusSquare() {
//        {
//            let bounds = sceneView.frame
//            return CGPoint(x: bounds.midX, y: bounds.midY)
//        }
        // Perform hit testing only when ARKit tracking is in a good state.
        guard let screenCenter = screenCenter else { return }
        
        if let camera = session.currentFrame?.camera, case .normal = camera.trackingState,
            let result = sceneView.hitTest(screenCenter, types: .existingPlaneUsingExtent).first {
            
            updateQueue.async {
                self.sceneView.scene.rootNode.addChildNode(self.focusSquare)
                self.focusSquare.state = .detecting(hitTestResult: result, camera: camera)
            }
            
            
        } else {
            updateQueue.async {
                self.focusSquare.state = .initializing
                self.sceneView.pointOfView?.addChildNode(self.focusSquare)
            }
        }
    }
    
}
