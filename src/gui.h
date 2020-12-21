#pragma once
#include "util.h"
#include "vmath.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

#define MAX_NUM_MODELS 100

typedef struct _GUI {
  bool wireframe;

  int numModels;
  const char *models[MAX_NUM_MODELS];
  int selectedModel;
} GUI;

extern GUI gGUI;

void initGUI(id<MTLDevice> device);
void destroyGUI();
BOOL guiHandleOSXEvent(NSEvent *event, MTKView *view);
void guiBeginFrame(MTKView *view);
void guiEndFrameAndRender(id<MTLCommandBuffer> commandBufer,
                          id<MTLRenderCommandEncoder> renderEncoder);

void doGUI(bool *shouldLoadNewModel);
bool isGUIHandlingMouseDrag();

void guiDemo();

C_INTERFACE_END