#include "gui.h"

#include "external/imgui/imgui_impl_osx.h"
#include "external/imgui/imgui_impl_metal.h"

GUI gGUI;

extern "C" {

void initGUI(id<MTLDevice> device) {
  ImGui::CreateContext();
  ImGui::StyleColorsDark();
  ImGui_ImplMetal_Init(device);
  ImGui_ImplOSX_Init();
}

void destroyGUI() {
  ImGui_ImplOSX_Shutdown();
  ImGui_ImplMetal_Shutdown();
  ImGui::DestroyContext();
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
  ImGui::Checkbox("Render wireframe", &gGUI.wireframe);
  ImGui::End();
}

bool isGUIHandlingMouseDrag() {
  bool result = ImGui::GetIO().WantCaptureMouse;
  return result;
}
}