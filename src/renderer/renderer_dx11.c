#include "../renderer.h"
#include "../app.h"
#include "../memory.h"
#include "../util.h"
#include <dxgidebug.h>
#include <d3dcompiler.h>
#define HR_ASSERT(exp)                                                         \
  do {                                                                         \
    HRESULT hr__ = (exp);                                                      \
    ASSERT(SUCCEEDED(hr__));                                                   \
  } while (0)
#define COM_RELEASE(com)                                                       \
  do {                                                                         \
    if (com) {                                                                 \
      com->lpVtbl->Release(com);                                               \
      com = NULL;                                                              \
    }                                                                          \
  } while (0)

typedef enum _ShaderType {
  ShaderType_Vertex,
  ShaderType_Fragment,
  ShaderType_Count,
} ShaderType;

static const char *gShaderTargets[ShaderType_Count] = {
    "vs_5_0",
    "ps_5_0",
};

typedef struct _Shader {
  ShaderType type;
  union {
    ID3D11VertexShader *vertex;
    ID3D11PixelShader *fragment;
  };
  ID3DBlob *code;
  void *bytecode;
  SIZE_T bytecodeLength;
} Shader;

typedef struct _Renderer {
  IDXGISwapChain *swapChain;
  ID3D11Device *device;
  ID3D11DeviceContext *context;
  ID3D11RenderTargetView *swapChainRTV;
  ID3D11Texture2D *swapChainDepthStencilBuffer;
  ID3D11DepthStencilView *swapChainDSV;

  ID3D11InputLayout *inputLayout;

  struct {
    ID3D11DepthStencilState *depthStencilState;
    ID3D11RasterizerState *rasterizerState;

    Shader vertexShader;
    Shader fragmentShader;
  } phong;

  Model tempModel;
  OrbitCamera cam;
} Renderer;
static Renderer gRenderer;

static Shader createShader(const char *path, ShaderType shaderType) {
  Shader shader = {.type = shaderType};

  String resourcePath = createResourcePath(ResourceType_Shader, path);

  int length;
  void *source = readFileData(&resourcePath, true, &length);

  ID3DBlob *shaderError;
  const char *target = gShaderTargets[shader.type];

  HR_ASSERT(D3DCompile(source, length, NULL, NULL, NULL, "main", target,
                       D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION, 0,
                       &shader.code, &shaderError));

  COM_RELEASE(shaderError);
  MFREE(source);

  shader.bytecode = ID3D10Blob_GetBufferPointer(shader.code);
  shader.bytecodeLength = ID3D10Blob_GetBufferSize(shader.code);

  switch (shader.type) {
  case ShaderType_Vertex:
    HR_ASSERT(ID3D11Device_CreateVertexShader(gRenderer.device, shader.bytecode,
                                              shader.bytecodeLength, NULL,
                                              &shader.vertex));
    break;
  case ShaderType_Fragment:
    HR_ASSERT(ID3D11Device_CreatePixelShader(gRenderer.device, shader.bytecode,
                                             shader.bytecodeLength, NULL,
                                             &shader.fragment));
    break;
  default:
    ASSERT(false);
    break;
  }

  destroyString(&resourcePath);

  return shader;
}

static void destroyShader(Shader *shader) {
  switch (shader->type) {
  case ShaderType_Vertex:
    COM_RELEASE(shader->vertex);
    break;
  case ShaderType_Fragment:
    COM_RELEASE(shader->fragment);
    break;
  default:
    ASSERT(false);
    break;
  }
  COM_RELEASE(shader->code);
  *shader = (Shader){0};
}

void initRenderer(void) {
  App *app = getApp();

  DXGI_FORMAT swapChainFormat = DXGI_FORMAT_R8G8B8A8_UNORM;

  DXGI_RATIONAL refreshRate = {0};
  {
    IDXGIFactory *factory;
    HR_ASSERT(CreateDXGIFactory(&IID_IDXGIFactory, (void **)&factory));

    IDXGIAdapter *adapter;
    HR_ASSERT(IDXGIFactory_EnumAdapters(factory, 0, &adapter));

    IDXGIOutput *adapterOutput;
    HR_ASSERT(IDXGIAdapter_EnumOutputs(adapter, 0, &adapterOutput));

    UINT numDisplayModes;
    HR_ASSERT(IDXGIOutput_GetDisplayModeList(adapterOutput, swapChainFormat,
                                             DXGI_ENUM_MODES_INTERLACED,
                                             &numDisplayModes, NULL));

    DXGI_MODE_DESC *displayModes =
        MMALLOC_ARRAY(DXGI_MODE_DESC, numDisplayModes);

    HR_ASSERT(IDXGIOutput_GetDisplayModeList(adapterOutput, swapChainFormat,
                                             DXGI_ENUM_MODES_INTERLACED,
                                             &numDisplayModes, displayModes));

    for (UINT i = 0; i < numDisplayModes; ++i) {
      DXGI_MODE_DESC *mode = &displayModes[i];
      if ((int)mode->Width == app->width && (int)mode->Height == app->height) {
        refreshRate = mode->RefreshRate;
      }
    }

    MFREE(displayModes);
    COM_RELEASE(adapterOutput);
    COM_RELEASE(adapter);
    COM_RELEASE(factory);
  }

  DXGI_SWAP_CHAIN_DESC swapChainDesc = {
      .BufferCount = 2,
      .BufferDesc =
          {
              .Width = app->width,
              .Height = app->height,
              .Format = DXGI_FORMAT_R8G8B8A8_UNORM,
              .RefreshRate = refreshRate,
          },
      .BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT,
      .OutputWindow = app->win32.window,
      .SampleDesc =
          {
              .Count = 1,
              .Quality = 0,
          },
      .SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD,
      .Windowed = TRUE,
  };

  UINT createDeviceFlags = D3D11_CREATE_DEVICE_DEBUG;

  D3D_FEATURE_LEVEL featureLevel = D3D_FEATURE_LEVEL_11_1;

  HR_ASSERT(D3D11CreateDeviceAndSwapChain(
      NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, createDeviceFlags, &featureLevel, 1,
      D3D11_SDK_VERSION, &swapChainDesc, &gRenderer.swapChain,
      &gRenderer.device, NULL, &gRenderer.context));

  ID3D11Texture2D *backBuffer;
  HR_ASSERT(IDXGISwapChain_GetBuffer(
      gRenderer.swapChain, 0, &IID_ID3D11Texture2D, (void **)&backBuffer));

  HR_ASSERT(ID3D11Device_CreateRenderTargetView(gRenderer.device,
                                                (ID3D11Resource *)backBuffer,
                                                NULL, &gRenderer.swapChainRTV));
  COM_RELEASE(backBuffer);

  D3D11_TEXTURE2D_DESC depthStencilBufferDesc = {
      .ArraySize = 1,
      .BindFlags = D3D11_BIND_DEPTH_STENCIL,
      .CPUAccessFlags = 0,
      .Format = DXGI_FORMAT_D32_FLOAT,
      .Width = app->width,
      .Height = app->height,
      .MipLevels = 1,
      .SampleDesc =
          {
              .Count = 1,
              .Quality = 0,
          },
      .Usage = D3D11_USAGE_DEFAULT,
  };
  HR_ASSERT(ID3D11Device_CreateTexture2D(
      gRenderer.device, &depthStencilBufferDesc, NULL,
      &gRenderer.swapChainDepthStencilBuffer));
  HR_ASSERT(ID3D11Device_CreateDepthStencilView(
      gRenderer.device, (ID3D11Resource *)gRenderer.swapChainDepthStencilBuffer,
      NULL, &gRenderer.swapChainDSV));

  D3D11_DEPTH_STENCIL_DESC depthStencilStateDesc = {
      .DepthEnable = TRUE,
      .DepthWriteMask = D3D11_DEPTH_WRITE_MASK_ALL,
      .DepthFunc = D3D11_COMPARISON_GREATER_EQUAL,
      .StencilEnable = FALSE,
  };
  HR_ASSERT(ID3D11Device_CreateDepthStencilState(
      gRenderer.device, &depthStencilStateDesc,
      &gRenderer.phong.depthStencilState));

  D3D11_RASTERIZER_DESC rasterizerStateDesc = {
      .AntialiasedLineEnable = FALSE,
      .CullMode = D3D11_CULL_BACK,
      .DepthBias = 0,
      .DepthBiasClamp = 0.f,
      .DepthClipEnable = TRUE,
      .FillMode = D3D11_FILL_SOLID,
      .FrontCounterClockwise = TRUE,
      .MultisampleEnable = FALSE,
      .ScissorEnable = FALSE,
      .SlopeScaledDepthBias = 0.f,
  };
  HR_ASSERT(
      ID3D11Device_CreateRasterizerState(gRenderer.device, &rasterizerStateDesc,
                                         &gRenderer.phong.rasterizerState));

  D3D11_INPUT_ELEMENT_DESC layoutDescs[] = {
      {
          .SemanticName = "TEXCOORD",
          .SemanticIndex = 0,
          .Format = DXGI_FORMAT_R32G32B32_FLOAT,
          .InputSlot = 0,
          .AlignedByteOffset = offsetof(Vertex, position),
          .InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA,
          .InstanceDataStepRate = 0,
      },
      {
          .SemanticName = "TEXCOORD",
          .SemanticIndex = 1,
          .Format = DXGI_FORMAT_R32G32B32A32_FLOAT,
          .InputSlot = 0,
          .AlignedByteOffset = offsetof(Vertex, color),
          .InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA,
          .InstanceDataStepRate = 0,
      },
      {
          .SemanticName = "TEXCOORD",
          .SemanticIndex = 2,
          .Format = DXGI_FORMAT_R32G32_FLOAT,
          .InputSlot = 0,
          .AlignedByteOffset = offsetof(Vertex, texcoord),
          .InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA,
          .InstanceDataStepRate = 0,
      },
      {
          .SemanticName = "TEXCOORD",
          .SemanticIndex = 3,
          .Format = DXGI_FORMAT_R32G32B32_FLOAT,
          .InputSlot = 0,
          .AlignedByteOffset = offsetof(Vertex, normal),
          .InputSlotClass = D3D11_INPUT_PER_VERTEX_DATA,
          .InstanceDataStepRate = 0,
      },
  };

  gRenderer.phong.vertexShader =
      createShader("phong_vert.hlsl", ShaderType_Vertex);
  gRenderer.phong.fragmentShader =
      createShader("phong_frag.hlsl", ShaderType_Fragment);

  HR_ASSERT(ID3D11Device_CreateInputLayout(
      gRenderer.device, layoutDescs, ARRAY_COUNT(layoutDescs),
      gRenderer.phong.vertexShader.bytecode,
      gRenderer.phong.vertexShader.bytecodeLength, &gRenderer.inputLayout));
}

void destroyRenderer(void) {
  destroyShader(&gRenderer.phong.fragmentShader);
  destroyShader(&gRenderer.phong.vertexShader);
  COM_RELEASE(gRenderer.phong.rasterizerState);
  COM_RELEASE(gRenderer.phong.depthStencilState);
  COM_RELEASE(gRenderer.inputLayout);
  COM_RELEASE(gRenderer.swapChainDSV);
  COM_RELEASE(gRenderer.swapChainDepthStencilBuffer);
  COM_RELEASE(gRenderer.swapChainRTV);
  COM_RELEASE(gRenderer.context);
  COM_RELEASE(gRenderer.device);
  COM_RELEASE(gRenderer.swapChain);
}

void render(void) {}