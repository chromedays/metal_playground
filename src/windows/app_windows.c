#include "../app.h"
#include "../util.h"
#include <stdio.h>
#include <stdint.h>
#include <stdio.h>
#include <Windows.h>
#include <ShellScalingApi.h>
#ifndef COBJMACROS
#define COBJMACROS
#endif
#include <d3d11_1.h>
#include <dxgidebug.h>
#include <d3dcompiler.h>
#include <crtdbg.h>

static App gApp;
App *getApp(void) { return &gApp; }

static LRESULT CALLBACK wndProc(HWND window, UINT msg, WPARAM wp, LPARAM lp);

int runMain(UNUSED int argc, UNUSED char **argv, const char *title, int width,
            int height, OnInit init, OnUpdate update, OnCleanup cleanup) {
  _CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);

  copyStringFromCStr(&gApp.title, title);
  gApp.width = width;
  gApp.height = height;

  ASSERT(width > 0 && height > 0 && init && update && cleanup);
  printf("Hello Windows!");

  WNDCLASSEX wc = {
      .cbSize = sizeof(wc),
      .style = CS_HREDRAW | CS_VREDRAW,
      .lpfnWndProc = wndProc,
      .hInstance = GetModuleHandle(NULL),
      .hCursor = LoadCursor(NULL, IDC_ARROW),
      .hbrBackground = (HBRUSH)(COLOR_WINDOW + 1),
      .lpszClassName = gApp.title.buf,
  };

  ATOM registerResult = RegisterClassEx(&wc);
  ASSERT(registerResult);

  RECT windowRect = {
      .left = 0,
      .top = 0,
      .right = gApp.width,
      .bottom = gApp.height,
  };
  AdjustWindowRect(&windowRect, WS_OVERLAPPEDWINDOW, FALSE);
  HWND window = CreateWindow(
      wc.lpszClassName, gApp.title.buf, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT,
      CW_USEDEFAULT, windowRect.right - windowRect.left,
      windowRect.bottom - windowRect.top, NULL, NULL, wc.hInstance, NULL);
  ASSERT(window);

  ShowWindow(window, SW_SHOW);
  UpdateWindow(window);

  LARGE_INTEGER freq;
  QueryPerformanceFrequency(&freq);
  LARGE_INTEGER prevCounter;
  QueryPerformanceCounter(&prevCounter);

  float targetTimeStep = 1 / 60.f;
  MSG msg = {0};

  while (msg.message != WM_QUIT) {

    if (PeekMessage(&msg, 0, 0, 0, PM_REMOVE)) {
      TranslateMessage(&msg);
      DispatchMessage(&msg);
    } else {
      LARGE_INTEGER currentCounter;
      QueryPerformanceCounter(&currentCounter);
      float deltaTime =
          (float)(currentCounter.QuadPart - prevCounter.QuadPart) /
          (float)freq.QuadPart;
      prevCounter = currentCounter;
      if (deltaTime > targetTimeStep) {
        deltaTime = targetTimeStep;
      }
    }
  }

  destroyString(&gApp.title);

  _CrtDumpMemoryLeaks();
  return 0;
}

static LRESULT CALLBACK wndProc(HWND window, UINT msg, WPARAM wp, LPARAM lp) {
  LRESULT result = 0;

  switch (msg) {
  case WM_PAINT: {
    PAINTSTRUCT paintStruct;
    BeginPaint(window, &paintStruct);
    EndPaint(window, &paintStruct);
  } break;
  case WM_DESTROY:
    PostQuitMessage(0);
    break;
  default:
    result = DefWindowProc(window, msg, wp, lp);
    break;
  }

  return result;
}