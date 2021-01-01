#include "renderer.h"
#include "app.h"
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

typedef struct _UniformsPerMaterial {
  Float4 baseColorFactor;
} UniformsPerMaterial;

typedef struct _UniformsPerDraw {
  Mat4 modelMat;
  Mat4 normalMat;
} UniformsPerDraw;

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
  id<MTLTexture> __strong *textures;

  int numSamplers;
  id<MTLSamplerState> __strong *samplers;

  int numMaterials;
  Material *materials;

  int numMeshes;
  Mesh *meshes;

  int numNodes;
  SceneNode *nodes;

  int numScenes;
  Scene *scenes;

  id<MTLBuffer> gpuVertexBuffer;
  id<MTLBuffer> gpuIndexBuffer;
} Model;

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

  id<MTLTexture> defaultBaseColorTexture;
  id<MTLSamplerState> defaultSampler;

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
  NSString *filePath;
  if ([[basePath pathExtension] isEqualToString:@"glb"]) {
    filePath = basePath;
  } else {
    filePath = [basePath stringByAppendingPathComponent:
                             [[basePath lastPathComponent]
                                 stringByAppendingPathExtension:@"gltf"]];
  }

  cgltf_data *gltf;
  cgltf_result gltfLoadResult =
      cgltf_parse_file(&options, [filePath UTF8String], &gltf);
  ASSERT(gltfLoadResult == cgltf_result_success);
  cgltf_load_buffers(&options, gltf, [filePath UTF8String]);

  model->numTextures = gltf->textures_count;
  model->textures = (id<MTLTexture> __strong *)MMALLOC_ARRAY_ZEROES(
      id<MTLTexture> __strong, model->numTextures);

  id<MTLCommandBuffer> commandBuffer = [gRenderer.queue commandBuffer];
  id<MTLBlitCommandEncoder> mipmapBlitEncoder =
      [commandBuffer blitCommandEncoder];

  for (cgltf_size textureIndex = 0; textureIndex < gltf->images_count;
       ++textureIndex) {
    cgltf_image *gltfImage = &gltf->images[textureIndex];
    int w, h, numComponents;
    stbi_uc *data;
    if (gltfImage->buffer_view) {
      data = stbi_load_from_memory(
          (uint8_t *)gltfImage->buffer_view->buffer->data +
              gltfImage->buffer_view->offset,
          gltfImage->buffer_view->size, &w, &h, &numComponents, STBI_rgb_alpha);
    } else {
      NSString *imageFilePath =
          [basePath stringByAppendingPathComponent:
                        [NSString stringWithCString:gltfImage->uri
                                           encoding:NSUTF8StringEncoding]];

      data = stbi_load([imageFilePath UTF8String], &w, &h, &numComponents,
                       STBI_rgb_alpha);
    }
    ASSERT(data);

    MTLTextureDescriptor *textureDesc = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                     width:w
                                    height:h
                                 mipmapped:YES];
    model->textures[textureIndex] =
        [gRenderer.device newTextureWithDescriptor:textureDesc];

    MTLRegion region = {
        .origin = {0, 0, 0},
        .size = {w, h, 1},
    };

    [model->textures[textureIndex] replaceRegion:region
                                     mipmapLevel:0
                                       withBytes:data
                                     bytesPerRow:4 * w];

    stbi_image_free(data);

    [mipmapBlitEncoder generateMipmapsForTexture:model->textures[textureIndex]];
  }
  [mipmapBlitEncoder endEncoding];
  [commandBuffer commit];

  model->numSamplers = gltf->samplers_count;
  model->samplers = (id<MTLSamplerState> __strong *)MMALLOC_ARRAY_ZEROES(
      id<MTLSamplerState> __strong, model->numSamplers);

  for (cgltf_size samplerIndex = 0; samplerIndex < gltf->samplers_count;
       ++samplerIndex) {
    cgltf_sampler *gltfSampler = &gltf->samplers[samplerIndex];
    MTLSamplerDescriptor *samplerDesc = [[MTLSamplerDescriptor alloc] init];
    switch (gltfSampler->mag_filter) {
    case 9728:
      samplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
      break;
    default:
      samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
      break;
    }

    switch (gltfSampler->min_filter) {
    case 9729:
    case 9985:
    case 9987:
      samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
      break;
    default:
      samplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    }

    switch (gltfSampler->min_filter) {
    case 9728:
    case 9729:
      samplerDesc.mipFilter = MTLSamplerMipFilterNotMipmapped;
      break;
    case 9984:
    case 9985:
      samplerDesc.mipFilter = MTLSamplerMipFilterNearest;
      break;
    default:
      samplerDesc.mipFilter = MTLSamplerMipFilterLinear;
    }

    switch (gltfSampler->wrap_s) {
    case 33071:
      samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
      break;
    case 33648:
      samplerDesc.sAddressMode = MTLSamplerAddressModeMirrorRepeat;
      break;
    default:
      samplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
      break;
    }

    switch (gltfSampler->wrap_t) {
    case 33071:
      samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
      break;
    case 33648:
      samplerDesc.tAddressMode = MTLSamplerAddressModeMirrorRepeat;
      break;
    default:
      samplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
      break;
    }

    samplerDesc.rAddressMode = MTLSamplerAddressModeRepeat;

    model->samplers[samplerIndex] =
        [gRenderer.device newSamplerStateWithDescriptor:samplerDesc];
  }

  model->numMaterials = gltf->materials_count;
  model->materials = MMALLOC_ARRAY_ZEROES(Material, model->numMaterials);
  for (cgltf_size materialIndex = 0; materialIndex < gltf->materials_count;
       ++materialIndex) {
    cgltf_material *gltfMaterial = &gltf->materials[materialIndex];
    Material *material = &model->materials[materialIndex];
    ASSERT(gltfMaterial->has_pbr_metallic_roughness);

    cgltf_pbr_metallic_roughness *pbrMR = &gltfMaterial->pbr_metallic_roughness;

    memcpy(&material->baseColorFactor, pbrMR->base_color_factor,
           sizeof(Float4));

    if (pbrMR->base_color_texture.texture) {
      material->baseColorTexture = gltfMaterial->pbr_metallic_roughness
                                       .base_color_texture.texture->image -
                                   gltf->images;

      if (pbrMR->base_color_texture.texture->sampler) {
        material->baseColorSampler = gltfMaterial->pbr_metallic_roughness
                                         .base_color_texture.texture->sampler -
                                     gltf->samplers;
      } else {
        material->baseColorSampler = -1;
      }
    } else {
      material->baseColorTexture = -1;
      material->baseColorSampler = -1;
    }
  }

  model->numMeshes = gltf->meshes_count;
  model->meshes = MMALLOC_ARRAY_ZEROES(Mesh, model->numMeshes);

  int vertexBufferSize = 0;
  int indexBufferSize = 0;

  for (cgltf_size meshIndex = 0; meshIndex < gltf->meshes_count; ++meshIndex) {
    cgltf_mesh *gltfMesh = &gltf->meshes[meshIndex];
    Mesh *mesh = &model->meshes[meshIndex];

    mesh->numSubMeshes = gltfMesh->primitives_count;
    mesh->subMeshes = MMALLOC_ARRAY_ZEROES(SubMesh, mesh->numSubMeshes);

    for (cgltf_size primIndex = 0; primIndex < gltfMesh->primitives_count;
         ++primIndex) {
      cgltf_primitive *prim = &gltfMesh->primitives[primIndex];
      SubMesh *subMesh = &mesh->subMeshes[primIndex];

      subMesh->numIndices = prim->indices->count;
      subMesh->indices = MMALLOC_ARRAY(VertexIndex, subMesh->numIndices);
      VertexIndex maxIndex = 0;
      for (cgltf_size i = 0; i < prim->indices->count; ++i) {
        subMesh->indices[i] = cgltf_accessor_read_index(prim->indices, i);
        if (maxIndex < subMesh->indices[i]) {
          maxIndex = subMesh->indices[i];
        }
      }

      subMesh->numVertices = maxIndex + 1;
      subMesh->vertices = MMALLOC_ARRAY_ZEROES(Vertex, subMesh->numVertices);
      for (int i = 0; i < subMesh->numVertices; ++i) {
        subMesh->vertices[i].color = (Float4){1, 1, 1, 1};
      }
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
                (float *)&subMesh->vertices[vertexIndex].position,
                numComponents);
            ASSERT(readResult);
          }
          break;
        case cgltf_attribute_type_texcoord:
          for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
               ++vertexIndex) {
            cgltf_size numComponents = cgltf_num_components(attrib->data->type);
            cgltf_bool readResult = cgltf_accessor_read_float(
                attrib->data, vertexIndex,
                (float *)&subMesh->vertices[vertexIndex].texcoord,
                numComponents);
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
      vertexBufferSize += subMesh->numVertices * sizeof(Vertex);
      indexBufferSize += subMesh->numIndices * sizeof(VertexIndex);

      subMesh->material = prim->material - gltf->materials;
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
  model->nodes = MMALLOC_ARRAY_ZEROES(SceneNode, model->numNodes);
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
      node->childNodes = MMALLOC_ARRAY(int, node->numChildNodes);
      for (cgltf_size childIndex = 0; childIndex < gltfNode->children_count;
           ++childIndex) {
        node->childNodes[childIndex] =
            gltfNode->children[childIndex] - gltf->nodes;
      }
    }
  }

  model->numScenes = gltf->scenes_count;
  model->scenes = MMALLOC_ARRAY_ZEROES(Scene, model->numScenes);

  for (cgltf_size sceneIndex = 0; sceneIndex < gltf->scenes_count;
       ++sceneIndex) {
    cgltf_scene *gltfScene = &gltf->scenes[sceneIndex];
    Scene *scene = &model->scenes[sceneIndex];

    if (gltfScene->nodes_count > 0) {
      scene->numNodes = gltfScene->nodes_count;
      scene->nodes = MMALLOC_ARRAY(int, scene->numNodes);

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
  model->gpuIndexBuffer = nil;
  model->gpuVertexBuffer = nil;

  for (int i = 0; i < model->numScenes; ++i) {
    MFREE(model->scenes[i].nodes);
  }
  MFREE(model->scenes);

  for (int i = 0; i < model->numNodes; ++i) {
    MFREE(model->nodes[i].childNodes);
  }
  MFREE(model->nodes);

  for (int i = 0; i < model->numMeshes; ++i) {
    for (int j = 0; j < model->meshes[i].numSubMeshes; ++j) {
      MFREE(model->meshes[i].subMeshes[j].vertices);
      MFREE(model->meshes[i].subMeshes[j].indices);
    }
    MFREE(model->meshes[i].subMeshes);
  }
  MFREE(model->meshes);

  MFREE(model->materials);

  for (int i = 0; i < model->numSamplers; ++i) {
    model->samplers[i] = nil;
  }
  MFREE(model->samplers);

  for (int i = 0; i < model->numTextures; ++i) {
    model->textures[i] = nil;
  }
  MFREE(model->textures);
}

void renderMesh(const Model *model, const Mesh *mesh,
                id<MTLRenderCommandEncoder> renderEncoder) {
  for (int subMeshIndex = 0; subMeshIndex < mesh->numSubMeshes;
       ++subMeshIndex) {
    SubMesh *subMesh = &mesh->subMeshes[subMeshIndex];

    Material *material = &model->materials[subMesh->material];

    UniformsPerMaterial uniforms = {.baseColorFactor =
                                        material->baseColorFactor};
    [renderEncoder setVertexBytes:&uniforms length:sizeof(uniforms) atIndex:2];

    if (material->baseColorTexture >= 0) {
      [renderEncoder
          setFragmentTexture:model->textures[material->baseColorTexture]
                     atIndex:0];
    } else {
      [renderEncoder setFragmentTexture:gRenderer.defaultBaseColorTexture
                                atIndex:0];
    }

    if (material->baseColorSampler >= 0) {
      [renderEncoder
          setFragmentSamplerState:model->samplers[material->baseColorSampler]
                          atIndex:0];
    } else {
      [renderEncoder setFragmentSamplerState:gRenderer.defaultSampler
                                     atIndex:0];
    }

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

  [renderEncoder setVertexBytes:&uniform length:sizeof(uniform) atIndex:3];

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

static void loadModel(void) {
  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *gltfRelPath =
      [@"gltf" stringByAppendingPathComponent:
                   [NSString stringWithCString:gGUI.models[gGUI.selectedModel]
                                      encoding:NSUTF8StringEncoding]];
  NSString *gltfBasePath = [mainBundle pathForResource:gltfRelPath ofType:nil];
  if (!gltfBasePath) {
    gltfBasePath = [mainBundle pathForResource:gltfRelPath ofType:@"glb"];
  }
  ASSERT(gltfBasePath);
  loadGLTFModel(&gRenderer.model, gltfBasePath);
}

void initRenderer(MTKView *view) {
  gRenderer.device = MTLCreateSystemDefaultDevice();
  view.device = gRenderer.device;

  initGUI(gRenderer.device);

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

  MTLTextureDescriptor *defaultBaseColorTextureDesc = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                   width:1
                                  height:1
                               mipmapped:NO];
  gRenderer.defaultBaseColorTexture =
      [gRenderer.device newTextureWithDescriptor:defaultBaseColorTextureDesc];
  MTLRegion region = {
      .origin = {0, 0, 0},
      .size = {1, 1, 1},
  };
  uint32_t color = 0xffffffff;
  [gRenderer.defaultBaseColorTexture replaceRegion:region
                                       mipmapLevel:0
                                         withBytes:&color
                                       bytesPerRow:4];

  MTLSamplerDescriptor *defaultSamplerDesc =
      [[MTLSamplerDescriptor alloc] init];
  defaultSamplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
  defaultSamplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
  defaultSamplerDesc.mipFilter = MTLSamplerMipFilterLinear;
  defaultSamplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
  defaultSamplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
  defaultSamplerDesc.rAddressMode = MTLSamplerAddressModeRepeat;
  gRenderer.defaultSampler =
      [gRenderer.device newSamplerStateWithDescriptor:defaultSamplerDesc];

  loadModel();

  gRenderer.cam.distance = 5;
  gRenderer.cam.phi = -90;
  gRenderer.cam.theta = 0;
}

void destroyRenderer(void) {
  destroyModel(&gRenderer.model);
  gRenderer.defaultSampler = nil;
  gRenderer.depthStencilState = nil;
  gRenderer.pipeline = nil;
  gRenderer.library = nil;
  gRenderer.queue = nil;
  destroyGUI();
  gRenderer.device = nil;
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
  bool shouldLoadNewModel;
  doGUI(&shouldLoadNewModel);

  if (shouldLoadNewModel) {
    destroyModel(&gRenderer.model);
    loadModel();
  }

  gRenderer.uniformsPerView.viewMat = getOrbitCameraMatrix(&gRenderer.cam);
  Mat4 projection = mat4Perspective(
      degToRad(60), (float)getApp()->width / (float)getApp()->height, 0.01f,
      1000.f);
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

void onResizeWindow(void) {
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
  if (!isGUIHandlingMouseInput()) {
    gInput.mouseDelta = (Float2){dx, dy};
  }
}

void onMouseScrolled(float dy) {
  if (!isGUIHandlingMouseInput()) {
    gInput.wheelDelta = dy;
  }
}