#pragma once
#include "util.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

void initGUI(id<MTLDevice> device);
BOOL guiHandleOSXEvent(NSEvent *event, MTKView *view);
void guiBeginFrame(MTKView *view);
void guiEndFrameAndRender(id<MTLCommandBuffer> commandBufer,
                          id<MTLRenderCommandEncoder> renderEncoder);

void guiDemo();

C_INTERFACE_END