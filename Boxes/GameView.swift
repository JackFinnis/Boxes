//
//  GameView.swift
//  Boxes
//
//  Created by Jack Finnis on 14/12/2022.
//

import SwiftUI
import SpriteKit
import CoreMotion

struct GameView: View {
    @StateObject var game = Game()
    @State var showShakeAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                SpriteView(scene: game, options: [.allowsTransparency])
                    .onAppear {
                        game.size = geo.size
                    }
            }
            HStack(spacing: 20) {
                Button {
                    game.addShape()
                } label: {
                    Image(systemName: "plus")
                }
                Spacer()
                
                Menu {
                    Picker("", selection: $game.shapeColour) {
                        ForEach(ShapeColour.allCases, id: \.self) { colour in
                            Label {
                                Text(colour.rawValue.capitalized)
                            } icon: {
                                colour.icon
                            }
                        }
                    }
                } label: {
                    Image(systemName: "circle.fill")
                        .foregroundColor(game.shapeColour.colour)
                }
                Menu {
                    Picker("", selection: $game.shapeType) {
                        ForEach(ShapeType.allCases, id: \.self) { shape in
                            Label(shape.rawValue.capitalized, systemImage: shape == .random ? "questionmark" : shape.systemName)
                        }
                    }
                } label: {
                    Image(systemName: game.shapeType.systemName)
                        .animation(.none)
                }
                Menu {
                    Picker("", selection: $game.shapeSize) {
                        ForEach(ShapeSize.allCases, id: \.self) { size in
                            Label(size.rawValue.capitalized, systemImage: size == .random ? "questionmark" : size.systemName)
                        }
                    }
                } label: {
                    Image(systemName: game.shapeSize.systemName)
                        .animation(.none)
                }
                
                Spacer()
                Menu {
                    Picker("", selection: $game.gravity) {
                        ForEach(Gravity.allCases, id: \.self) { planet in
                            Label(planet.name, systemImage: planet.systemName)
                        }
                    }
                } label: {
                    Image(systemName: game.gravity.systemName)
                        .animation(.none)
                }
                Button {
                    game.reset()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
            }
            .font(.title)
            .frame(height: 50)
            .padding(.horizontal)
        }
        .onReceive(NotificationCenter.default.publisher(for: .didShakeDevice)) { _ in
            showShakeAlert = true
            Haptics.error()
        }
        .alert("Reset Canvas?", isPresented: $showShakeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", action: game.reset)
        }
    }
}

enum ShapeColour: String, CaseIterable {
    case red, green, yellow, blue
    case random
    
    var icon: Image {
        if self == .random {
            return Image(systemName: "questionmark")
        } else {
            return Image(uiImage: UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(hierarchicalColor: UIColor(colour)))!)
        }
    }
    
    var colour: Color {
        switch self {
        case .red:
            return Color.red
        case .green:
            return Color.green
        case .yellow:
            return Color.yellow
        case .blue:
            return Color.blue
        case .random:
            return [ShapeColour.red, .green, .yellow, .blue].randomElement()!.colour
        }
    }
}

enum ShapeType: String, CaseIterable {
    case square, circle, triangle
    case random
    
    var systemName: String {
        if self == .random {
            return [ShapeType.square, .circle, .triangle].randomElement()!.systemName
        } else {
            return rawValue
        }
    }
    
    func node(size: Double) -> SKShapeNode {
        let node: SKShapeNode
        switch self {
        case .square:
            node = SKShapeNode(rectOf: CGSizeMake(size, size))
            node.physicsBody = SKPhysicsBody(rectangleOf: node.frame.size)
        case .circle:
            node = SKShapeNode(circleOfRadius: size/2)
            node.physicsBody = SKPhysicsBody(circleOfRadius: size/2)
        case .triangle:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: size/2, y: size * sqrt(3) / 2))
            path.addLine(to: CGPoint(x: size, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 0))
            node = SKShapeNode(path: path.cgPath)
            node.physicsBody = SKPhysicsBody(polygonFrom: path.cgPath)
        case .random:
            node = [ShapeType.square, .circle, .triangle].randomElement()!.node(size: size)
        }
        return node
    }
}

enum ShapeSize: String, CaseIterable {
    case small
    case medium
    case large
    case random
    
    var systemName: String {
        switch self {
        case .small:
            return "circle.grid.3x3"
        case .medium:
            return "circle.grid.2x2"
        case .large:
            return "circle.grid.2x1"
        case .random:
            return [ShapeSize.small, .medium, .large].randomElement()!.systemName
        }
    }
    
    var size: Double {
        switch self {
        case .small:
            return 25
        case .medium:
            return 50
        case .large:
            return 75
        case .random:
            return [ShapeSize.small, .medium, .large].randomElement()!.size
        }
    }
}

enum Gravity: Double, CaseIterable {
    case sun = 100
    case earth = 50
    case moon = 10
    
    var systemName: String {
        switch self {
        case .earth:
            return "globe.europe.africa"
        case .sun:
            return "sun.max"
        case .moon:
            return "moon"
        }
    }
    
    var name: String {
        switch self {
        case .earth:
            return "Earth"
        case .sun:
            return "Sun"
        case .moon:
            return "Moon"
        }
    }
}

class Game: SKScene, ObservableObject {
    @Published var shapeColour = ShapeColour.red
    @Published var shapeType = ShapeType.square
    @Published var shapeSize = ShapeSize.medium
    
    @Published var gravity = Gravity.earth
    
    let motion = CMMotionManager()
    
    var boxMoving: SKNode?
    var touchPoint: CGPoint?
    
    func reset() {
        removeAllChildren()
        addShape()
        Haptics.tap()
    }
    
    override func didMove(to view: SKView) {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        backgroundColor = .clear
        motion.deviceMotionUpdateInterval = 1/60
        motion.startAccelerometerUpdates()
        addShape()
    }
    
    func addShape(at location: CGPoint? = nil) {
        let location = location ?? CGPointMake(frame.width / 2, frame.height / 2)
        let shape = shapeType.node(size: shapeSize.size)
        shape.fillColor = UIColor(shapeColour.colour)
        shape.position = location
        addChild(shape)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if let box = children.first(where: { $0.contains(location) }) {
            if touch.tapCount == 1 || children.count == 1 {
                boxMoving = box
                touchPoint = location
            } else {
                box.removeFromParent()
            }
        } else {
            addShape(at: location)
            objectWillChange.send()
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        touchPoint = location
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        boxMoving = nil
        touchPoint = nil
    }
    
    override func update(_ currentTime: CFTimeInterval) {
        if let boxMoving, let touchPoint {
            let dt = 1.0/50.0
            let distance = CGVector(dx: touchPoint.x - boxMoving.position.x, dy: touchPoint.y - boxMoving.position.y)
            let velocity = CGVector(dx: distance.dx/dt, dy: distance.dy/dt)
            boxMoving.physicsBody!.velocity = velocity
        }
        
        if let data = motion.accelerometerData {
            physicsWorld.gravity = CGVector(dx: data.acceleration.x * gravity.rawValue, dy: data.acceleration.y * gravity.rawValue)
        }
    }
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .didShakeDevice, object: nil)
        }
    }
}

extension NSNotification.Name {
    static let didShakeDevice = NSNotification.Name("didShakeDevice")
}

struct Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
