#pragma once
#include "util.h"
#include "vmath.h"
#include "str.h"
#include <stdint.h>
#ifdef RENDERER_DX11
#ifndef COBJMACROS
#define COBJMACROS
#endif
#include <d3d11_1.h>
#endif

void initRenderer(void);
void destroyRenderer(void);
void render(float dt);

#ifdef __APPLE__
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

void initRenderer(MTKView *view);
void destroyRenderer(void);
void render(MTKView *view, float dt);
void onResizeWindow(void);
void onMouseDragged(float dx, float dy);
void onMouseScrolled(float dy);

C_INTERFACE_END

#else

typedef struct _Vertex {
  Float3 position;
  Float4 color;
  Float2 texcoord;
  Float3 normal;
} Vertex;

typedef uint32_t VertexIndex;

typedef struct _LightUniform {
  Float3 position;
  float intensity;
} LightUniform;

typedef struct _UniformsPerView {
  Mat4 viewMat;
  Mat4 projMat;
} UniformsPerView;

typedef struct _UniformsPerMaterial {
  Float4 baseColorFactor;
} UniformsPerMaterial;

typedef struct _UniformsPerDraw {
  Mat4 modelMat;
  Mat4 normalMat;
} UniformsPerDraw;

typedef UniformsPerView ViewUniforms;
typedef UniformsPerMaterial MaterialUniforms;
typedef UniformsPerDraw DrawUniforms;

typedef struct _Material {
  int baseColorTexture;
  int baseColorSampler;
  Float4 baseColorFactor;
  int metallicRoughnessTexture;
  int metallicRoughnessSampler;
  float metallicFactor;
  float roughnessFactor;
  int normalTexture;
  int normalSampler;
  float normalScale;
  int occlusionTexture;
  int occlusionSampler;
  float occlusionStrength;
  int emissiveTexture;
  int emissiveSampler;
  Float3 emissiveFactor;
} Material;

typedef struct _SubMesh {
  int numVertices;
  Vertex *vertices;
  int numIndices;
  VertexIndex *indices;

  int material;

  int gpuVertexBufferOffsetInBytes;
  int gpuIndexBufferOffsetInBytes;
} SubMesh;

typedef struct _Mesh {
  int numSubMeshes;
  SubMesh *subMeshes;
} Mesh;

typedef struct _Transform {
  // Float3 position;
  // Float3 scale;
  // Float4 rotation;
  Mat4 matrix;
} Transform;

typedef struct _SceneNode {
  int parent;

  Transform localTransform;
  Transform worldTransform;

  int mesh;

  int *childNodes;
  int numChildNodes;
} SceneNode;

typedef struct _Scene {
  int numNodes;
  int *nodes;
} Scene;

typedef struct _Model {
  int numTextures;
#ifdef RENDERER_GL33
  uint32_t *textures;
#elif defined(RENDERER_METAL)
  id<MTLTexture> __strong *textures;
#elif defined(RENDERER_DX11)
  ID3D11Texture2D **textures;
#endif

  int numSamplers;
#ifdef RENDERER_GL33
  uint32_t *samplers;
#elif defined(RENDERER_METAL)
  id<MTLSamplerState> __strong *samplers;
#elif defined(RENDERER_DX11)
  ID3D11SamplerState **samplers;
#endif

  int numMaterials;
  Material *materials;

  int numMeshes;
  Mesh *meshes;

  int numNodes;
  SceneNode *nodes;

  int numScenes;
  Scene *scenes;

#ifdef RENDERER_GL33
  uint32_t gpuVertexBuffer;
  uint32_t gpuIndexBuffer;
#elif defined(RENDERER_METAL)
  id<MTLBuffer> gpuVertexBuffer;
  id<MTLBuffer> gpuIndexBuffer;
#elif defined(RENDERER_DX11)
  ID3D11Buffer *gpuVertexBuffer;
  ID3D11Buffer *gpuIndexBuffer;
#endif
} Model;

void loadGLTFModel(Model *model, const String *basePath);
void destroyModel(Model *model);
void renderModel(Model *model, Mat4 transform);

typedef struct _OrbitCamera {
  float distance;
  float theta;
  float phi;
  Float3 target;
} OrbitCamera;

Mat4 getOrbitCameraMatrix(const OrbitCamera *cam);

// Command stuffs
void setCamera(const OrbitCamera *cam);
void setDeferredGBufferPass(void);
void setDeferredLightingPass(void);

#endif
