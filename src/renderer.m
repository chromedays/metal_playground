#include "renderer.h"
#include "global.h"
#include "vmath.h"
#include "gui.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

typedef struct _Vertex {
  Float4 position;
  Float4 color;
} Vertex;

typedef uint32_t VertexIndex;
#define METAL_INDEX_TYPE MTLIndexTypeUInt32
#define METAL_CONSTANT_ALIGNMENT 256
#define NUM_BUFFERS_IN_FLIGHT 3

typedef struct _UniformBlock {
  Mat4 modelMat;
  Mat4 projMat;
} UniformBlock;

static struct {
  id<MTLDevice> device;
  id<MTLCommandQueue> queue;
  MTLPixelFormat viewPixelFormat;
  MTLPixelFormat viewDepthFormat;

  id<MTLLibrary> library;
  id<MTLRenderPipelineState> pipeline;
  id<MTLDepthStencilState> depthStencilState;

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

void initRenderer(MTKView *view) {
  gRenderer.device = MTLCreateSystemDefaultDevice();
  view.device = gRenderer.device;
  gRenderer.queue = [gRenderer.device newCommandQueue];
  gRenderer.viewPixelFormat = view.colorPixelFormat;
  gRenderer.viewDepthFormat = view.depthStencilPixelFormat;

  gRenderer.library = [gRenderer.device newLibraryWithFile:@"shaders.metallib"
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

  Vertex vertices[] = {{.position = {-1, 1, 1, 1}, .color = {0, 1, 1, 1}},
                       {.position = {-1, -1, 1, 1}, .color = {0, 0, 1, 1}},
                       {.position = {1, -1, 1, 1}, .color = {1, 0, 1, 1}},
                       {.position = {1, 1, 1, 1}, .color = {1, 1, 1, 1}},
                       {.position = {-1, 1, -1, 1}, .color = {0, 1, 0, 1}},
                       {.position = {-1, -1, -1, 1}, .color = {0, 0, 0, 1}},
                       {.position = {1, -1, -1, 1}, .color = {1, 0, 0, 1}},
                       {.position = {1, 1, -1, 1}, .color = {1, 1, 0, 1}}};

  VertexIndex indices[] = {3, 2, 6, 6, 7, 3, 4, 5, 1, 1, 0, 4,
                           4, 0, 3, 3, 7, 4, 1, 5, 6, 6, 2, 1,
                           0, 1, 2, 2, 3, 0, 7, 6, 5, 5, 4, 7};

  gRenderer.vertexBuffer = [gRenderer.device
      newBufferWithBytes:vertices
                  length:sizeof(vertices)
                 options:MTLResourceOptionCPUCacheModeDefault];
  gRenderer.indexBuffer = [gRenderer.device
      newBufferWithBytes:indices
                  length:sizeof(indices)
                 options:MTLResourceOptionCPUCacheModeDefault];
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
      MTLClearColorMake(0.1f, 0.1f, 0.1f, 1);
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
  NSUInteger numIndices = gRenderer.indexBuffer.length / sizeof(VertexIndex);
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
