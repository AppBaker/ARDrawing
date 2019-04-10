import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    @IBOutlet var sceneView: VirtualObjectARView!
    
    @IBOutlet weak var plusButton: UIButton!
    @IBOutlet weak var minusButton: UIButton!
    @IBOutlet weak var switchDrawVisualEffect: UIVisualEffectView!
    
    @IBOutlet weak var drawingSwitch: UISwitch!
    
    
    let configuration = ARWorldTrackingConfiguration()
    
    /// Node selected by user
    var selectedNode: SCNNode?
    
    /// Nodes placed by the user
    var placedNodes = [SCNNode]() {
        didSet{
            showMinusButton()
        }
    }
    
    /// Visualisation planes placed when detecting planes
    var planeNodes = [SCNNode]() {
        didSet {
            showMinusButton()
        }
    }
    
    //Drawing
    /// One line in drawind mode
    var drawingLine = [SCNNode]()
    
    /// All drawing lines
    var drawing: [[SCNNode]] = []
    
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
    
    var screenCenter: CGPoint?

    
    enum ObjectPlacementMode {
        case freeform, plane, image, draw
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reloadConfiguration(removeAnchors: false)
        sceneView.debugOptions = [.showFeaturePoints]
        sceneView.scene.rootNode.addChildNode(focusSquare)
        //Default freeform
        drawingSwitch.isOn = false
        showPlaneOverlay = false
        focusSquare.isHidden = true
        plusButton.isHidden = false
        showMinusButton()
        showPlusButton()
        switchDrawVisualEffect.isHidden = true
        
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
        
        drawingSwitch.addTarget(self, action: #selector(drawingToggle), for: .valueChanged)
    }
    
    @objc func drawingToggle() {
        print("Swithed")
        showPlusButton()
        showMinusButton()
        
        if objectMode == .plane && drawingSwitch.isOn {
            focusSquare.isHidden = true
        } else if objectMode == .plane && !drawingSwitch.isOn {
            focusSquare.isHidden = false
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let bounds = view.frame
        screenCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        reloadConfiguration(removeAnchors: false)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        screenCenter = CGPoint(x: size.width/2, y: size.height/2)
    }
    
    
    
    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
            drawingSwitch.isOn = false
            showPlaneOverlay = false
            focusSquare.isHidden = true
            plusButton.isHidden = false
            showMinusButton()
            showPlusButton()
            switchDrawVisualEffect.isHidden = true
            
        case 1:
            objectMode = .plane
            drawingSwitch.isOn = false
            showPlaneOverlay = true
            focusSquare.isHidden = false
            showMinusButton()
            showPlusButton()
            switchDrawVisualEffect.isHidden = false
        case 2:
            objectMode = .image
            drawingSwitch.isOn = false
            showPlaneOverlay = true
            focusSquare.isHidden = true
            showMinusButton()
            showPlusButton()
            switchDrawVisualEffect.isHidden = true
        case 3:
            objectMode = .draw
            drawingSwitch.isOn = true
            showPlaneOverlay = true
            focusSquare.isHidden = true
            showMinusButton()
            showPlusButton()
            switchDrawVisualEffect.isHidden = true
        default:
            break
        }
    }
    
    @IBAction func plusButtonPressed(_ sender: UIButton) {
        
        guard let node = selectedNode else { return }
        
        switch objectMode {
        case .freeform:
            addNodeInFront(node)
            break
        case .plane:
            guard let screenCenter = screenCenter else { return }
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
        showPlusButton()
        showMinusButton()
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
        showPlusButton()
    }
    
    func togglePlaneVisualization() {
        dismiss(animated: true, completion: nil)
        showPlaneOverlay.toggle()
    }
    
    func undoLastObject() {
        if objectMode == .draw || drawingSwitch.isOn {
            
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
        
        if objectMode == .freeform {
            addNodeInFront(node)
        }
        if objectMode == .plane && drawingSwitch.isOn {
            let point = touch.location(in: sceneView)
            lastObjectPlasedPoint = point
            addNode(node, to: point)
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
        //Drawing by shape in plane mode
        if objectMode == .plane && drawingSwitch.isOn {
            addNode(selectedNode, to: newTouchPoint)
        }

    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        if !drawingLine.isEmpty{
            drawing.append(drawingLine)
            drawingLine.removeAll()
            showMinusButton()
        }
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
        DispatchQueue.main.async {
            if self.objectMode == .draw && !isFloor || self.drawingSwitch.isOn && !isFloor  {
                self.drawingLine.append(cloneNode)
                parentNode.addChildNode(cloneNode)
            } else {
                parentNode.addChildNode(cloneNode)
                if isFloor {
                    self.planeNodes.append(cloneNode)
                } else {
                    self.placedNodes.append(cloneNode)
                }
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
            } else if anchor.alignment == .horizontal {
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
        node.simdTransform = matrix_multiply(currentFrame.camera.transform, translation)
        
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
    
    func createFloorImage(imageAnchor: ARImageAnchor) -> SCNNode {
        
        let node = SCNNode()
        let extent = imageAnchor.referenceImage.physicalSize
        let plane = SCNPlane(width: extent.width, height: extent.height)
        
        plane.materials.first?.diffuse.contents = UIColor.white
        node.geometry = plane
        node.eulerAngles.x = -Float.pi/2
        node.opacity = 0.25
        node.name = "PlaneImage"
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
        
        let imageFlor = createFloorImage(imageAnchor: anchor)
        imageFlor.isHidden = !showPlaneOverlay
        addNode(imageFlor, to: node, isFloor: true)
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
        configuration.detectionImages = images
        
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
    
    func showMinusButton() {
        DispatchQueue.main.async {
            if self.drawingSwitch.isOn {
                if self.drawing.isEmpty {
                    self.minusButton.isEnabled = false
                    self.minusButton.alpha = 0.5
                } else {
                    self.minusButton.isEnabled = true
                    self.minusButton.alpha = 1
                }
            } else {
                if self.placedNodes.isEmpty {
                    self.minusButton.isEnabled = false
                    self.minusButton.alpha = 0.5
                } else {
                    self.minusButton.isEnabled = true
                    self.minusButton.alpha = 1
                }
            }
        }
    }

    func showPlusButton() {
        if drawingSwitch.isOn || objectMode == .draw || objectMode == .image || selectedNode == nil  {
            plusButton.isEnabled = false
            plusButton.alpha = 0.5
        } else {
            plusButton.isEnabled = true
            plusButton.alpha = 1
        }
    }
}
