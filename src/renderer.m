#include "renderer.h"
#include "global.h"
#include "vmath.h"
#include "gui.h"
#include "memory.h"
#define CGLTF_IMPLEMENTATION
#include "external/cgltf.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

typedef struct _Vertex {
  Float4 position;
  Float4 color;
  Float2 texcoord;
} Vertex;

typedef uint32_t VertexIndex;
#define METAL_INDEX_TYPE MTLIndexTypeUInt32
#define METAL_CONSTANT_ALIGNMENT 256
#define NUM_BUFFERS_IN_FLIGHT 3

typedef struct _UniformBlock {
  Mat4 modelMat;
  Mat4 projMat;
} UniformBlock;

typedef struct _SubMesh {
  int numVertices;
  Vertex *vertices;
  int numIndices;
  VertexIndex *indices;
} SubMesh;

typedef struct _Mesh {
  SubMesh *subMeshes;
} Mesh;

typedef struct _Model {
  int numMeshes;
  Mesh *meshes;
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
        subMesh->vertices[vertexIndex].position.w = 1;
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
        subMesh->vertices[vertexIndex].color.w = 1;
        ASSERT(readResult);
      }
      break;
    default:
      break;
    }
  }
}

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

  for (cgltf_size meshIndex = 0; meshIndex < gltf->meshes_count; ++meshIndex) {
    cgltf_mesh *mesh = &gltf->meshes[meshIndex];

    model->meshes[meshIndex].subMeshes =
        MALLOC_ARRAY(SubMesh, mesh->primitives_count);

    for (cgltf_size primIndex = 0; primIndex < mesh->primitives_count;
         ++primIndex) {
      model->meshes[meshIndex].subMeshes[primIndex] = (SubMesh){0};
      initSubMeshFromGLTFPrimitive(
          &model->meshes[meshIndex].subMeshes[primIndex],
          &mesh->primitives[primIndex]);
    }
  }

  for (cgltf_size i = 0; i < gltf->buffers_count; ++i) {
    cgltf_buffer *buffer = &gltf->buffers[i];
    ASSERT(buffer->data);
    LOG("Parsing gltf buffer (%s)", gltf->buffers[i].uri);
  }

  cgltf_free(gltf);
}

void destroyMesh() {}

static struct {
  id<MTLDevice> device;
  id<MTLCommandQueue> queue;
  MTLPixelFormat viewPixelFormat;
  MTLPixelFormat viewDepthFormat;

  id<MTLLibrary> library;
  id<MTLRenderPipelineState> pipeline;
  id<MTLDepthStencilState> depthStencilState;

  Model model;

  id<MTLBuffer> vertexBuffer;
  id<MTLBuffer> indexBuffer;
  //   id<MTLBuffer> uniformBuffer;

  UniformBlock uniformBlock;
} gRenderer;

#if 0
static int divideRounded(int n, int d) {
  int result = (n + d - 1) / d;
  return result;
}

static int alignUp(int n, int alignment) {
  int result = divideRounded(n, alignment) * alignment;
  return result;
}
#endif

void initVertexAndIndexBufferWithSubMesh(__strong id<MTLBuffer> *vertexBuffer,
                                         __strong id<MTLBuffer> *indexBuffer,
                                         const SubMesh *subMesh) {
  *vertexBuffer = [gRenderer.device
      newBufferWithBytes:subMesh->vertices
                  length:sizeof(Vertex) * subMesh->numVertices
                 options:MTLResourceOptionCPUCacheModeDefault];
  *indexBuffer = [gRenderer.device
      newBufferWithBytes:subMesh->indices
                  length:sizeof(VertexIndex) * subMesh->numIndices
                 options:MTLResourceOptionCPUCacheModeDefault];
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

  // Vertex vertices[] = {{.position = {-1, 1, 1, 1}, .color = {0, 1, 1, 1}},
  //                      {.position = {-1, -1, 1, 1}, .color = {0, 0, 1, 1}},
  //                      {.position = {1, -1, 1, 1}, .color = {1, 0, 1, 1}},
  //                      {.position = {1, 1, 1, 1}, .color = {1, 1, 1, 1}},
  //                      {.position = {-1, 1, -1, 1}, .color = {0, 1, 0, 1}},
  //                      {.position = {-1, -1, -1, 1}, .color = {0, 0, 0, 1}},
  //                      {.position = {1, -1, -1, 1}, .color = {1, 0, 0, 1}},
  //                      {.position = {1, 1, -1, 1}, .color = {1, 1, 0, 1}}};

  // VertexIndex indices[] = {3, 2, 6, 6, 7, 3, 4, 5, 1, 1, 0, 4,
  //                          4, 0, 3, 3, 7, 4, 1, 5, 6, 6, 2, 1,
  //                          0, 1, 2, 2, 3, 0, 7, 6, 5, 5, 4, 7};

  NSString *gltfBasePath = [mainBundle pathForResource:@"BoxVertexColors"
                                                ofType:nil];
  loadGLTFModel(&gRenderer.model, gltfBasePath);
  initVertexAndIndexBufferWithSubMesh(&gRenderer.vertexBuffer,
                                      &gRenderer.indexBuffer,
                                      &gRenderer.model.meshes[0].subMeshes[0]);

  // gRenderer.vertexBuffer = [gRenderer.device
  //     newBufferWithBytes:gRenderer.model.meshes[0].subMeshes[0].indices
  //                 length:sizeof(VertexIndex) *
  //                        gRenderer.model.meshes[0].subMeshes[0].numIndices
  //                options:MTLResourceOptionCPUCacheModeDefault];
  // gRenderer.indexBuffer = [gRenderer.device
  //     newBufferWithBytes:gRenderer.model.meshes[0].subMeshes[0].vertices
  //                 length:sizeof(Vertex) *
  //                        gRenderer.model.meshes[0].subMeshes[0].numVertices
  //                options:MTLResourceOptionCPUCacheModeDefault];
  //   gRenderer.uniformBuffer = [gRenderer.device
  //       newBufferWithLength:alignUp(sizeof(UniformBlock),
  //                                   METAL_CONSTANT_ALIGNMENT) *
  //                           NUM_BUFFERS_IN_FLIGHT
  //                   options:MTLResourceOptionCPUCacheModeDefault];
  //   gRenderer.uniformBlock.mvp = mat4Identity();

  initGUI(gRenderer.device);
}

void render(MTKView *view, float dt) {

  guiBeginFrame(view);
  doGUI();

  Mat4 projection =
      mat4Perspective(degToRad(60), gScreenWidth / gScreenHeight, 1, 10.f);
  gRenderer.uniformBlock.projMat = projection;

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
  [renderEncoder setCullMode:MTLCullModeNone];
  [renderEncoder setTriangleFillMode:MTLTriangleFillModeFill];

  gRenderer.uniformBlock.modelMat = mat4Multiply(
      mat4Translate((Float3){0, 0, -5.1f}), mat4RotateY(gGUI.angle));
  [renderEncoder setVertexBuffer:gRenderer.vertexBuffer offset:0 atIndex:0];
  [renderEncoder setVertexBytes:&gRenderer.uniformBlock
                         length:sizeof(gRenderer.uniformBlock)
                        atIndex:1];
  // [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
  //                   vertexStart:0
  //                   vertexCount:3];
  NSUInteger numIndices = 36;
  [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                            indexCount:numIndices
                             indexType:METAL_INDEX_TYPE
                           indexBuffer:gRenderer.indexBuffer
                     indexBufferOffset:0];

  guiEndFrameAndRender(commandBuffer, renderEncoder);

  [renderEncoder endEncoding];
  [commandBuffer presentDrawable:view.currentDrawable];
  [commandBuffer commit];
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
