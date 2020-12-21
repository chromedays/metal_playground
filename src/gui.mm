#include "gui.h"

#include "external/imgui/imgui_impl_osx.h"
#include "external/imgui/imgui_impl_metal.h"

GUI gGUI = {.models = {
                "AnimatedCube",
                "Avocado",
                "BoxVertexColors",
                "CesiumMilkTruck",
                "DamagedHelmet",
                "EnvironmentTest",
                "Sponza",
                "VC",
                "MetalRoughSpheres",
            }};

extern "C" {

void initGUI(id<MTLDevice> device) {
  ImGui::CreateContext();
  ImGui::StyleColorsDark();
  ImGui_ImplMetal_Init(device);
  ImGui_ImplOSX_Init();

  while (gGUI.models[gGUI.numModels]) {
    ++gGUI.numModels;
  }
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

void doGUI(bool *shouldLoadNewModel) {
  ImGui::Begin("Control Panel");
  ImGui::Checkbox("Render wireframe", &gGUI.wireframe);
  int newSelectedModel = gGUI.selectedModel;
  ImGui::ListBox("Select model", &newSelectedModel, gGUI.models,
                 gGUI.numModels);
  *shouldLoadNewModel = newSelectedModel != gGUI.selectedModel;
  gGUI.selectedModel = newSelectedModel;
  ImGui::End();
}

bool isGUIHandlingMouseDrag() {
  bool result = ImGui::GetIO().WantCaptureMouse;
  return result;
}
}