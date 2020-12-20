#pragma once
#include "util.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

typedef struct _GUI {
  float angle;
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