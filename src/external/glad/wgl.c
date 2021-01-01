#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "wgl.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wmissing-variable-declarations"

#ifndef GLAD_IMPL_UTIL_C_
#define GLAD_IMPL_UTIL_C_

#ifdef _MSC_VER
#define GLAD_IMPL_UTIL_SSCANF sscanf_s
#else
#define GLAD_IMPL_UTIL_SSCANF sscanf
#endif

#endif /* GLAD_IMPL_UTIL_C_ */

#ifdef __cplusplus
extern "C" {
#endif



int GLAD_WGL_VERSION_1_0 = 0;
int GLAD_WGL_ARB_create_context = 0;
int GLAD_WGL_ARB_create_context_no_error = 0;
int GLAD_WGL_ARB_create_context_profile = 0;
int GLAD_WGL_ARB_create_context_robustness = 0;
int GLAD_WGL_ARB_extensions_string = 0;
int GLAD_WGL_ARB_framebuffer_sRGB = 0;
int GLAD_WGL_ARB_pixel_format = 0;
int GLAD_WGL_ARB_pixel_format_float = 0;
int GLAD_WGL_EXT_extensions_string = 0;


static void _pre_call_wgl_callback_default(const char *name, GLADapiproc apiproc, int len_args, ...) {
    (void) name;
    (void) apiproc;
    (void) len_args;
}
static void _post_call_wgl_callback_default(void *ret, const char *name, GLADapiproc apiproc, int len_args, ...) {
    (void) ret;
    (void) name;
    (void) apiproc;
    (void) len_args;
}

static GLADprecallback _pre_call_wgl_callback = _pre_call_wgl_callback_default;
void gladSetWGLPreCallback(GLADprecallback cb) {
    _pre_call_wgl_callback = cb;
}
static GLADpostcallback _post_call_wgl_callback = _post_call_wgl_callback_default;
void gladSetWGLPostCallback(GLADpostcallback cb) {
    _post_call_wgl_callback = cb;
}

PFNWGLCHOOSEPIXELFORMATARBPROC glad_wglChoosePixelFormatARB = NULL;
static BOOL GLAD_API_PTR glad_debug_impl_wglChoosePixelFormatARB(HDC hdc, const int * piAttribIList, const FLOAT * pfAttribFList, UINT nMaxFormats, int * piFormats, UINT * nNumFormats) {
    BOOL ret;
    _pre_call_wgl_callback("wglChoosePixelFormatARB", (GLADapiproc) glad_wglChoosePixelFormatARB, 6, hdc, piAttribIList, pfAttribFList, nMaxFormats, piFormats, nNumFormats);
    ret = glad_wglChoosePixelFormatARB(hdc, piAttribIList, pfAttribFList, nMaxFormats, piFormats, nNumFormats);
    _post_call_wgl_callback((void*) &ret, "wglChoosePixelFormatARB", (GLADapiproc) glad_wglChoosePixelFormatARB, 6, hdc, piAttribIList, pfAttribFList, nMaxFormats, piFormats, nNumFormats);
    return ret;
}
PFNWGLCHOOSEPIXELFORMATARBPROC glad_debug_wglChoosePixelFormatARB = glad_debug_impl_wglChoosePixelFormatARB;
PFNWGLCREATECONTEXTATTRIBSARBPROC glad_wglCreateContextAttribsARB = NULL;
static HGLRC GLAD_API_PTR glad_debug_impl_wglCreateContextAttribsARB(HDC hDC, HGLRC hShareContext, const int * attribList) {
    HGLRC ret;
    _pre_call_wgl_callback("wglCreateContextAttribsARB", (GLADapiproc) glad_wglCreateContextAttribsARB, 3, hDC, hShareContext, attribList);
    ret = glad_wglCreateContextAttribsARB(hDC, hShareContext, attribList);
    _post_call_wgl_callback((void*) &ret, "wglCreateContextAttribsARB", (GLADapiproc) glad_wglCreateContextAttribsARB, 3, hDC, hShareContext, attribList);
    return ret;
}
PFNWGLCREATECONTEXTATTRIBSARBPROC glad_debug_wglCreateContextAttribsARB = glad_debug_impl_wglCreateContextAttribsARB;
PFNWGLGETEXTENSIONSSTRINGARBPROC glad_wglGetExtensionsStringARB = NULL;
static const char * GLAD_API_PTR glad_debug_impl_wglGetExtensionsStringARB(HDC hdc) {
    const char * ret;
    _pre_call_wgl_callback("wglGetExtensionsStringARB", (GLADapiproc) glad_wglGetExtensionsStringARB, 1, hdc);
    ret = glad_wglGetExtensionsStringARB(hdc);
    _post_call_wgl_callback((void*) &ret, "wglGetExtensionsStringARB", (GLADapiproc) glad_wglGetExtensionsStringARB, 1, hdc);
    return ret;
}
PFNWGLGETEXTENSIONSSTRINGARBPROC glad_debug_wglGetExtensionsStringARB = glad_debug_impl_wglGetExtensionsStringARB;
PFNWGLGETEXTENSIONSSTRINGEXTPROC glad_wglGetExtensionsStringEXT = NULL;
static const char * GLAD_API_PTR glad_debug_impl_wglGetExtensionsStringEXT(void) {
    const char * ret;
    _pre_call_wgl_callback("wglGetExtensionsStringEXT", (GLADapiproc) glad_wglGetExtensionsStringEXT, 0);
    ret = glad_wglGetExtensionsStringEXT();
    _post_call_wgl_callback((void*) &ret, "wglGetExtensionsStringEXT", (GLADapiproc) glad_wglGetExtensionsStringEXT, 0);
    return ret;
}
PFNWGLGETEXTENSIONSSTRINGEXTPROC glad_debug_wglGetExtensionsStringEXT = glad_debug_impl_wglGetExtensionsStringEXT;
PFNWGLGETPIXELFORMATATTRIBFVARBPROC glad_wglGetPixelFormatAttribfvARB = NULL;
static BOOL GLAD_API_PTR glad_debug_impl_wglGetPixelFormatAttribfvARB(HDC hdc, int iPixelFormat, int iLayerPlane, UINT nAttributes, const int * piAttributes, FLOAT * pfValues) {
    BOOL ret;
    _pre_call_wgl_callback("wglGetPixelFormatAttribfvARB", (GLADapiproc) glad_wglGetPixelFormatAttribfvARB, 6, hdc, iPixelFormat, iLayerPlane, nAttributes, piAttributes, pfValues);
    ret = glad_wglGetPixelFormatAttribfvARB(hdc, iPixelFormat, iLayerPlane, nAttributes, piAttributes, pfValues);
    _post_call_wgl_callback((void*) &ret, "wglGetPixelFormatAttribfvARB", (GLADapiproc) glad_wglGetPixelFormatAttribfvARB, 6, hdc, iPixelFormat, iLayerPlane, nAttributes, piAttributes, pfValues);
    return ret;
}
PFNWGLGETPIXELFORMATATTRIBFVARBPROC glad_debug_wglGetPixelFormatAttribfvARB = glad_debug_impl_wglGetPixelFormatAttribfvARB;
PFNWGLGETPIXELFORMATATTRIBIVARBPROC glad_wglGetPixelFormatAttribivARB = NULL;
static BOOL GLAD_API_PTR glad_debug_impl_wglGetPixelFormatAttribivARB(HDC hdc, int iPixelFormat, int iLayerPlane, UINT nAttributes, const int * piAttributes, int * piValues) {
    BOOL ret;
    _pre_call_wgl_callback("wglGetPixelFormatAttribivARB", (GLADapiproc) glad_wglGetPixelFormatAttribivARB, 6, hdc, iPixelFormat, iLayerPlane, nAttributes, piAttributes, piValues);
    ret = glad_wglGetPixelFormatAttribivARB(hdc, iPixelFormat, iLayerPlane, nAttributes, piAttributes, piValues);
    _post_call_wgl_callback((void*) &ret, "wglGetPixelFormatAttribivARB", (GLADapiproc) glad_wglGetPixelFormatAttribivARB, 6, hdc, iPixelFormat, iLayerPlane, nAttributes, piAttributes, piValues);
    return ret;
}
PFNWGLGETPIXELFORMATATTRIBIVARBPROC glad_debug_wglGetPixelFormatAttribivARB = glad_debug_impl_wglGetPixelFormatAttribivARB;


static void glad_wgl_load_WGL_ARB_create_context(GLADuserptrloadfunc load, void *userptr) {
    if(!GLAD_WGL_ARB_create_context) return;
    glad_wglCreateContextAttribsARB = (PFNWGLCREATECONTEXTATTRIBSARBPROC) load(userptr, "wglCreateContextAttribsARB");
}
static void glad_wgl_load_WGL_ARB_extensions_string(GLADuserptrloadfunc load, void *userptr) {
    if(!GLAD_WGL_ARB_extensions_string) return;
    glad_wglGetExtensionsStringARB = (PFNWGLGETEXTENSIONSSTRINGARBPROC) load(userptr, "wglGetExtensionsStringARB");
}
static void glad_wgl_load_WGL_ARB_pixel_format(GLADuserptrloadfunc load, void *userptr) {
    if(!GLAD_WGL_ARB_pixel_format) return;
    glad_wglChoosePixelFormatARB = (PFNWGLCHOOSEPIXELFORMATARBPROC) load(userptr, "wglChoosePixelFormatARB");
    glad_wglGetPixelFormatAttribfvARB = (PFNWGLGETPIXELFORMATATTRIBFVARBPROC) load(userptr, "wglGetPixelFormatAttribfvARB");
    glad_wglGetPixelFormatAttribivARB = (PFNWGLGETPIXELFORMATATTRIBIVARBPROC) load(userptr, "wglGetPixelFormatAttribivARB");
}
static void glad_wgl_load_WGL_EXT_extensions_string(GLADuserptrloadfunc load, void *userptr) {
    if(!GLAD_WGL_EXT_extensions_string) return;
    glad_wglGetExtensionsStringEXT = (PFNWGLGETEXTENSIONSSTRINGEXTPROC) load(userptr, "wglGetExtensionsStringEXT");
}



static int glad_wgl_has_extension(HDC hdc, const char *ext) {
    const char *terminator;
    const char *loc;
    const char *extensions;

    if(wglGetExtensionsStringEXT == NULL && wglGetExtensionsStringARB == NULL)
        return 0;

    if(wglGetExtensionsStringARB == NULL || hdc == INVALID_HANDLE_VALUE)
        extensions = wglGetExtensionsStringEXT();
    else
        extensions = wglGetExtensionsStringARB(hdc);

    if(extensions == NULL || ext == NULL)
        return 0;

    while(1) {
        loc = strstr(extensions, ext);
        if(loc == NULL)
            break;

        terminator = loc + strlen(ext);
        if((loc == extensions || *(loc - 1) == ' ') &&
            (*terminator == ' ' || *terminator == '\0'))
        {
            return 1;
        }
        extensions = terminator;
    }

    return 0;
}

static GLADapiproc glad_wgl_get_proc_from_userptr(void *userptr, const char* name) {
    return (GLAD_GNUC_EXTENSION (GLADapiproc (*)(const char *name)) userptr)(name);
}

static int glad_wgl_find_extensions_wgl(HDC hdc) {
    GLAD_WGL_ARB_create_context = glad_wgl_has_extension(hdc, "WGL_ARB_create_context");
    GLAD_WGL_ARB_create_context_no_error = glad_wgl_has_extension(hdc, "WGL_ARB_create_context_no_error");
    GLAD_WGL_ARB_create_context_profile = glad_wgl_has_extension(hdc, "WGL_ARB_create_context_profile");
    GLAD_WGL_ARB_create_context_robustness = glad_wgl_has_extension(hdc, "WGL_ARB_create_context_robustness");
    GLAD_WGL_ARB_extensions_string = glad_wgl_has_extension(hdc, "WGL_ARB_extensions_string");
    GLAD_WGL_ARB_framebuffer_sRGB = glad_wgl_has_extension(hdc, "WGL_ARB_framebuffer_sRGB");
    GLAD_WGL_ARB_pixel_format = glad_wgl_has_extension(hdc, "WGL_ARB_pixel_format");
    GLAD_WGL_ARB_pixel_format_float = glad_wgl_has_extension(hdc, "WGL_ARB_pixel_format_float");
    GLAD_WGL_EXT_extensions_string = glad_wgl_has_extension(hdc, "WGL_EXT_extensions_string");
    return 1;
}

static int glad_wgl_find_core_wgl(void) {
    int major = 1, minor = 0;
    GLAD_WGL_VERSION_1_0 = (major == 1 && minor >= 0) || major > 1;
    return GLAD_MAKE_VERSION(major, minor);
}

int gladLoadWGLUserPtr(HDC hdc, GLADuserptrloadfunc load, void *userptr) {
    int version;
    wglGetExtensionsStringARB = (PFNWGLGETEXTENSIONSSTRINGARBPROC) load(userptr, "wglGetExtensionsStringARB");
    wglGetExtensionsStringEXT = (PFNWGLGETEXTENSIONSSTRINGEXTPROC) load(userptr, "wglGetExtensionsStringEXT");
    if(wglGetExtensionsStringARB == NULL && wglGetExtensionsStringEXT == NULL) return 0;
    version = glad_wgl_find_core_wgl();


    if (!glad_wgl_find_extensions_wgl(hdc)) return 0;
    glad_wgl_load_WGL_ARB_create_context(load, userptr);
    glad_wgl_load_WGL_ARB_extensions_string(load, userptr);
    glad_wgl_load_WGL_ARB_pixel_format(load, userptr);
    glad_wgl_load_WGL_EXT_extensions_string(load, userptr);

    return version;
}

int gladLoadWGL(HDC hdc, GLADloadfunc load) {
    return gladLoadWGLUserPtr(hdc, glad_wgl_get_proc_from_userptr, GLAD_GNUC_EXTENSION (void*) load);
}
 
void gladInstallWGLDebug() {
    glad_debug_wglChoosePixelFormatARB = glad_debug_impl_wglChoosePixelFormatARB;
    glad_debug_wglCreateContextAttribsARB = glad_debug_impl_wglCreateContextAttribsARB;
    glad_debug_wglGetExtensionsStringARB = glad_debug_impl_wglGetExtensionsStringARB;
    glad_debug_wglGetExtensionsStringEXT = glad_debug_impl_wglGetExtensionsStringEXT;
    glad_debug_wglGetPixelFormatAttribfvARB = glad_debug_impl_wglGetPixelFormatAttribfvARB;
    glad_debug_wglGetPixelFormatAttribivARB = glad_debug_impl_wglGetPixelFormatAttribivARB;
}

void gladUninstallWGLDebug() {
    glad_debug_wglChoosePixelFormatARB = glad_wglChoosePixelFormatARB;
    glad_debug_wglCreateContextAttribsARB = glad_wglCreateContextAttribsARB;
    glad_debug_wglGetExtensionsStringARB = glad_wglGetExtensionsStringARB;
    glad_debug_wglGetExtensionsStringEXT = glad_wglGetExtensionsStringEXT;
    glad_debug_wglGetPixelFormatAttribfvARB = glad_wglGetPixelFormatAttribfvARB;
    glad_debug_wglGetPixelFormatAttribivARB = glad_wglGetPixelFormatAttribivARB;
}


#ifdef __cplusplus
}
#endif

#pragma clang diagnostic pop