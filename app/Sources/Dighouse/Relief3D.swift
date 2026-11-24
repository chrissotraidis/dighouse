import SceneKit
import SwiftUI

/// A find's ground in 3D: the 120 m square find_views saves as a grid of heights, lit from one side, with a person
/// 1.70 m tall standing at the find for scale. Drag to turn it, scroll to come closer.
struct Relief3D: View {
    let title: String
    let path: String
    @Environment(\.dismiss) private var dismiss
    @State private var exaggerate: Float = 2
    @State private var light: Double = 315

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.system(size: 16 * Theme.scale, weight: .semibold)).lineLimit(1)
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(SecondaryButton()).keyboardShortcut(.cancelAction)
            }
            if let surface = Surface.load(path) {
                SceneView(scene: Self.scene(surface, exaggerate: exaggerate, light: light), options: [.allowsCameraControl])
                    .id("\(exaggerate)-\(light)")
                    .frame(minWidth: 640, minHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityLabel("The ground around the find in 3D, \(Int(surface.width)) m across, height ×\(Int(exaggerate))")
                HStack(spacing: 14) {
                    Picker("Height", selection: $exaggerate) {
                        Text("×1").tag(Float(1)); Text("×2").tag(Float(2)); Text("×4").tag(Float(4))
                    }
                    .pickerStyle(.segmented).frame(width: 200)
                    Text("Light from").font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.dim)
                    Slider(value: $light, in: 0...359, step: 15).frame(width: 180)
                        .accessibilityLabel("The direction the light comes from")
                    Spacer()
                }
                Text("\(Int(surface.width)) m across. The white post is a person 1.70 m tall, at the find; heights are drawn ×\(Int(exaggerate)). Drag to turn, scroll to come closer.")
                    .font(.system(size: 12 * Theme.scale)).foregroundStyle(Theme.dim)
            } else {
                Text("The 3D ground is drawn with the close views. Open the find again in a moment.")
                    .font(.system(size: 12.5 * Theme.scale)).foregroundStyle(Theme.faint).frame(minWidth: 640, minHeight: 200)
            }
        }
        .padding(20).background(Theme.bg).foregroundStyle(Theme.text)
    }

    struct Surface {
        let width: Float, depth: Float, nx: Int, ny: Int, find: (Float, Float), z: [Float]

        static func load(_ path: String) -> Surface? {
            guard let data = FileManager.default.contents(atPath: path),
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                  let cells = json["cells"] as? [Int], cells.count == 2, let z = json["z"] as? [Double], z.count == cells[0] * cells[1]
            else { return nil }
            let find = (json["find"] as? [Double]) ?? [0.5, 0.5]
            return Surface(width: Float(json["width_m"] as? Double ?? 120), depth: Float(json["height_m"] as? Double ?? 120),
                           nx: cells[0], ny: cells[1], find: (Float(find[0]), Float(find[1])), z: z.map(Float.init))
        }

        func height(_ i: Int, _ j: Int) -> Float { z[min(max(j, 0), ny - 1) * nx + min(max(i, 0), nx - 1)] }
    }

    static func scene(_ s: Surface, exaggerate: Float, light: Double) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = NSColor(Theme.bg)
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = [], indices: [Int32] = []
        let dx = s.width / Float(s.nx - 1), dz = s.depth / Float(s.ny - 1)
        for j in 0..<s.ny {
            for i in 0..<s.nx {
                vertices.append(SCNVector3(Float(i) * dx - s.width / 2, s.height(i, j) * exaggerate, Float(j) * dz - s.depth / 2))
                let gx = (s.height(i + 1, j) - s.height(i - 1, j)) * exaggerate / (2 * dx)
                let gz = (s.height(i, j + 1) - s.height(i, j - 1)) * exaggerate / (2 * dz)
                let n = simd_normalize(SIMD3<Float>(-gx, 1, -gz))
                normals.append(SCNVector3(n.x, n.y, n.z))
            }
        }
        for j in 0..<(s.ny - 1) {
            for i in 0..<(s.nx - 1) {
                let a = Int32(j * s.nx + i), b = a + 1, c = a + Int32(s.nx), d = c + 1
                indices += [a, c, b, b, c, d]
            }
        }
        let geometry = SCNGeometry(sources: [SCNGeometrySource(vertices: vertices), SCNGeometrySource(normals: normals)],
                                   elements: [SCNGeometryElement(indices: indices, primitiveType: .triangles)])
        let material = SCNMaterial()
        material.diffuse.contents = NSColor(white: 0.62, alpha: 1)
        material.lightingModel = .lambert
        material.isDoubleSided = true
        geometry.materials = [material]
        scene.rootNode.addChildNode(SCNNode(geometry: geometry))

        // A person at the find, as tall as the heights are drawn.
        let fi = Int(s.find.0 * Float(s.nx - 1)), fj = Int(s.find.1 * Float(s.ny - 1))
        let post = SCNCylinder(radius: 0.3, height: CGFloat(1.7 * exaggerate))
        post.firstMaterial?.diffuse.contents = NSColor.white
        post.firstMaterial?.lightingModel = .constant
        let person = SCNNode(geometry: post)
        person.position = SCNVector3(Float(fi) * dx - s.width / 2 + 6, s.height(fi + Int(6 / dx), fj) * exaggerate + 0.85 * exaggerate, Float(fj) * dz - s.depth / 2)
        scene.rootNode.addChildNode(person)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1100
        let azimuth = Float(light * .pi / 180)
        // A low light, as in a hillshade: shapes a few tens of centimetres high cast a shadow.
        sun.eulerAngles = SCNVector3(-Float.pi / 7, -azimuth, 0)
        scene.rootNode.addChildNode(sun)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 120
        scene.rootNode.addChildNode(ambient)

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zFar = 2000
        camera.position = SCNVector3(0, s.width * 0.42, s.depth * 0.62)
        camera.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(camera)
        return scene
    }
}
