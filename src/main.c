#include "app.h"
#include <stdbool.h>

static void onInit() {}

static void onUpdate() {}

static void onCleanup() {}

int main(int argc, char **argv) {
  int returnVal = runMain(argc, argv, "Metal Playground", 1280, 720, onInit,
                          onUpdate, onCleanup);
  return returnVal;
}