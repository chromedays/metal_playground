#include "app.h"
#include "vmath.h"
#include "renderer.h"
#include "str.h"
#include "memory.h"
#include <stdbool.h>

typedef struct _PlaygroundScene {
  Model model;
  OrbitCamera cam;
} PlaygroundScene;

static PlaygroundScene gScene;

static void onInit() {
  String gltfPath =
      createResourcePath(ResourceType_Common, "gltf/AnimatedCube");
  loadGLTFModel(&gScene.model, &gltfPath);
  destroyString(&gltfPath);

  gScene.cam.distance = 3;
  gScene.cam.phi = -90;
  gScene.cam.theta = 0;
  gScene.cam.target = (Float3){0, 0, 0};
}

static void onUpdate(float dt) {
  App *app = getApp();

  FORMAT_STRING(&app->title, "Playground (dt: %f)", dt);

  gScene.cam.phi += 20.f * dt;

  setCamera(&gScene.cam);
  setDeferredGBufferPass();
  renderModel(&gScene.model, mat4Identity());
  setDeferredLightingPass();
}

static void onCleanup() { destroyModel(&gScene.model); }

int main(int argc, char **argv) {
  int returnVal = runMain(argc, argv, "Metal Playground", 1280, 720, onInit,
                          onUpdate, onCleanup);
  return returnVal;
}