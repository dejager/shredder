//
//  Shaders.metal
//  Shredder
//
//  Created by Nate de Jager on 2025-12-23.
//

#include <metal_stdlib>
using namespace metal;
#include "ShaderTypes.metal"

struct Vertex {
  float3 position [[attribute(0)]];
  float2 uv       [[attribute(1)]];
};

struct Varyings {
  float4 position [[position]];
  float2 uv;
  float  amount;
};

static inline float3x3 rotationX(float a) {
  float c = cos(a), s = sin(a);
  return float3x3( 1, 0, 0,
                  0, c,-s,
                  0, s, c );
}
static inline float3x3 rotationY(float a) {
  float c = cos(a), s = sin(a);
  return float3x3( c, 0, s,
                  0, 1, 0,
                  -s, 0, c );
}
static inline float3x3 rotationZ(float a) {
  float c = cos(a), s = sin(a);
  return float3x3( c,-s, 0,
                  s, c, 0,
                  0, 0, 1 );
}

vertex Varyings ripVertex(Vertex in                         [[stage_in]],
                          constant ShredderUniforms& p      [[buffer(1)]])
{
  Varyings out;

  float yAmount = max(0.0, (p.tearAmount - (1.0 - in.uv.y)));

  float zRotate = p.tearZAngle * yAmount;
  float xRotate = p.tearXAngle * yAmount;
  float yRotate = p.tearYAngle * yAmount;
  float3 rotation = float3(xRotate * yAmount, yRotate * yAmount, zRotate * yAmount);

  float3 pos = in.position;

  float halfHeight = 0.5 * p.sheetHeight;
  float halfWidth  = 0.5 * (p.sheetHalfWidth - p.tearWidth * 0.5);

  float3 v = float3(
                    pos.x + (halfWidth * p.xDirection) - halfWidth,
                    pos.y + halfHeight,
                    pos.z
                    );

  v = v * rotationY(rotation.y) * rotationX(rotation.x) * rotationZ(rotation.z);

  v.x += (p.tearXOffset * yAmount) + halfWidth;
  v.y -= halfHeight;
  v.z += p.zOffset;

  if (p.groupRotZ != 0.0) {
    v = v * rotationZ(p.groupRotZ);
  }
  v.y += p.groupY;

  float throwT = clamp(p.throwProgress, 0.0, 1.0);
  if (throwT > 0.0) {
    float throwRot = p.throwRotZ * throwT;
    v = v * rotationZ(throwRot);
    v.x += p.throwX * throwT;
    v.y += p.throwY * throwT;
    v.z += p.throwZ * throwT;
  }

  out.position = p.mvp * float4(v, 1.0);
  out.uv = in.uv;
  out.amount = yAmount;
  return out;
}

fragment half4 ripFragment(Varyings in [[stage_in]],
                           texture2d<half> photoTex  [[texture(0)]],
                           texture2d<half> ripTex    [[texture(1)]],
                           constant ShredderUniforms& p     [[buffer(0)]])
{
  constexpr sampler s(address::clamp_to_edge, filter::linear);

  bool rightSide = (p.ripSide > 0.5);

  float widthOverlap = (p.tearWidth * 0.5) + p.sheetHalfWidth;
  float xScale = widthOverlap / p.sheetFullWidth;

  float2 uvOffset = float2(in.uv.x * xScale + p.uvOffset, in.uv.y);

  half4 texColor = photoTex.sample(s, uvOffset);
  float borderMarginY = 0.045;
  float borderMarginX = borderMarginY * (p.sheetHeight / p.sheetFullWidth);
  if (uvOffset.x < borderMarginX || uvOffset.x > (1.0 - borderMarginX) ||
      uvOffset.y < borderMarginY || uvOffset.y > (1.0 - borderMarginY)) {
    texColor = half4(half3(0.95h), 1.0h);
  }

  float ripRange = p.tearWidth / widthOverlap;
  float ripStart = rightSide ? 0.0 : (1.0 - ripRange);

  float alpha = 1.0;

  float ripX = (in.uv.x - ripStart) / ripRange;
  float ripY = in.uv.y * 0.5 + (0.5 * p.tearOffset);

  half4 ripCut   = ripTex.sample(s, float2(ripX, ripY));
  half4 ripColor = ripTex.sample(s, float2(ripX * 0.9, ripY - 0.02));

  float whiteness = float((ripCut.r + ripCut.g + ripCut.b + ripCut.a) * 0.25h);

  if (!rightSide && whiteness <= p.whiteThreshold) {
    float w2 = float((ripColor.r + ripColor.g + ripColor.b + ripColor.a) * 0.25h);
    if (w2 >= p.whiteThreshold) {
      texColor = ripColor;
    } else {
      alpha = 0.0;
    }
  }

  if (rightSide && whiteness >= p.whiteThreshold) {
    alpha = 0.0;
  }

  half3 shaded = mix(texColor.rgb, half3(p.shadeColor), half(in.amount * p.shadeAmount));
  return half4(shaded, half(alpha));
}
