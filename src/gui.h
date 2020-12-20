#pragma once
#include "util.h"
#include "vmath.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

typedef struct _GUI {
  Float3 pos;
  Float3 scale;
  Float3 axis;
  float angle;
  bool wireframe;
} GUI;

extern GUI gGUI;

void initGUI(id<MTLDevice> device);
BOOL guiHandleOSXEvent(NSEvent *event, MTKView *view);
void guiBeginFrame(MTKView *view);
void guiEndFrameAndRender(id<MTLCommandBuffer> commandBufer,
                          id<MTLRenderCommandEncoder> renderEncoder);

void doGUI();

void guiDemo();

C_INTERFACE_END