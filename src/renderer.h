#pragma once
#include "util.h"
#import <MetalKit/MetalKit.h>

C_INTERFACE_BEGIN

void initRenderer(MTKView *view);
void render(MTKView *view, float dt);

C_INTERFACE_END