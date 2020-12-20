#pragma once
#include "util.h"
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

void initRenderer(MTKView *view);
void render(MTKView *view, float dt);
void onResizeWindow();

C_INTERFACE_END