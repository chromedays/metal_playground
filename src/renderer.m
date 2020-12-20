#include "renderer.h"
#include "global.h"
#include "vmath.h"
#include "gui.h"
#include "memory.h"
#define CGLTF_IMPLEMENTATION
#include "external/cgltf.h"
#define STB_IMAGE_IMPLEMENTATION
#include "external/stb_image.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

typedef struct _Vertex {
  Float3 position;
  Float4 color;
  Float2 texcoord;
  Float3 normal;
} Vertex;

typedef uint32_t VertexIndex;
#define METAL_INDEX_TYPE MTLIndexTypeUInt32
#define METAL_CONSTANT_ALIGNMENT 256
#define NUM_BUFFERS_IN_FLIGHT 3

typedef struct _UniformsPerView {
  Mat4 viewMat;
  Mat4 projMat;
} UniformsPerView;

typedef struct _UniformsPerDraw {
  Mat4 modelMat;
  Mat4 normalMat;
} UniformsPerDraw;

typedef struct _SubMesh {
  int numVertices;
  Vertex *vertices;
  int numIndices;
  VertexIndex *indices;

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
  int numMeshes;
  Mesh *meshes;

  int numNodes;
  SceneNode *nodes;

  int numScenes;
  Scene *scenes;

  id<MTLBuffer> gpuVertexBuffer;
  id<MTLBuffer> gpuIndexBuffer;
} Model;

static void initSubMeshFromGLTFPrimitive(SubMesh *subMesh,
                                         const cgltf_primitive *prim) {
  subMesh->numIndices = prim->indices->count;
  subMesh->indices = MALLOC_ARRAY(VertexIndex, subMesh->numIndices);
  VertexIndex maxIndex = 0;
  for (cgltf_size i = 0; i < prim->indices->count; ++i) {
    subMesh->indices[i] = cgltf_accessor_read_index(prim->indices, i);
    if (maxIndex < subMesh->indices[i]) {
      maxIndex = subMesh->indices[i];
    }
  }

  subMesh->numVertices = maxIndex + 1;
  subMesh->vertices = MALLOC_ARRAY_ZEROES(Vertex, subMesh->numVertices);
  for (cgltf_size attribIndex = 0; attribIndex < prim->attributes_count;
       ++attribIndex) {
    cgltf_attribute *attrib = &prim->attributes[attribIndex];
    ASSERT(!attrib->data->is_sparse); // Sparse is not supported yet;
    switch (attrib->type) {
    case cgltf_attribute_type_position:
      for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
           ++vertexIndex) {
        cgltf_size numComponents = cgltf_num_components(attrib->data->type);
        cgltf_bool readResult = cgltf_accessor_read_float(
            attrib->data, vertexIndex,
            (float *)&subMesh->vertices[vertexIndex].position, numComponents);
        ASSERT(readResult);
      }
      break;
    case cgltf_attribute_type_texcoord:
      for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
           ++vertexIndex) {
        cgltf_size numComponents = cgltf_num_components(attrib->data->type);
        cgltf_bool readResult = cgltf_accessor_read_float(
            attrib->data, vertexIndex,
            (float *)&subMesh->vertices[vertexIndex].texcoord, numComponents);
        ASSERT(readResult);
      }
      break;
    case cgltf_attribute_type_color:
      for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
           ++vertexIndex) {
        cgltf_size numComponents = cgltf_num_components(attrib->data->type);
        cgltf_bool readResult = cgltf_accessor_read_float(
            attrib->data, vertexIndex,
            (float *)&subMesh->vertices[vertexIndex].color, numComponents);
        ASSERT(readResult);
      }
      break;
    case cgltf_attribute_type_normal:
      for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
           ++vertexIndex) {
        cgltf_size numComponents = cgltf_num_components(attrib->data->type);
        cgltf_bool readResult = cgltf_accessor_read_float(
            attrib->data, vertexIndex,
            (float *)&subMesh->vertices[vertexIndex].normal, numComponents);
        ASSERT(readResult);
      }
      break;
    default:
      break;
    }
  }
}

typedef struct _OrbitCamera {
  float distance;
  float theta;
  float phi;
} OrbitCamera;

Mat4 getOrbitCameraMatrix(const OrbitCamera *cam) {
  Float3 camPos = sphericalToCartesian(cam->distance, degToRad(cam->theta),
                                       degToRad(cam->phi));
  Mat4 lookAt = mat4LookAt(camPos, (Float3){0}, (Float3){0, 1, 0});
  return lookAt;
}

static struct {
  id<MTLDevice> device;
  id<MTLCommandQueue> queue;
  MTLPixelFormat viewPixelFormat;
  MTLPixelFormat viewDepthFormat;

  id<MTLLibrary> library;
  id<MTLRenderPipelineState> pipeline;
  id<MTLDepthStencilState> depthStencilState;

  Model model;

  OrbitCamera cam;

  UniformsPerView uniformsPerView;
} gRenderer;

static struct {
  Float2 mouseDelta;
  float wheelDelta;
} gInput;

void loadGLTFModel(Model *model, NSString *basePath) {
  LOG("Loading gltf (%s)", [basePath UTF8String]);

  cgltf_options options = {0};
  NSString *filePath =
      [basePath stringByAppendingPathComponent:
                    [[basePath lastPathComponent]
                        stringByAppendingPathExtension:@"gltf"]];
  cgltf_data *gltf;
  cgltf_result gltfLoadResult =
      cgltf_parse_file(&options, [filePath UTF8String], &gltf);
  ASSERT(gltfLoadResult == cgltf_result_success);
  cgltf_load_buffers(&options, gltf, [filePath UTF8String]);

  model->numMeshes = gltf->meshes_count;
  model->meshes = MALLOC_ARRAY_ZEROES(Mesh, model->numMeshes);

  int vertexBufferSize = 0;
  int indexBufferSize = 0;

  for (cgltf_size meshIndex = 0; meshIndex < gltf->meshes_count; ++meshIndex) {
    cgltf_mesh *gltfMesh = &gltf->meshes[meshIndex];
    Mesh *mesh = &model->meshes[meshIndex];

    mesh->numSubMeshes = gltfMesh->primitives_count;
    mesh->subMeshes = MALLOC_ARRAY_ZEROES(SubMesh, mesh->numSubMeshes);

    for (cgltf_size primIndex = 0; primIndex < gltfMesh->primitives_count;
         ++primIndex) {
      SubMesh *subMesh = &mesh->subMeshes[primIndex];
      initSubMeshFromGLTFPrimitive(subMesh, &gltfMesh->primitives[primIndex]);
      vertexBufferSize += subMesh->numVertices * sizeof(Vertex);
      indexBufferSize += subMesh->numIndices * sizeof(VertexIndex);
    }
  }

  model->gpuVertexBuffer = [gRenderer.device
      newBufferWithLength:vertexBufferSize
                  options:MTLResourceCPUCacheModeDefaultCache];
  model->gpuIndexBuffer = [gRenderer.device
      newBufferWithLength:indexBufferSize
                  options:MTLResourceCPUCacheModeDefaultCache];
  uint8_t *gpuVertexBufferMem = (uint8_t *)[model->gpuVertexBuffer contents];
  uint8_t *gpuIndexBufferMem = (uint8_t *)[model->gpuIndexBuffer contents];

  int vertexOffsetInBytes = 0;
  int indexOffsetInBytes = 0;

  for (int meshIndex = 0; meshIndex < model->numMeshes; ++meshIndex) {
    Mesh *mesh = &model->meshes[meshIndex];
    for (int subMeshIndex = 0; subMeshIndex < mesh->numSubMeshes;
         ++subMeshIndex) {
      SubMesh *subMesh = &mesh->subMeshes[subMeshIndex];
      memcpy(gpuVertexBufferMem + vertexOffsetInBytes, subMesh->vertices,
             subMesh->numVertices * sizeof(Vertex));
      memcpy(gpuIndexBufferMem + indexOffsetInBytes, subMesh->indices,
             subMesh->numIndices * sizeof(VertexIndex));
      subMesh->gpuVertexBufferOffsetInBytes = vertexOffsetInBytes;
      subMesh->gpuIndexBufferOffsetInBytes = indexOffsetInBytes;
      vertexOffsetInBytes += subMesh->numVertices * sizeof(Vertex);
      indexOffsetInBytes += subMesh->numIndices * sizeof(VertexIndex);
    }
  }

  model->numNodes = gltf->nodes_count;
  model->nodes = MALLOC_ARRAY_ZEROES(SceneNode, model->numNodes);
  for (cgltf_size nodeIndex = 0; nodeIndex < gltf->nodes_count; ++nodeIndex) {
    cgltf_node *gltfNode = &gltf->nodes[nodeIndex];
    SceneNode *node = &model->nodes[nodeIndex];

    cgltf_node_transform_local(gltfNode,
                               (float *)node->localTransform.matrix.cols);
    cgltf_node_transform_world(gltfNode,
                               (float *)node->worldTransform.matrix.cols);

    if (gltfNode->parent) {
      node->parent = gltfNode->parent - gltf->nodes;
    } else {
      node->parent = -1;
    }

    if (gltfNode->mesh) {
      node->mesh = gltfNode->mesh - gltf->meshes;
    } else {
      node->mesh = -1;
    }

    if (gltfNode->children_count > 0) {
      node->numChildNodes = gltfNode->children_count;
      node->childNodes = MALLOC_ARRAY(int, node->numChildNodes);
      for (cgltf_size childIndex = 0; childIndex < gltfNode->children_count;
           ++childIndex) {
        node->childNodes[childIndex] =
            gltfNode->children[childIndex] - gltf->nodes;
      }
    }
  }

  model->numScenes = gltf->scenes_count;
  model->scenes = MALLOC_ARRAY_ZEROES(Scene, model->numScenes);

  for (cgltf_size sceneIndex = 0; sceneIndex < gltf->scenes_count;
       ++sceneIndex) {
    cgltf_scene *gltfScene = &gltf->scenes[sceneIndex];
    Scene *scene = &model->scenes[sceneIndex];

    if (gltfScene->nodes_count > 0) {
      scene->numNodes = gltfScene->nodes_count;
      scene->nodes = MALLOC_ARRAY(int, scene->numNodes);

      for (cgltf_size nodeIndex = 0; nodeIndex < gltfScene->nodes_count;
           ++nodeIndex) {
        cgltf_node *gltfNode = gltfScene->nodes[nodeIndex];
        scene->nodes[nodeIndex] = gltfNode - gltf->nodes;
      }
    }
  }

  cgltf_free(gltf);
}

void destroyModel(Model *model) {
  for (int i = 0; i < model->numScenes; ++i) {
    FREE(model->scenes[i].nodes);
  }
  FREE(model->scenes);

  for (int i = 0; i < model->numNodes; ++i) {
    FREE(model->nodes[i].childNodes);
  }
  FREE(model->nodes);

  for (int i = 0; i < model->numMeshes; ++i) {
    for (int j = 0; j < model->meshes[i].numSubMeshes; ++j) {
      FREE(model->meshes[i].subMeshes[j].vertices);
      FREE(model->meshes[i].subMeshes[j].indices);
    }
    FREE(model->meshes[i].subMeshes);
  }

  FREE(model->meshes);
}

void renderMesh(const Model *model, const Mesh *mesh,
                id<MTLRenderCommandEncoder> renderEncoder) {
  for (int subMeshIndex = 0; subMeshIndex < mesh->numSubMeshes;
       ++subMeshIndex) {
    SubMesh *subMesh = &mesh->subMeshes[subMeshIndex];

    [renderEncoder setVertexBufferOffset:subMesh->gpuVertexBufferOffsetInBytes
                                 atIndex:0];

    [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                              indexCount:subMesh->numIndices
                               indexType:METAL_INDEX_TYPE
                             indexBuffer:model->gpuIndexBuffer
                       indexBufferOffset:subMesh->gpuIndexBufferOffsetInBytes];
  }
}

void renderSceneNode(const Model *model, const SceneNode *node,
                     id<MTLRenderCommandEncoder> renderEncoder) {
  UniformsPerDraw uniform;
  uniform.modelMat = node->worldTransform.matrix;
  uniform.normalMat = mat4Transpose(mat4Inverse(uniform.modelMat));

  [renderEncoder setVertexBytes:&uniform length:sizeof(uniform) atIndex:2];

  if (node->mesh >= 0) {
    Mesh *mesh = &model->meshes[node->mesh];
    renderMesh(model, mesh, renderEncoder);
  }

  if (node->numChildNodes > 0) {
    for (int i = 0; i < node->numChildNodes; ++i) {
      SceneNode *childNode = &model->nodes[node->childNodes[i]];
      renderSceneNode(model, childNode, renderEncoder);
    }
  }
}

void renderModel(const Model *model,
                 id<MTLRenderCommandEncoder> renderEncoder) {
  [renderEncoder setVertexBuffer:model->gpuVertexBuffer offset:0 atIndex:0];

  for (int sceneIndex = 0; sceneIndex < model->numScenes; ++sceneIndex) {
    Scene *scene = &model->scenes[sceneIndex];
    for (int nodeIndex = 0; nodeIndex < scene->numNodes; ++nodeIndex) {
      SceneNode *node = &model->nodes[scene->nodes[nodeIndex]];
      renderSceneNode(model, node, renderEncoder);
    }
  }
}

void initRenderer(MTKView *view) {
  gRenderer.device = MTLCreateSystemDefaultDevice();
  view.device = gRenderer.device;
  gRenderer.queue = [gRenderer.device newCommandQueue];
  gRenderer.viewPixelFormat = view.colorPixelFormat;
  gRenderer.viewDepthFormat = view.depthStencilPixelFormat;

  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *shaderPath = [mainBundle pathForResource:@"shaders"
                                              ofType:@"metallib"];
  gRenderer.library = [gRenderer.device newLibraryWithFile:shaderPath
                                                     error:nil];
  //   gRenderer.library = [gRenderer.device newDefaultLibrary];
  MTLRenderPipelineDescriptor *pipelineDesc = [MTLRenderPipelineDescriptor new];
  pipelineDesc.vertexFunction =
      [gRenderer.library newFunctionWithName:@"vertex_main"];
  pipelineDesc.fragmentFunction =
      [gRenderer.library newFunctionWithName:@"fragment_main"];
  pipelineDesc.colorAttachments[0].pixelFormat = gRenderer.viewPixelFormat;
  pipelineDesc.depthAttachmentPixelFormat = gRenderer.viewDepthFormat;
  gRenderer.pipeline =
      [gRenderer.device newRenderPipelineStateWithDescriptor:pipelineDesc
                                                       error:nil];
  MTLDepthStencilDescriptor *depthStencilDesc = [MTLDepthStencilDescriptor new];
  depthStencilDesc.depthCompareFunction = MTLCompareFunctionGreaterEqual;
  depthStencilDesc.depthWriteEnabled = YES;
  gRenderer.depthStencilState =
      [gRenderer.device newDepthStencilStateWithDescriptor:depthStencilDesc];

  NSString *gltfBasePath = [mainBundle pathForResource:@"DamagedHelmet"
                                                ofType:nil];
  loadGLTFModel(&gRenderer.model, gltfBasePath);

  gRenderer.cam.distance = 5;
  gRenderer.cam.phi = -90;
  gRenderer.cam.theta = 0;

  initGUI(gRenderer.device);
}

void render(MTKView *view, float dt) {
  gRenderer.cam.phi -= gInput.mouseDelta.x * 2.f;
  gRenderer.cam.theta -= gInput.mouseDelta.y * 2.f;
  if (gRenderer.cam.theta > 89.9f) {
    gRenderer.cam.theta = 89.9f;
  } else if (gRenderer.cam.theta < -89.9f) {
    gRenderer.cam.theta = -89.9f;
  }
  gRenderer.cam.distance -= gInput.wheelDelta;
  if (gRenderer.cam.distance < 0.1f) {
    gRenderer.cam.distance = 0.1f;
  }

  guiBeginFrame(view);
  doGUI();

  gRenderer.uniformsPerView.viewMat = getOrbitCameraMatrix(&gRenderer.cam);
  Mat4 projection =
      mat4Perspective(degToRad(60), gScreenWidth / gScreenHeight, 0.1f, 1000.f);
  gRenderer.uniformsPerView.projMat = projection;

  id<MTLCommandBuffer> commandBuffer = [gRenderer.queue commandBuffer];
  MTLRenderPassDescriptor *renderPassDescriptor =
      view.currentRenderPassDescriptor;
  renderPassDescriptor.colorAttachments[0].clearColor =
      MTLClearColorMake(0, 0, 0, 1);
  renderPassDescriptor.depthAttachment.clearDepth = 0;
  id<MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
  [renderEncoder setRenderPipelineState:gRenderer.pipeline];
  [renderEncoder setDepthStencilState:gRenderer.depthStencilState];

  [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
  [renderEncoder setCullMode:MTLCullModeBack];
  if (gGUI.wireframe) {
    [renderEncoder setTriangleFillMode:MTLTriangleFillModeLines];
  } else {
    [renderEncoder setTriangleFillMode:MTLTriangleFillModeFill];
  }

  [renderEncoder setVertexBytes:&gRenderer.uniformsPerView
                         length:sizeof(gRenderer.uniformsPerView)
                        atIndex:1];
  renderModel(&gRenderer.model, renderEncoder);

  [renderEncoder setTriangleFillMode:MTLTriangleFillModeFill];
  guiEndFrameAndRender(commandBuffer, renderEncoder);

  [renderEncoder endEncoding];
  [commandBuffer presentDrawable:view.currentDrawable];
  [commandBuffer commit];

  gInput.mouseDelta = (Float2){0};
  gInput.wheelDelta = 0;
}

void onResizeWindow() {
  // MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor
  //     texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
  //                                  width:gScreenWidth
  //                                 height:gScreenHeight
  //                              mipmapped:NO];
  // textureDesc.textureType = MTLTextureType2D;
  // textureDesc.usage |= MTLTextureUsageRenderTarget;
  // textureDesc.storageMode = MTLStorageModeMemoryless;
}

void onMouseDragged(float dx, float dy) {
  gInput.mouseDelta = (Float2){dx, dy};
}

void onMouseScrolled(float dy) { gInput.wheelDelta = dy; }