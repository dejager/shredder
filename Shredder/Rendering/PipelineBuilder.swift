//
//  PipelineBuilder.swift
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

import Metal
import simd

enum PipelineBuilder {
  static func makePipeline(
    device: MTLDevice,
    library: MTLLibrary,
    pixelFormat: MTLPixelFormat
  ) throws -> MTLRenderPipelineState {
    let descriptor = MTLRenderPipelineDescriptor()
    descriptor.vertexFunction = library.makeFunction(name: "ripVertex")
    descriptor.fragmentFunction = library.makeFunction(name: "ripFragment")
    descriptor.vertexDescriptor = makeVertexDescriptor()
    descriptor.colorAttachments[0].pixelFormat = pixelFormat
    descriptor.colorAttachments[0].isBlendingEnabled = true
    descriptor.colorAttachments[0].rgbBlendOperation = .add
    descriptor.colorAttachments[0].alphaBlendOperation = .add
    descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
    descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
    descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
    descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
    return try device.makeRenderPipelineState(descriptor: descriptor)
  }

  private static func makeVertexDescriptor() -> MTLVertexDescriptor {
    let descriptor = MTLVertexDescriptor()
    descriptor.attributes[0].format = .float3
    descriptor.attributes[0].offset = 0
    descriptor.attributes[0].bufferIndex = 0
    descriptor.attributes[1].format = .float2
    descriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
    descriptor.attributes[1].bufferIndex = 0
    descriptor.layouts[0].stride = MemoryLayout<Vertex>.stride
    descriptor.layouts[0].stepFunction = .perVertex
    return descriptor
  }
}
