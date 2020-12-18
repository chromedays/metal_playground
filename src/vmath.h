#ifndef vmath_h
#define vmath_h

#define MATH_PI 3.141592f

static inline float degToRad(float deg) {
  float rad = deg * MATH_PI / 180.f;
  return rad;
}

static inline float radToDeg(float rad) {
  float deg = rad * 180.f / MATH_PI;
  return deg;
}

typedef float Float2 __attribute__((ext_vector_type(2)));
typedef float Float3 __attribute__((ext_vector_type(3)));
typedef float Float4 __attribute__((ext_vector_type(4)));

float float2Dot(const Float2 a, const Float2 b);

float float3Dot(const Float3 a, const Float3 b);
Float3 float3Cross(const Float3 a, const Float3 b);
float float3LengthSq(const Float3 v);
float float3Length(const Float3 v);
Float3 float3Normalize(const Float3 v);

float float4Dot(const Float4 a, const Float4 b);

typedef struct _Mat4 {
  Float4 cols[4];
} Mat4;

Float4 mat4Row(const Mat4 mat, int n);
Mat4 mat4Multiply(const Mat4 a, const Mat4 b);
Mat4 mat4Identity();
Mat4 mat4Translate(Float3 position);
Mat4 mat4Scale(Float3 scale);
Mat4 mat4LookAt(const Float3 eye, const Float3 target, const Float3 upAxis);
Mat4 mat4Perspective(float fov, float aspectRatio, float nearZ, float farZ);

#endif /* vmath_h */
