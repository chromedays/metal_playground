#include "gui.h"
#include "external/toml.h"
#include "external/imgui/imgui_impl_osx.h"
#include "external/imgui/imgui_impl_metal.h"

GUI gGUI = {
    .models =
        {
            "AnimatedCube",
            "Avocado",
            "BoxVertexColors",
            "CesiumMilkTruck",
            "DamagedHelmet",
            "EnvironmentTest",
            "Sponza",
            "VC",
            "MetalRoughSpheres",
            "MultiUVTest",
        },
    .selectedModel = 0,
};

extern "C" {

void initGUI(id<MTLDevice> device) {
  ImGui::CreateContext();
  ImGui::StyleColorsDark();
  ImGui_ImplMetal_Init(device);
  ImGui_ImplOSX_Init();

  NSBundle *mainBundle = [NSBundle mainBundle];
  NSString *gltfConfigPath = [mainBundle pathForResource:@"gltf_list"
                                                  ofType:@"toml"];
  ASSERT(gltfConfigPath);

  FILE *f = fopen([gltfConfigPath UTF8String], "r");
  ASSERT(f);

  toml_table_t *table = toml_parse_file(f, NULL, 0);
  ASSERT(table);

  toml_array_t *gltfFileNames = toml_array_in(table, "files");
  int gltfNumFiles = toml_array_nelem(gltfFileNames);
  ASSERT(gltfNumFiles <= MAX_NUM_MODELS);
  gGUI.numModels = gltfNumFiles;
  for (int i = 0; i < gltfNumFiles; ++i) {
    toml_datum_t fileName = toml_string_at(gltfFileNames, i);
    strcpy(gGUI.models[i], fileName.u.s);
  }

  toml_free(table);

  fclose(f);
}

void destroyGUI(void) {
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
  static const char *models[MAX_NUM_MODELS] = {};
  for (int i = 0; i < gGUI.numModels; ++i) {
    models[i] = gGUI.models[i];
  }
  ImGui::ListBox("Select model", &newSelectedModel, models, gGUI.numModels,
                 gGUI.numModels);
  *shouldLoadNewModel = newSelectedModel != gGUI.selectedModel;
  gGUI.selectedModel = newSelectedModel;
  ImGui::End();
}

bool isGUIHandlingMouseInput(void) {
  bool result = ImGui::GetIO().WantCaptureMouse;
  return result;
}
}