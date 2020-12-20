#pragma once
#include "util.h"
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

void initRenderer(MTKView *view);
void render(MTKView *view, float dt);
void onResizeWindow();
void onMouseDragged(float dx, float dy);
void onMouseScrolled(float dy);

C_INTERFACE_END