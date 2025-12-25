//
//  Mesh.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import simd
import Metal

struct Vertex {
  var position: SIMD3<Float>
  var uv: SIMD2<Float>
}

struct Mesh {
  var vertexBuffer: MTLBuffer
  var indexBuffer: MTLBuffer
  var indexCount: Int
}

enum MeshBuilder {
  static func makePlane(
    device: MTLDevice,
    width: Float,
    height: Float,
    xSegments: Int,
    ySegments: Int
  ) -> Mesh {
    let vx = xSegments + 1
    let vy = ySegments + 1

    var vertices: [Vertex] = []
    vertices.reserveCapacity(vx * vy)

    for y in 0..<vy {
      let v = Float(y) / Float(ySegments)
      let py = (v - 0.5) * height
      for x in 0..<vx {
        let u = Float(x) / Float(xSegments)
        let px = (u - 0.5) * width
        vertices.append(Vertex(position: .init(px, py, 0), uv: .init(u, v)))
      }
    }

    var indices: [UInt16] = []
    indices.reserveCapacity(xSegments * ySegments * 6)

    for y in 0..<ySegments {
      for x in 0..<xSegments {
        let i0 = UInt16(y * vx + x)
        let i1 = UInt16(y * vx + x + 1)
        let i2 = UInt16((y + 1) * vx + x)
        let i3 = UInt16((y + 1) * vx + x + 1)
        indices += [i0, i2, i1, i1, i2, i3]
      }
    }

    let vb = device.makeBuffer(bytes: vertices,
                               length: MemoryLayout<Vertex>.stride * vertices.count,
                               options: [])!
    let ib = device.makeBuffer(bytes: indices,
                               length: MemoryLayout<UInt16>.stride * indices.count,
                               options: [])!

    return Mesh(vertexBuffer: vb, indexBuffer: ib, indexCount: indices.count)
  }
}
