#include "../app.h"
#include "../util.h"
#include "../renderer.h"
#include "../memory.h"
#include "../external/glad/wgl.h"
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

static struct Win32Internal {
  const char *className;
  HINSTANCE instance;
} gInternal = {
    .className = "CANT THIS JUST BE A RANDOM STRING",
};

static GLADapiproc loadGLProc(const char *name) {
  static HMODULE openglLibrary;
  if (!openglLibrary) {
    openglLibrary = LoadLibrary("opengl32.dll");
  }

  void *proc = NULL;

  if (openglLibrary) {
    proc = (void *)wglGetProcAddress(name);
    if (!proc) {
      proc = (void *)GetProcAddress(openglLibrary, name);
    }
  }

  return (GLADapiproc)proc;
}

static void initGL(HWND window) {
  PIXELFORMATDESCRIPTOR dummyPFD = {
      .nSize = sizeof(PIXELFORMATDESCRIPTOR),
      .nVersion = 1,
      .dwFlags = PFD_DRAW_TO_WINDOW | PFD_SUPPORT_OPENGL | PFD_DOUBLEBUFFER,
      .iPixelType = PFD_TYPE_RGBA,
      .cColorBits = 32,
      .cDepthBits = 24,
      .cStencilBits = 8,
  };

  HWND dummyWindow =
      CreateWindow(gInternal.className, gApp.title.buf, WS_OVERLAPPEDWINDOW,
                   CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
                   NULL, NULL, gInternal.instance, NULL);

  HDC dummyDC = GetDC(dummyWindow);
  int dummyPixelFormat = ChoosePixelFormat(dummyDC, &dummyPFD);
  SetPixelFormat(dummyDC, dummyPixelFormat, &dummyPFD);

  HGLRC dummyRC = wglCreateContext(dummyDC);
  wglMakeCurrent(dummyDC, dummyRC);

  gladLoadWGL(dummyDC, loadGLProc);

  wglMakeCurrent(NULL, NULL);
  wglDeleteContext(dummyRC);
  ReleaseDC(dummyWindow, dummyDC);
  DestroyWindow(dummyWindow);

  int pixelFormatAttribs[] = {WGL_DRAW_TO_WINDOW_ARB,
                              GL_TRUE,
                              WGL_SUPPORT_OPENGL_ARB,
                              GL_TRUE,
                              WGL_DOUBLE_BUFFER_ARB,
                              GL_TRUE,
                              WGL_PIXEL_TYPE_ARB,
                              WGL_TYPE_RGBA_ARB,
                              WGL_COLOR_BITS_ARB,
                              32,
                              WGL_DEPTH_BITS_ARB,
                              24,
                              WGL_STENCIL_BITS_ARB,
                              8,
                              0};
  int contextAttribs[] = {WGL_CONTEXT_MAJOR_VERSION_ARB,
                          3,
                          WGL_CONTEXT_MINOR_VERSION_ARB,
                          3,
                          WGL_CONTEXT_PROFILE_MASK_ARB,
                          WGL_CONTEXT_CORE_PROFILE_BIT_ARB,
                          0};

  HDC dc = GetDC(window);

  int pixelFormat;
  uint32_t numFormats;
  wglChoosePixelFormatARB(dc, pixelFormatAttribs, NULL, 1, &pixelFormat,
                          &numFormats);
  BOOL setPixelFormatResult = SetPixelFormat(dc, pixelFormat, NULL);
  ASSERT(setPixelFormatResult == TRUE);
  HGLRC rc = wglCreateContextAttribsARB(dc, NULL, contextAttribs);
  ASSERT(rc);
  wglMakeCurrent(dc, rc);
  gladLoadGL(loadGLProc);
}

int runMain(UNUSED int argc, UNUSED char **argv, const char *title, int width,
            int height, OnInit init, OnUpdate update, OnCleanup cleanup) {
  _CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);

  copyStringFromCStr(&gApp.title, title);
  gApp.width = width;
  gApp.height = height;

  ASSERT(width > 0 && height > 0 && init && update && cleanup);
  LOG("Hello Windows!");

  gInternal.instance = GetModuleHandle(NULL);

  WNDCLASSEX wc = {
      .cbSize = sizeof(wc),
      .style = CS_HREDRAW | CS_VREDRAW | CS_OWNDC,
      .lpfnWndProc = wndProc,
      .hInstance = gInternal.instance,
      .hCursor = LoadCursor(NULL, IDC_ARROW),
      .hbrBackground = (HBRUSH)(COLOR_WINDOW + 1),
      .lpszClassName = gInternal.className,
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

#ifdef RENDERER_GL33
  initGL(window);
#endif

  initRenderer();

  ShowWindow(window, SW_SHOW);
  UpdateWindow(window);

  LARGE_INTEGER freq;
  QueryPerformanceFrequency(&freq);
  LARGE_INTEGER prevCounter;
  QueryPerformanceCounter(&prevCounter);

  float targetTimeStep = 1 / 60.f;
  MSG msg = {0};

  HDC dc = GetDC(window);

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
#ifdef RENDERER_GL33
      glClearColor(0.1f, 0.1f, 0.1f, 1);
      glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
      render();
      SwapBuffers(dc);
#endif
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
  case WM_CLOSE:
    PostQuitMessage(0);
    break;
  default:
    result = DefWindowProc(window, msg, wp, lp);
    break;
  }

  return result;
}

static const char *gResourceRootPaths[ResourceType_Count] = {
    "../resources",
    "../src/shaders/generated/glsl330",
};

String createResourcePath(ResourceType type, const char *relPath) {
  String path = {0};

  static TCHAR tmp[MAX_PATH];

  DWORD len = GetModuleFileName(NULL, tmp, sizeof(tmp) / sizeof(TCHAR));
  for (int i = len - 1; i >= 0; --i) {
    if (tmp[i] == '\\') {
      tmp[i] = 0;
      break;
    }
  }
  copyStringFromCStr(&path, tmp);

  appendPathCStr(&path, gResourceRootPaths[type]);
  appendPathCStr(&path, relPath);

  return path;
}

void *readFileData(const String *path, bool nullTerminate, int *outFileSize) {
  HANDLE file = CreateFileA(path->buf, GENERIC_READ, FILE_SHARE_READ, NULL,
                            OPEN_EXISTING, 0, NULL);
  ASSERT(file != INVALID_HANDLE_VALUE);
  DWORD fileSize = GetFileSize(file, NULL);

  uint8_t *data = MMALLOC_ARRAY(uint8_t, fileSize + (nullTerminate ? 1 : 0));

  DWORD bytesRead;
  ReadFile(file, data, fileSize, &bytesRead, NULL);
  ASSERT(fileSize == bytesRead);
  if (nullTerminate) {
    data[fileSize] = 0;
  }

  if (outFileSize) {
    *outFileSize = (int)fileSize;
  }

  CloseHandle(file);

  return data;
}

void destroyFileData(void *data) { MFREE(data); }