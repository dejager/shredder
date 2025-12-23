//
//  Renderer.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import Foundation
import MetalKit
import simd

final class Renderer: NSObject, MTKViewDelegate {
  private let device: MTLDevice
  private let commandQueue: MTLCommandQueue
  private let pipelineState: MTLRenderPipelineState

  private var mesh: Mesh

  private var textureLoader: MTKTextureLoader
  private var photoTex: MTLTexture?
  private var ripTex: MTLTexture?

  private var loadedPhotoName: String = ""
  private var loadedRipName: String = ""

  private var tearAmount: Float = 0
  private var tearOffset: Float = Float.random(in: 0...1)
  private var throwProgress: Float = 0
  private var throwLeft: ThrowSide = .zero
  private var throwRight: ThrowSide = .zero
  private var groupY: Float = 0
  private var groupRotZ: Float = 0

  private let fullWidth: Float = 3.0
  private let sheetHeight: Float = 2.0
  private let tearWidth: Float = 0.4
  private let xSegments = 30
  private let ySegments = 50
  private let leftShadeBase: Float = 0.2
  private let rightShadeBase: Float = 0.3

  private var mvp: simd_float4x4 = matrix_identity_float4x4

  struct Params {
    var mvp: simd_float4x4

    var tearAmount: Float
    var tearWidth: Float
    var tearOffset: Float
    var uvOffset: Float

    var ripSide: Float
    var xDirection: Float

    var tearXAngle: Float
    var tearYAngle: Float
    var tearZAngle: Float
    var tearXOffset: Float

    var shadeColor: SIMD3<Float>
    var shadeAmount: Float

    var whiteThreshold: Float

    var sheetHalfWidth: Float
    var sheetFullWidth: Float
    var sheetHeight: Float
    var zOffset: Float
    var groupY: Float
    var groupRotZ: Float
    var throwProgress: Float
    var throwX: Float
    var throwY: Float
    var throwZ: Float
    var throwRotZ: Float

    var _pad: SIMD3<Float> = .zero
  }

  private var leftParams = Params(
    mvp: matrix_identity_float4x4,
    tearAmount: 0, tearWidth: 0.4, tearOffset: 0, uvOffset: 0,
    ripSide: 0, xDirection: -1,
    tearXAngle: -0.01, tearYAngle: -0.1, tearZAngle: 0.05, tearXOffset: 0,
    shadeColor: SIMD3(1,1,1), shadeAmount: 0.2,
    whiteThreshold: 0.5,
    sheetHalfWidth: 1.5, sheetFullWidth: 3.0, sheetHeight: 2.0, zOffset: 0.0,
    groupY: 0, groupRotZ: 0,
    throwProgress: 0, throwX: 0, throwY: 0, throwZ: 0, throwRotZ: 0
  )

  private var rightParams = Params(
    mvp: matrix_identity_float4x4,
    tearAmount: 0, tearWidth: 0.4, tearOffset: 0, uvOffset: 0,
    ripSide: 1, xDirection: 1,
    tearXAngle: 0.2, tearYAngle: 0.1, tearZAngle: -0.1, tearXOffset: 0,
    shadeColor: SIMD3(0,0,0), shadeAmount: 0.4,
    whiteThreshold: 0.5,
    sheetHalfWidth: 1.5, sheetFullWidth: 3.0, sheetHeight: 2.0, zOffset: 0.0001,
    groupY: 0, groupRotZ: 0,
    throwProgress: 0, throwX: 0, throwY: 0, throwZ: 0, throwRotZ: 0
  )

  init?(mtkView: MTKView) {
    guard let device = mtkView.device else { return nil }
    self.device = device
    guard let cq = device.makeCommandQueue() else { return nil }
    self.commandQueue = cq
    self.textureLoader = MTKTextureLoader(device: device)

    let planeWidth = (fullWidth / 2.0) + (tearWidth / 2.0)
    self.mesh = MeshBuilder.makePlane(device: device, width: planeWidth, height: sheetHeight,
                                      xSegments: xSegments, ySegments: ySegments)

    let library = device.makeDefaultLibrary()!
    let vfn = library.makeFunction(name: "ripVertex")!
    let ffn = library.makeFunction(name: "ripFragment")!

    let desc = MTLRenderPipelineDescriptor()
    desc.vertexFunction = vfn
    desc.fragmentFunction = ffn
    let vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = .float3
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[1].format = .float2
    vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    vertexDescriptor.attributes[1].bufferIndex = 0
    vertexDescriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
    vertexDescriptor.layouts[0].stepFunction = .perVertex
    desc.vertexDescriptor = vertexDescriptor
    desc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
    desc.colorAttachments[0].isBlendingEnabled = true
    desc.colorAttachments[0].rgbBlendOperation = .add
    desc.colorAttachments[0].alphaBlendOperation = .add
    desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    desc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    desc.colorAttachments[0].sourceAlphaBlendFactor = .one
    desc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

    do {
      self.pipelineState = try device.makeRenderPipelineState(descriptor: desc)
    } catch {
      print("Pipeline error:", error)
      return nil
    }

    super.init()
  }

  private func loadTexture(named name: String, options: [MTKTextureLoader.Option: Any]) -> MTLTexture? {
    do {
      return try textureLoader.newTexture(name: name, scaleFactor: 1.0, bundle: .main, options: options)
    } catch {
      print("Texture load failed:", name, error)
      return nil
    }
  }

  func setTearAmount(_ amount: Float) -> Bool {
    if tearAmount == 0, amount > 0 {
      tearOffset = Float.random(in: 0...1)
    }
    let prev = tearAmount
    tearAmount = amount
    return abs(prev - amount) > 0.0005
  }

  func setTextures(photoName: String, ripName: String) -> Bool {
    var changed = false

    let opts: [MTKTextureLoader.Option: Any] = [
      .origin: MTKTextureLoader.Origin.bottomLeft,
      .SRGB: true
    ]

    if loadedPhotoName != photoName {
      photoTex = loadTexture(named: photoName, options: opts)
      loadedPhotoName = photoName
      if photoTex != nil { changed = true }
    }
    if loadedRipName != ripName {
      ripTex = loadTexture(named: ripName, options: opts)
      loadedRipName = ripName
      if ripTex != nil { changed = true }
    }
    return changed
  }

  func setThrow(progress: Float, left: ThrowSide, right: ThrowSide) -> Bool {
    let prevProgress = throwProgress
    let prevLeft = throwLeft
    let prevRight = throwRight

    throwProgress = progress
    throwLeft = left
    throwRight = right

    let progressChanged = abs(prevProgress - progress) > 0.0005
    return progressChanged || prevLeft != left || prevRight != right
  }

  func setGroup(y: Float, rotZ: Float) -> Bool {
    let prevY = groupY
    let prevRotZ = groupRotZ
    groupY = y
    groupRotZ = rotZ
    return abs(prevY - y) > 0.0005 || abs(prevRotZ - rotZ) > 0.0005
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    let w = Float(size.width)
    let h = Float(size.height)
    let aspect = max(0.001, w / max(0.001, h))

    let cameraZ: Float = (w < 800) ? 10.0 : 6.0

    let proj = makePerspectiveRH(fovyRadians: radians(30), aspect: aspect, nearZ: 0.1, farZ: 100)
    let viewM = makeTranslation(0, 0, -cameraZ)
    mvp = proj * viewM
  }

  func draw(in view: MTKView) {
    guard
      let rpd = view.currentRenderPassDescriptor,
      let drawable = view.currentDrawable,
      let cmd = commandQueue.makeCommandBuffer(),
      let enc = cmd.makeRenderCommandEncoder(descriptor: rpd)
    else { return }

    enc.setRenderPipelineState(pipelineState)
    enc.setVertexBuffer(mesh.vertexBuffer, offset: 0, index: 0)

    if let p = photoTex, let r = ripTex {
      enc.setFragmentTexture(p, index: 0)
      enc.setFragmentTexture(r, index: 1)
    }

    let half = fullWidth / 2.0
    let rightUvOffset = ((fullWidth - tearWidth) / fullWidth) * 0.5
    let tearT = min(1, max(0, tearAmount / 1.5))
    let wobbleFade = max(0, 1 - throwProgress)
    let wobbleStrength = 0.035 * tearT * wobbleFade
    let wobbleSeed = tearOffset * 10.0
    let leftWobble = (sin(tearAmount * 4.2 + wobbleSeed) + sin(tearAmount * 7.4 + wobbleSeed * 1.7)) * 0.5
    let rightWobble = (sin(tearAmount * 4.0 + wobbleSeed * 1.3) + sin(tearAmount * 6.8 + wobbleSeed * 1.9)) * 0.5
    let shadeLift = tearT * 0.2
    let frontBoost = tearT * 0.1

    leftParams.mvp = mvp
    leftParams.tearAmount = tearAmount
    leftParams.tearWidth = tearWidth
    leftParams.tearOffset = tearOffset
    leftParams.uvOffset = 0
    leftParams.sheetHalfWidth = half
    leftParams.sheetFullWidth = fullWidth
    leftParams.sheetHeight = sheetHeight
    leftParams.zOffset = 0.0
    leftParams.groupY = groupY
    leftParams.groupRotZ = groupRotZ
    leftParams.tearXOffset = leftWobble * wobbleStrength
    leftParams.shadeAmount = min(1, leftShadeBase + shadeLift * 0.6)
    leftParams.throwProgress = throwProgress
    leftParams.throwX = throwLeft.x
    leftParams.throwY = throwLeft.y
    leftParams.throwZ = throwLeft.z
    leftParams.throwRotZ = throwLeft.rotZ

    rightParams.mvp = mvp
    rightParams.tearAmount = tearAmount
    rightParams.tearWidth = tearWidth
    rightParams.tearOffset = tearOffset
    rightParams.uvOffset = rightUvOffset
    rightParams.sheetHalfWidth = half
    rightParams.sheetFullWidth = fullWidth
    rightParams.sheetHeight = sheetHeight
    rightParams.zOffset = 0.0001
    rightParams.groupY = groupY
    rightParams.groupRotZ = groupRotZ
    rightParams.tearXOffset = rightWobble * wobbleStrength
    rightParams.shadeAmount = min(1, rightShadeBase + shadeLift * 0.7 + frontBoost * 0.5)
    rightParams.throwProgress = throwProgress
    rightParams.throwX = throwRight.x
    rightParams.throwY = throwRight.y
    rightParams.throwZ = throwRight.z
    rightParams.throwRotZ = throwRight.rotZ

    var lp = leftParams
    enc.setVertexBytes(&lp, length: MemoryLayout<Params>.stride, index: 1)
    enc.setFragmentBytes(&lp, length: MemoryLayout<Params>.stride, index: 0)
    enc.drawIndexedPrimitives(type: .triangle,
                              indexCount: mesh.indexCount,
                              indexType: .uint16,
                              indexBuffer: mesh.indexBuffer,
                              indexBufferOffset: 0)

    var rp = rightParams
    enc.setVertexBytes(&rp, length: MemoryLayout<Params>.stride, index: 1)
    enc.setFragmentBytes(&rp, length: MemoryLayout<Params>.stride, index: 0)
    enc.drawIndexedPrimitives(type: .triangle,
                              indexCount: mesh.indexCount,
                              indexType: .uint16,
                              indexBuffer: mesh.indexBuffer,
                              indexBufferOffset: 0)

    enc.endEncoding()
    cmd.present(drawable)
    cmd.commit()
  }
}

// MARK: - Math helpers

private func radians(_ deg: Float) -> Float { deg * .pi / 180 }

private func makeTranslation(_ x: Float, _ y: Float, _ z: Float) -> simd_float4x4 {
  simd_float4x4(
    SIMD4(1,0,0,0),
    SIMD4(0,1,0,0),
    SIMD4(0,0,1,0),
    SIMD4(x,y,z,1)
  )
}

private func makePerspectiveRH(fovyRadians fovy: Float, aspect: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
  let y = 1 / tan(fovy * 0.5)
  let x = y / aspect
  let z = farZ / (nearZ - farZ)
  return simd_float4x4(
    SIMD4(x, 0, 0, 0),
    SIMD4(0, y, 0, 0),
    SIMD4(0, 0, z, -1),
    SIMD4(0, 0, z * nearZ, 0)
  )
}
