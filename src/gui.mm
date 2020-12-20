#include "gui.h"

#include "external/imgui/imgui_impl_osx.h"
#include "external/imgui/imgui_impl_metal.h"

GUI gGUI = {.scale = {1, 1, 1}, .axis = {0, 1, 0}, .wireframe = true};

extern "C" {

void initGUI(id<MTLDevice> device) {
  ImGui::CreateContext();
  ImGui::StyleColorsDark();
  ImGui_ImplMetal_Init(device);
  ImGui_ImplOSX_Init();
}

BOOL guiHandleOSXEvent(NSEvent *event, MTKView *view) {
  return ImGui_ImplOSX_HandleEvent(event, view);
}

void guiBeginFrame(MTKView *view) {
  ImGui_ImplMetal_NewFrame(view.currentRenderPassDescriptor);
  ImGui_ImplOSX_NewFrame(view);
  ImGui::NewFrame();
}

void guiEndFrameAndRender(id<MTLCommandBuffer> commandBufer,
                          id<MTLRenderCommandEncoder> renderEncoder) {
  ImGui::Render();
  [renderEncoder pushDebugGroup:@"ImGui"];
  ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBufer,
                                 renderEncoder);
  [renderEncoder popDebugGroup];
}

void doGUI() {
  ImGui::Begin("Control Panel");
  ImGui::SliderFloat3("Position", (float *)&gGUI.pos, -10, 10);
  ImGui::SliderFloat3("Scale", (float *)&gGUI.scale, 1, 30);
  ImGui::SliderFloat3("Axis", (float *)&gGUI.axis, -1, 1);
  ImGui::SliderAngle("Angle", &gGUI.angle);
  ImGui::Checkbox("Render wireframe", &gGUI.wireframe);
  ImGui::End();
}
}