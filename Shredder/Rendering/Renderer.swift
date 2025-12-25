//
//  Renderer.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import MetalKit
import simd

final class Renderer: NSObject, MTKViewDelegate {
  private let context: MetalContext
  private let uniformBuffer: UniformRingBuffer
  private let config: RendererConfig

  private var state = RenderState(
    tearAmount: 0,
    throwProgress: 0,
    throwLeft: .zero,
    throwRight: .zero,
    groupY: 0,
    groupRotZ: 0,
    photoName: "",
    ripName: ""
  )

  private var photoTexture: MTLTexture?
  private var ripTexture: MTLTexture?
  private var loadedPhotoName = ""
  private var loadedRipName = ""
  private var tearOffset: Float = Float.random(in: 0...1)

  private var mvp: simd_float4x4 = matrix_identity_float4x4

  private var leftUniforms: ShredderUniforms
  private var rightUniforms: ShredderUniforms

  init(context: MetalContext) {
    self.context = context
    self.config = context.config
    self.uniformBuffer = UniformRingBuffer(
      device: context.device,
      elementSize: MemoryLayout<ShredderUniforms>.stride,
      itemsPerFrame: 2
    )

    let halfWidth = config.fullWidth / 2.0
    self.leftUniforms = ShredderUniforms(
      mvp: matrix_identity_float4x4,
      tearAmount: 0,
      tearWidth: config.tearWidth,
      tearOffset: 0,
      uvOffset: 0,
      ripSide: 0,
      xDirection: -1,
      tearXAngle: -0.01,
      tearYAngle: -0.1,
      tearZAngle: 0.05,
      tearXOffset: 0,
      shadeColor: SIMD3(1, 1, 1),
      shadeAmount: config.leftShadeBase,
      whiteThreshold: 0.5,
      sheetHalfWidth: halfWidth,
      sheetFullWidth: config.fullWidth,
      sheetHeight: config.sheetHeight,
      zOffset: 0.0,
      groupY: 0,
      groupRotZ: 0,
      throwProgress: 0,
      throwX: 0,
      throwY: 0,
      throwZ: 0,
      throwRotZ: 0
    )

    self.rightUniforms = ShredderUniforms(
      mvp: matrix_identity_float4x4,
      tearAmount: 0,
      tearWidth: config.tearWidth,
      tearOffset: 0,
      uvOffset: 0,
      ripSide: 1,
      xDirection: 1,
      tearXAngle: 0.2,
      tearYAngle: 0.1,
      tearZAngle: -0.1,
      tearXOffset: 0,
      shadeColor: SIMD3(0, 0, 0),
      shadeAmount: config.rightShadeBase,
      whiteThreshold: 0.5,
      sheetHalfWidth: halfWidth,
      sheetFullWidth: config.fullWidth,
      sheetHeight: config.sheetHeight,
      zOffset: 0.0001,
      groupY: 0,
      groupRotZ: 0,
      throwProgress: 0,
      throwX: 0,
      throwY: 0,
      throwZ: 0,
      throwRotZ: 0
    )

    super.init()
  }

  func update(state newState: RenderState) -> Bool {
    let previous = state
    state = newState

    if previous.tearAmount == 0, newState.tearAmount > 0 {
      tearOffset = Float.random(in: 0...1)
    }

    let textureChanged = updateTextures(for: newState)
    return previous != newState || textureChanged
  }

  func refreshTextures() -> Bool {
    updateTextures(for: state)
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
      let commandBuffer = context.commandQueue.makeCommandBuffer(),
      let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd)
    else { return }

    guard let photoTexture, let ripTexture else {
      commandBuffer.commit()
      return
    }

    encoder.setRenderPipelineState(context.pipelineState)
    encoder.setVertexBuffer(context.mesh.vertexBuffer, offset: 0, index: 0)
    encoder.setFragmentTexture(photoTexture, index: 0)
    encoder.setFragmentTexture(ripTexture, index: 1)

    let half = config.fullWidth / 2.0
    let rightUvOffset = ((config.fullWidth - config.tearWidth) / config.fullWidth) * 0.5
    let tearT = clamp(state.tearAmount / 1.5, min: 0, max: 1)
    let wobbleFade = max(0, 1 - state.throwProgress)
    let wobbleStrength = 0.035 * tearT * wobbleFade
    let wobbleSeed = tearOffset * 10.0
    let leftWobble = (sin(state.tearAmount * 4.2 + wobbleSeed) + sin(state.tearAmount * 7.4 + wobbleSeed * 1.7)) * 0.5
    let rightWobble = (sin(state.tearAmount * 4.0 + wobbleSeed * 1.3) + sin(state.tearAmount * 6.8 + wobbleSeed * 1.9)) * 0.5
    let shadeLift = tearT * 0.2
    let frontBoost = tearT * 0.1

    leftUniforms.mvp = mvp
    leftUniforms.tearAmount = state.tearAmount
    leftUniforms.tearOffset = tearOffset
    leftUniforms.uvOffset = 0
    leftUniforms.sheetHalfWidth = half
    leftUniforms.sheetFullWidth = config.fullWidth
    leftUniforms.sheetHeight = config.sheetHeight
    leftUniforms.zOffset = 0.0
    leftUniforms.groupY = state.groupY
    leftUniforms.groupRotZ = state.groupRotZ
    leftUniforms.tearXOffset = leftWobble * wobbleStrength
    leftUniforms.shadeAmount = min(1, config.leftShadeBase + shadeLift * 0.6)
    leftUniforms.throwProgress = state.throwProgress
    leftUniforms.throwX = state.throwLeft.x
    leftUniforms.throwY = state.throwLeft.y
    leftUniforms.throwZ = state.throwLeft.z
    leftUniforms.throwRotZ = state.throwLeft.rotZ

    rightUniforms.mvp = mvp
    rightUniforms.tearAmount = state.tearAmount
    rightUniforms.tearOffset = tearOffset
    rightUniforms.uvOffset = rightUvOffset
    rightUniforms.sheetHalfWidth = half
    rightUniforms.sheetFullWidth = config.fullWidth
    rightUniforms.sheetHeight = config.sheetHeight
    rightUniforms.zOffset = 0.0001
    rightUniforms.groupY = state.groupY
    rightUniforms.groupRotZ = state.groupRotZ
    rightUniforms.tearXOffset = rightWobble * wobbleStrength
    rightUniforms.shadeAmount = min(1, config.rightShadeBase + shadeLift * 0.7 + frontBoost * 0.5)
    rightUniforms.throwProgress = state.throwProgress
    rightUniforms.throwX = state.throwRight.x
    rightUniforms.throwY = state.throwRight.y
    rightUniforms.throwZ = state.throwRight.z
    rightUniforms.throwRotZ = state.throwRight.rotZ

    let baseOffset = uniformBuffer.nextFrameOffset()
    uniformBuffer.write(leftUniforms, at: baseOffset)
    uniformBuffer.write(rightUniforms, at: baseOffset + uniformBuffer.stride)

    encoder.setVertexBuffer(uniformBuffer.buffer, offset: baseOffset, index: 1)
    encoder.setFragmentBuffer(uniformBuffer.buffer, offset: baseOffset, index: 0)
    encoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: context.mesh.indexCount,
      indexType: .uint16,
      indexBuffer: context.mesh.indexBuffer,
      indexBufferOffset: 0
    )

    let rightOffset = baseOffset + uniformBuffer.stride
    encoder.setVertexBuffer(uniformBuffer.buffer, offset: rightOffset, index: 1)
    encoder.setFragmentBuffer(uniformBuffer.buffer, offset: rightOffset, index: 0)
    encoder.drawIndexedPrimitives(
      type: .triangle,
      indexCount: context.mesh.indexCount,
      indexType: .uint16,
      indexBuffer: context.mesh.indexBuffer,
      indexBufferOffset: 0
    )

    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

  private func updateTextures(for state: RenderState) -> Bool {
    var changed = false

    if loadedPhotoName != state.photoName || photoTexture == nil {
      photoTexture = context.textureCache.texture(named: state.photoName)
      loadedPhotoName = state.photoName
      changed = true
    }

    if loadedRipName != state.ripName || ripTexture == nil {
      ripTexture = context.textureCache.texture(named: state.ripName)
      loadedRipName = state.ripName
      changed = true
    }

    return changed
  }
}
