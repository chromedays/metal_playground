#pragma once
#include "str.h"
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <Windows.h>
#endif

typedef struct _App {
  String title;
  int width;
  int height;

#ifdef _WIN32
  struct {
    HWND window;
  } win32;
#endif
} App;

typedef void (*OnInit)(void);
typedef void (*OnUpdate)(float dt);
typedef void (*OnCleanup)(void);

int runMain(int argc, char **argv, const char *title, int width, int height,
            OnInit init, OnUpdate update, OnCleanup cleanup);

App *getApp(void);

typedef enum _ResourceType {
  ResourceType_Common = 0,
  ResourceType_Shader,

  ResourceType_Count
} ResourceType;

String createResourcePath(ResourceType type, const char *relPath);

void *readFileData(const String *path, bool nullTerminate, int *outFileSize);
void destroyFileData(void *data);
