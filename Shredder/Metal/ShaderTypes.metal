#ifndef ShaderTypes_metal
#define ShaderTypes_metal

#include <metal_stdlib>
using namespace metal;

struct ShredderUniforms {
  float4x4 mvp;

  float tearAmount;
  float tearWidth;
  float tearOffset;
  float uvOffset;

  float ripSide;
  float xDirection;

  float tearXAngle;
  float tearYAngle;
  float tearZAngle;
  float tearXOffset;

  float3 shadeColor;
  float shadeAmount;

  float whiteThreshold;

  float sheetHalfWidth;
  float sheetFullWidth;
  float sheetHeight;
  float zOffset;
  float groupY;
  float groupRotZ;
  float throwProgress;
  float throwX;
  float throwY;
  float throwZ;
  float throwRotZ;

  float3 _padding;
};

#endif
