#pragma once

typedef struct _App {
  int width;
  int height;
} App;

typedef void (*OnInit)(void);
typedef void (*OnUpdate)(void);
typedef void (*OnCleanup)(void);

int runMain(int argc, char **argv, int width, int height, OnInit init,
            OnUpdate update, OnCleanup cleanup);