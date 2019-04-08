import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Node selected by user
    var selectedNode: SCNNode?
    
    /// Nodes placed by the user
    var placedNodes = [SCNNode]()
    
    /// Visualisation planes placed when detecting planes
    var planeNodes = [SCNNode]()
    
    var drawingLine = [SCNNode]()
    var drawing = [[SCNNode]()]
    
    /// Coordinate of last placed point
    var lastObjectPlasedPoint: CGPoint?
    
    /// Minimum distance between nearby points (2D coordinates )
    let touchDistanceThreshold = CGFloat(40)
    
    /// Toggle plane visualisation
    var showPlaneOverlay = false {
        didSet {
            planeNodes.forEach { (plane) in
                plane.isHidden = !showPlaneOverlay
            }
        }
    }
    var focusSquare = FocusSquare()
    
    var session: ARSession {
        return sceneView.session
    }
    let updateQueue = DispatchQueue(label: "com.example.apple-samplecode.arkitexample.serialSceneKitQueue")
    
    var screenCenter: CGPoint {
        let bounds = sceneView.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    enum ObjectPlacementMode {
        case freeform, plane, image, draw
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reloadConfiguration(removeAnchors: false)
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.scene.rootNode.addChildNode(focusSquare)
        focusSquare.isHidden = true
        hideButtonsFromView(true)
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadConfiguration(removeAnchors: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            showPlaneOverlay = false
            focusSquare.isHidden = true
            hideButtonsFromView(true)
        case 1:
            objectMode = .plane
            showPlaneOverlay = true
            focusSquare.isHidden = false
            hideButtonsFromView(false)
        case 2:
            objectMode = .image
            showPlaneOverlay = false
            focusSquare.isHidden = true
            hideButtonsFromView(true)
        case 3:
            objectMode = .draw
            showPlaneOverlay = true
            focusSquare.isHidden = true
            minusButton.isHidden = false
            plusButton.isHidden = true
            
        default:
            break
        }
    }
    
    @IBAction func plusButtonPressed(_ sender: UIButton) {
        
        guard let node = selectedNode else { return }
        
        switch objectMode {
        case .freeform:
            addNodeInFront(node)
        case .plane:
            addNode(node, to: screenCenter)
            break
        case .image:
            break
        case .draw:
            break
        }
        
    }
    @IBAction func minusButtonPressed(_ sender: UIButton) {
        undoLastObject()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showOptions" {
            let optionsViewController = segue.destination as! OptionsContainerViewController
            optionsViewController.delegate = self
        }
    }
}

extension ViewController: OptionsViewControllerDelegate {
    
    /// Called when user selects an object
    ///
    /// - Parameter node: SCNNode of an object selected by user
    func objectSelected(node: SCNNode) {
        dismiss(animated: true, completion: nil)
        selectedNode = node
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        showPlaneOverlay.toggle()
    }
    
    func undoLastObject() {
        if objectMode == .draw {
            
            guard let line = drawing.last else { return }
            
                    line.forEach{$0.removeFromParentNode()}
                drawing.removeLast()
            
            } else {
            guard let lastNode = placedNodes.last else {
                dismiss(animated: true, completion: nil)
                return }
            lastNode.removeFromParentNode()
            placedNodes.removeLast()
            
        }
    }
    
    /// Discard all actions
    func resetScene() {
        dismiss(animated: true, completion: nil)
        reloadConfiguration()
        
    }
}

// MARK: - View Controller Touches
extension ViewController {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first else { return }
        guard let node = selectedNode else { return }
        
        switch objectMode {
        case .freeform:
            addNodeInFront(node)
        case .plane:
            //            let point = touch.location(in: sceneView)
            //            addNode(node, to: point)
            break
        case .image:
            
            break
        case .draw:
            break
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        
        guard let touch = touches.first else { return }
        let newTouchPoint = touch.location(in: sceneView)
        if objectMode == .draw {
            
            let pencil = SCNNode(geometry: SCNCylinder(radius: 0.01, height: 0.001))
            pencil.geometry?.firstMaterial?.diffuse.contents = UIColor.black
            addNode(pencil, to: newTouchPoint)
        }
        guard let selectedNode = selectedNode else { return }
        guard let lastTouchPoint = lastObjectPlasedPoint else { return }
        
        
        
        let deltaX = newTouchPoint.x - lastTouchPoint.x
        let deltaY = newTouchPoint.y - lastTouchPoint.y
        let distanceSquare = deltaX * deltaX + deltaY * deltaY
        
        guard touchDistanceThreshold * touchDistanceThreshold < distanceSquare else { return }
        
        switch objectMode {
        case .freeform:
            break
        case .image:
            break
        case .plane:
            
            addNode(selectedNode, to: newTouchPoint)
            break
        case .draw:
            break
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        drawing.append(drawingLine)
        drawingLine.removeAll()
        print("End of touch")
        lastObjectPlasedPoint = nil
    }
}

// MARK: - Placement Methods
extension ViewController {
    
    /// Add node po parent node
    ///
    /// - Parameters:
    ///   - node: node which will be added
    ///   - parentNode: parent node to which the node to be added
    func addNode(_  node: SCNNode, to parentNode: SCNNode, isFloor: Bool = false) {
        let cloneNode = isFloor ? node : node.clone()
        
        if objectMode == .draw {
            drawingLine.append(cloneNode)
            parentNode.addChildNode(cloneNode)
        } else {
            parentNode.addChildNode(cloneNode)
            if isFloor {
                planeNodes.append(cloneNode)
            } else {
                placedNodes.append(cloneNode)
            }
        }
        
    }
    
    /// Add a node using a point on the screen
    ///
    /// - Parameters:
    ///   - node: selected node to add
    ///   - point: point at the screen to use
    func addNode(_ node: SCNNode, to point: CGPoint) {
        
        let results = sceneView.hitTest(point, types: .existingPlaneUsingExtent)
        guard let match = results.first else { return }
        
        if let anchor = match.anchor as? ARPlaneAnchor {
            if anchor.alignment == .vertical {
                let transform = match.worldTransform
                let translate = transform.columns.3
                let x = translate.x
                let y = translate.y
                let z = translate.z
                node.position = SCNVector3(x, y, z)
                node.eulerAngles.x = -.pi/2
                addNodeToSceneRoot(node)
                lastObjectPlasedPoint = point
            } else {
                
                let transform = match.worldTransform
                let translate = transform.columns.3
                let x = translate.x
                let y = translate.y
                let z = translate.z
                node.position = SCNVector3(x, y, z)
                addNodeToSceneRoot(node)
                lastObjectPlasedPoint = point
            }
        }
    }
    
    /// Places object defined by node at 20 cm befor the camera
    ///
    /// - Parameter node: SCNNode to place in scene
    func addNodeInFront(_ node: SCNNode) {
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        node.simdTransform =  matrix_multiply(currentFrame.camera.transform, translation)
        addNodeToSceneRoot(node)
    }
    
    /// Clones and adds an object defined by node to scene root
    ///
    /// - Parameter node: SCNNode which will be added
    func addNodeToSceneRoot(_ node: SCNNode) {
        let rootNode = sceneView.scene.rootNode
        addNode(node, to: rootNode)
        
    }
    
    /// Create visualisation  plane
    ///
    /// - Parameter planeAnchor: Detected anchor
    /// - Returns: node of created  visualisation  plane
    func createFloor(planeAnchor: ARPlaneAnchor) -> SCNNode {
        let node = SCNNode()
        let extent = planeAnchor.extent
        let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        
        plane.materials.first?.diffuse.contents = UIColor.cyan
        node.geometry = plane
        node.eulerAngles.x = -Float.pi/2
        node.name = "Plane"
        node.opacity = 0.25
        
        return node
    }
    
    /// Plane node AR anchor has added to the scene
    ///
    /// - Parameters:
    ///   - node: node which was added
    ///   - anchor: AR plane  anchor which defines the plane found
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        let floor = createFloor(planeAnchor: anchor)
        floor.isHidden = !showPlaneOverlay
        addNode(floor, to: node, isFloor: true)
    }
    /// Image node AR anchor has added to the scene
    ///
    /// - Parameters:
    ///   - node: node which was added
    ///   - anchor: AR image anchor which defines the image found
    func nodeAdded(_ node: SCNNode, for anchor: ARImageAnchor) {
        guard let selectedNode = selectedNode else { return }
        addNode(selectedNode, to: node)
    }
}



// MARK: - ARSCNViewDelegate
extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let planeAnchor = anchor as? ARPlaneAnchor {
            if objectMode == .plane || objectMode == .draw {
                let plane = createFloor(planeAnchor: planeAnchor)
                node.addChildNode(plane)
                planeNodes.append(plane)
            }
        } else if let planeAnchor = anchor as?  ARImageAnchor {
            if objectMode == .image {
                nodeAdded(node, for: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let anchor = anchor as? ARPlaneAnchor else { return }
        guard let planeNode = node.childNodes.first else { return }
        guard let plane = planeNode.geometry as? SCNPlane else { return }
        guard planeNode.name == "Plane" else { return }
        
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
        planeNode.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        planeNode.geometry?.firstMaterial?.diffuse.contents = UIColor.green
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        updateFocusSquare()
    }
}
// MARK: - Configuration Methods
extension ViewController {
    func reloadConfiguration(removeAnchors: Bool = true) {
        
        configuration.planeDetection = [.horizontal, .vertical]
        
        let images = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources" , bundle: nil)
        configuration.detectionImages = objectMode == .image ?  images : nil
        
        let options: ARSession.RunOptions
        
        if removeAnchors {
            options = [.removeExistingAnchors]
            for node in planeNodes {
                node.removeFromParentNode()
            }
            planeNodes.removeAll()
            for node in placedNodes {
                node.removeFromParentNode()
            }
            placedNodes.removeAll()
        } else {
            options = []
        }
        
        sceneView.session.run(configuration, options: options)
        
    }
}

// MARK: - Custom Methods
extension ViewController {
    func hideButtonsFromView(_ isHidden: Bool) {
        plusButton.isHidden = isHidden
        minusButton.isHidden = isHidden
    }
}
