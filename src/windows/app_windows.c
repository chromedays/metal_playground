#include "../app.h"
#include "../util.h"
#include <stdio.h>

static App gApp;
App *getApp(void) { return &gApp; }

int runMain(UNUSED int argc, UNUSED char **argv, UNUSED const char *title, int width,
            int height, OnInit init, OnUpdate update, OnCleanup cleanup) {
  ASSERT(width > 0 && height > 0 && init && update && cleanup);
  printf("Hello Windows!");
  return 0;
}