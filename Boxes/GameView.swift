//
//  GameView.swift
//  Boxes
//
//  Created by Jack Finnis on 14/12/2022.
//

import SwiftUI
import SpriteKit
import CoreMotion

struct RootView: View {
    @State var showShakeAlert = false
    @State var refresh = false
    
    let game = Game()
    
    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: game, options: [.allowsTransparency])
                .onAppear {
                    game.size = geo.size
                }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didShakeDevice)) { _ in
            showShakeAlert = true
        }
        .alert("Reset Canvas?", isPresented: $showShakeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset") {
                game.removeAllChildren()
                game.addBox()
                Haptics.tap()
            }
        }
    }
}

class Game: SKScene {
    let motion = CMMotionManager()
    
    var boxMoving: SKNode?
    var touchPoint: CGPoint?
    
    override func didMove(to view: SKView) {
        physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        backgroundColor = .clear
        motion.deviceMotionUpdateInterval = 1/60
        motion.startAccelerometerUpdates()
        addBox()
    }
    
    func addBox(at location: CGPoint? = nil) {
        let location = location ?? CGPointMake(frame.width / 2, frame.height / 2)
        let box = SKSpriteNode(color: .red, size: CGSize(width: 50, height: 50))
        box.physicsBody = SKPhysicsBody(rectangleOf: box.size)
        box.position = location
        addChild(box)
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
            addBox(at: location)
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
            physicsWorld.gravity = CGVector(dx: data.acceleration.x * 50, dy: data.acceleration.y * 50)
        }
    }
}

extension CGVector {
    public init(magnitude: Double, angle: Double) {
        self.init(dx: magnitude * cos(angle), dy: magnitude * sin(angle))
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
