#pragma once
#include "str.h"

typedef struct _App {
  String title;
  int width;
  int height;
} App;

typedef void (*OnInit)(void);
typedef void (*OnUpdate)(void);
typedef void (*OnCleanup)(void);

int runMain(int argc, char **argv, const char *title, int width, int height,
            OnInit init, OnUpdate update, OnCleanup cleanup);

App *getApp();