#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#include "vmath.c"

typedef struct _Vertex {
  Float4 position;
  Float4 color;
} Vertex;

typedef uint32_t VertexIndex;

typedef struct _UniformBlock {
  Mat4 mvp;
} UniformBlock;

static struct {
  id<MTLDevice> device;
  id<MTLCommandQueue> queue;
  MTLPixelFormat viewPixelFormat;

  id<MTLLibrary> library;
  id<MTLRenderPipelineState> pipeline;
  id<MTLDepthStencilState> depthStencilState;

  id<MTLBuffer> vertexBuffer;
  id<MTLBuffer> indexBuffer;
  id<MTLBuffer> uniformBuffer;
} gRenderer;

#define METAL_CONSTANT_ALIGNMENT 256
#define NUM_BUFFERS_IN_FLIGHT 3

static int alignUp(int n, int alignment) {
  int result = ((n + alignment - 1) / alignment) * alignment;
  return result;
}

static void initRenderer(MTKView *view) {
  gRenderer.device = MTLCreateSystemDefaultDevice();
  view.device = gRenderer.device;
  gRenderer.queue = [gRenderer.device newCommandQueue];
  gRenderer.viewPixelFormat = ((CAMetalLayer *)view.layer).pixelFormat;

  gRenderer.library = [gRenderer.device newLibraryWithFile:@"shaders.metallib"
                                                     error:nil];
  //   gRenderer.library = [gRenderer.device newDefaultLibrary];
  MTLRenderPipelineDescriptor *pipelineDesc = [MTLRenderPipelineDescriptor new];
  pipelineDesc.vertexFunction =
      [gRenderer.library newFunctionWithName:@"vertex_main"];
  pipelineDesc.fragmentFunction =
      [gRenderer.library newFunctionWithName:@"fragment_main"];
  pipelineDesc.colorAttachments[0].pixelFormat = gRenderer.viewPixelFormat;
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
  gRenderer.uniformBuffer = [gRenderer.device
      newBufferWithLength:alignUp(sizeof(UniformBlock),
                                  METAL_CONSTANT_ALIGNMENT) *
                          NUM_BUFFERS_IN_FLIGHT
                  options:MTLResourceOptionCPUCacheModeDefault];
}

static void render(MTKView *view) {

  id<MTLCommandBuffer> commandBuffer = [gRenderer.queue commandBuffer];
  MTLRenderPassDescriptor *renderPassDescriptor =
      view.currentRenderPassDescriptor;
  renderPassDescriptor.colorAttachments[0].clearColor =
      MTLClearColorMake(1, 1, 1, 1);
  id<MTLRenderCommandEncoder> renderEncoder =
      [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
  [renderEncoder setRenderPipelineState:gRenderer.pipeline];
  //   [renderEncoder setDepthStencilState:gRenderer.depthStencilState];
  [renderEncoder setFrontFacingWinding:MTLWindingCounterClockwise];
  [renderEncoder setCullMode:MTLCullModeNone];
  [renderEncoder setVertexBuffer:gRenderer.vertexBuffer offset:0 atIndex:0];
  int bufferIndex = 0;
  NSUInteger uniformBufferOffset =
      alignUp(sizeof(UniformBlock), METAL_CONSTANT_ALIGNMENT) * bufferIndex;
  [renderEncoder setVertexBuffer:gRenderer.uniformBuffer
                          offset:uniformBufferOffset
                         atIndex:1];
  [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle
                    vertexStart:0
                    vertexCount:3];
  [renderEncoder endEncoding];
  [commandBuffer presentDrawable:view.currentDrawable];
  [commandBuffer commit];
}
