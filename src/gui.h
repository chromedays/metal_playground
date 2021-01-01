#pragma once
#include "util.h"
#include "vmath.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

#define MAX_NUM_MODELS 100
#define MAX_FILENAME_LENGTH 100

typedef struct _GUI {
  bool wireframe;

  int numModels;
  char models[MAX_NUM_MODELS][MAX_FILENAME_LENGTH];
  int selectedModel;
} GUI;

extern GUI gGUI;

void initGUI(id<MTLDevice> device);
void destroyGUI(void);
BOOL guiHandleOSXEvent(NSEvent *event, MTKView *view);
void guiBeginFrame(MTKView *view);
void guiEndFrameAndRender(id<MTLCommandBuffer> commandBufer,
                          id<MTLRenderCommandEncoder> renderEncoder);

void doGUI(bool *shouldLoadNewModel);
bool isGUIHandlingMouseInput(void);

void guiDemo(void);

C_INTERFACE_END