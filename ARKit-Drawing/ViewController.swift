import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    let configuration = ARWorldTrackingConfiguration()
    
    /// Node selected by user
    var selectedNode: SCNNode?
    
    /// Nodes placed by the user
    var placedNodes = [SCNNode]()
    /// Visualisation planes placed when detecting planes
    var planeNodes = [SCNNode]()
    
    
    enum ObjectPlacementMode {
        case freeform, plane, image
    }
    
    var objectMode: ObjectPlacementMode = .freeform
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadConfiguration()
        sceneView.debugOptions = [.showFeaturePoints]
        
        
        sceneView.delegate = self
        sceneView.autoenablesDefaultLighting = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    @IBAction func changeObjectMode(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            objectMode = .freeform
        case 1:
            objectMode = .plane
        case 2:
            objectMode = .image
        default:
            break
        }
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
    }
    
    func undoLastObject() {
            placedNodes.last?.removeFromParentNode()
            placedNodes.removeLast()
    }
    
    /// Discard all actions
    func resetScene() {
        sceneView.session.pause()
        
        planeNodes.forEach { (plane) in
            plane.removeFromParentNode()
        }
        placedNodes.forEach { (node) in
            node.removeFromParentNode()
        }
        planeNodes.removeAll()
        placedNodes.removeAll()
        
        loadConfiguration()
        dismiss(animated: true, completion: nil)
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
            let point = touch.location(in: sceneView)
            let results = sceneView.hitTest(point, types: .existingPlaneUsingExtent)
            guard let result = results.first else { return }
            
            node.simdTransform = result.worldTransform
            addNodeToSceneView(node)
            
            break
        case .image:
            break
        }
    }
}

// MARK: - Placement Methods
extension ViewController {
    
    /// Add node po parent node
    ///
    /// - Parameters:
    ///   - node: node which will be added
    ///   - parentNode: parent node to which the node to be added
    func addNode(_  node: SCNNode, to parentNode: SCNNode) {
        let cloneNode = node.clone()
        parentNode.addChildNode(cloneNode)
        placedNodes.append(cloneNode)
        
    }
    
    /// Places object defined by node at 20 cm befor the camera
    ///
    /// - Parameter node: SCNNode to place in scene
    func addNodeInFront(_ node: SCNNode) {
        
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        var translation = matrix_identity_float4x4
        translation.columns.3.z = -0.2
        node.simdTransform =  matrix_multiply(currentFrame.camera.transform, translation)
        addNodeToSceneView(node)
    }
    
    /// Clones and adds an object defined by node to scene root
    ///
    /// - Parameter node: SCNNode which will be added
    func addNodeToSceneView(_ node: SCNNode) {
        let rootNode = sceneView.scene.rootNode
        addNode(node, to: rootNode)
        
    }
    
    /// Plane node AR anchor has added to the scene
    ///
    /// - Parameters:
    ///   - node: node which was added
    ///   - anchor: AR plane  anchor which defines the plane found
    func nodeAdded(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let selectedNode = selectedNode else { return }
        addNode(selectedNode, to: node)
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
            if objectMode == .plane {
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
}

// MARK: - Plane Detection Methods
extension ViewController {
    
    /// Create color plane to detected plane
    ///
    /// - Parameter planeAnchor: Detected anchor
    /// - Returns: Color plane
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
    
}

// MARK: - Configuration Methods
extension ViewController {
    func loadConfiguration() {

        let images = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources" , bundle: nil)
        configuration.detectionImages = images
        configuration.planeDetection = .horizontal
        
        sceneView.session.run(configuration)
  
        }
}
