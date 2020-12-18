#include "vmath.h"
#include <math.h>

float float2Dot(const Float2 a, const Float2 b) {
  float result = a.x * b.x + a.y * b.y;
  return result;
}

float float3Dot(const Float3 a, const Float3 b) {
  float result = a.x * b.x + a.y * b.y + a.z * b.z;
  return result;
}

Float3 float3Cross(const Float3 a, const Float3 b) {
  Float3 result = {
      a.y * b.z - a.z * b.y,
      a.z * b.x - a.x * b.z,
      a.x * b.y - a.y * b.x,
  };

  return result;
}

float float3LengthSq(const Float3 v) {
  float result = float3Dot(v, v);
  return result;
}

float float3Length(const Float3 v) {
  float result = sqrtf(float3LengthSq(v));
  return result;
}

Float3 float3Normalize(const Float3 v) {
  Float3 normalized = v / float3Length(v);
  return normalized;
}

float float4Dot(const Float4 a, const Float4 b) {
  float result = a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
  return result;
}

Float4 mat4Row(const Mat4 mat, int n) {
  Float4 row = {mat.cols[0][n], mat.cols[1][n], mat.cols[2][n], mat.cols[3][n]};
  return row;
}

Mat4 mat4Multiply(const Mat4 a, const Mat4 b) {
  Float4 rows[4] = {
      mat4Row(a, 0),
      mat4Row(a, 1),
      mat4Row(a, 2),
      mat4Row(a, 3),
  };

  Mat4 result = {0};
  for (int i = 0; i < 4; ++i) {
    for (int j = 0; j < 4; ++j) {
      result.cols[j][i] = float4Dot(rows[i], b.cols[j]);
    }
  }

  return result;
}

Mat4 mat4Identity() {
  Mat4 identity = {{
      {1, 0, 0, 0},
      {0, 1, 0, 0},
      {0, 0, 1, 0},
      {0, 0, 0, 1},
  }};

  return identity;
}

Mat4 mat4Translate(Float3 position) {
  Mat4 translation = {{
      {1, 0, 0, 0},
      {0, 1, 0, 0},
      {0, 0, 1, 0},
      {position.x, position.y, position.z, 1},
  }};

  return translation;
}

Mat4 mat4Scale(Float3 scale) {
  Mat4 scaleMat = {{
      {scale.x, 0, 0, 0},
      {0, scale.y, 0, 0},
      {0, 0, scale.z, 0},
      {0, 0, 0, 1},
  }};

  return scaleMat;
}

Mat4 mat4LookAt(const Float3 eye, const Float3 target, const Float3 upAxis) {
  Float3 forward = eye - target;
  forward = float3Normalize(forward);
  Float3 right = float3Cross(upAxis, forward);
  right = float3Normalize(right);
  Float3 up = float3Cross(forward, right);
  up = float3Normalize(up);

  Mat4 lookat = {{
      {right.x, up.x, forward.x, 0},
      {right.y, up.y, forward.y, 0},
      {right.z, up.z, forward.z, 0},
      {-float3Dot(eye, right), -float3Dot(eye, up), -float3Dot(eye, forward),
       1},
  }};

  return lookat;
}

Mat4 mat4Perspective(float fov, float aspectRatio, float nearZ, float farZ) {
  float yScale = 1.f / tanf(fov * 0.5f);
  float xScale = yScale / aspectRatio;
  float zRange = farZ - nearZ;
  float zScale = nearZ / zRange;
  float wzScale = farZ * nearZ / zRange;

  Mat4 persp = {{
      {xScale, 0, 0, 0},
      {0, yScale, 0, 0},
      {0, 0, zScale, -1},
      {0, 0, wzScale, 0},
  }};

  return persp;
}