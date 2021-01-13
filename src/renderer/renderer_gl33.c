#include "../renderer.h"
#include "../memory.h"
#include "../app.h"
#include "../external/glad/gl.h"
#include <stdint.h>
#define CGLTF_IMPLEMENTATION
#include "../external/cgltf.h"
#define STB_IMAGE_IMPLEMENTATION
#include "../external/stb_image.h"

#define VIEW_BINDING 0
#define MATERIAL_BINDING 1
#define DRAW_BINDING 2

typedef struct _Renderer {
  uint32_t vao;
  struct {
    uint32_t program;
  } phong;

  // GBuffer pixel data
  // Texture 1: baseColor(rgb), metallic(a)
  // Texture 2: normal(rgb), roughness(a)
  // Texture 3: position(rgb), occlusion(a)
  struct {
    uint32_t gbufferFBO;
    uint32_t gbufferTextures[3];
    uint32_t gbufferDepth;
    uint32_t gbufferSampler;
    uint32_t gbufferProgram;
    int32_t gbufferTextureLocations[3];
    uint32_t lightingProgram;
  } deferred;

  uint32_t viewUniformBuffer;
  uint32_t materialUniformBuffer;
  uint32_t drawUniformBuffer;

  Model tempModel;

  OrbitCamera cam;
} Renderer;

static Renderer gRenderer;

static uint32_t createShaderProgram(const char *vertexShaderFilePath,
                                    const char *fragmentShaderFilePath);

static void setUniformBinding(uint32_t program, const char *name,
                              uint32_t binding) {
  uint32_t uniformIndex = glGetUniformBlockIndex(program, name);
  if (uniformIndex != (uint32_t)(-1)) {
    glUniformBlockBinding(program, uniformIndex, binding);
  }
}

static void setTexture(uint32_t texture, uint32_t sampler, int32_t location,
                       uint32_t unit) {
  if (location < 0) {
    return;
  }

  glActiveTexture(GL_TEXTURE0 + unit);
  glBindTexture(GL_TEXTURE_2D, texture);
  glUniform1i(location, unit);
  glBindSampler(unit, sampler);
}

static void GLAPIENTRY openglDebugCallback(UNUSED uint32_t source,
                                           uint32_t type, UNUSED uint32_t id,
                                           uint32_t severity,
                                           UNUSED int32_t length,
                                           const char *message,
                                           UNUSED const void *userdata) {

  LOG("GL CALLBACK: %s type = 0x%x, severity = 0x%x, message = %s",
      (type == GL_DEBUG_TYPE_ERROR ? "** GL ERROR **" : ""), type, severity,
      message);
}

void initRenderer(void) {
  App *app = getApp();

  if (GLAD_GL_KHR_debug) {
    glEnable(GL_DEBUG_OUTPUT);
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
    glDebugMessageCallback(openglDebugCallback, NULL);
  }

  glGenVertexArrays(1, &gRenderer.vao);
  glBindVertexArray(gRenderer.vao);

  gRenderer.phong.program =
      createShaderProgram("phong_vert.glsl", "phong_frag.glsl");
  setUniformBinding(gRenderer.phong.program, "type_ViewData", VIEW_BINDING);
  setUniformBinding(gRenderer.phong.program, "type_MaterialData",
                    MATERIAL_BINDING);
  setUniformBinding(gRenderer.phong.program, "type_DrawData", DRAW_BINDING);

  // Init deferred pipeline
  {
    glGenFramebuffers(1, &gRenderer.deferred.gbufferFBO);
    glBindFramebuffer(GL_FRAMEBUFFER, gRenderer.deferred.gbufferFBO);
    glGenTextures(ARRAY_COUNT(gRenderer.deferred.gbufferTextures),
                  gRenderer.deferred.gbufferTextures);

    // TODO: Handle window resizing
    glBindTexture(GL_TEXTURE_2D, gRenderer.deferred.gbufferTextures[0]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, app->width, app->height, 0,
                 GL_RGBA, GL_FLOAT, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D,
                           gRenderer.deferred.gbufferTextures[0], 0);

    glBindTexture(GL_TEXTURE_2D, gRenderer.deferred.gbufferTextures[1]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, app->width, app->height, 0,
                 GL_RGBA, GL_FLOAT, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_2D,
                           gRenderer.deferred.gbufferTextures[1], 0);

    glBindTexture(GL_TEXTURE_2D, gRenderer.deferred.gbufferTextures[2]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, app->width, app->height, 0,
                 GL_RGBA, GL_FLOAT, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT2, GL_TEXTURE_2D,
                           gRenderer.deferred.gbufferTextures[2], 0);

    uint32_t attachmentEnums[] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1,
                                  GL_COLOR_ATTACHMENT2};
    glDrawBuffers(ARRAY_COUNT(attachmentEnums), attachmentEnums);

    glGenRenderbuffers(1, &gRenderer.deferred.gbufferDepth);
    glBindRenderbuffer(GL_RENDERBUFFER, gRenderer.deferred.gbufferDepth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT32F, app->width,
                          app->height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER, gRenderer.deferred.gbufferDepth);

    ASSERT(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

    glGenSamplers(1, &gRenderer.deferred.gbufferSampler);
    glSamplerParameteri(gRenderer.deferred.gbufferSampler,
                        GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glSamplerParameteri(gRenderer.deferred.gbufferSampler,
                        GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    gRenderer.deferred.gbufferProgram =
        createShaderProgram("gbuffer_vert.glsl", "gbuffer_frag.glsl");
    gRenderer.deferred.lightingProgram = createShaderProgram(
        "deferred_lighting_vert.glsl", "deferred_lighting_frag.glsl");

    gRenderer.deferred.gbufferTextureLocations[0] =
        glGetUniformLocation(gRenderer.deferred.lightingProgram,
                             "SPIRV_Cross_Combinedgbuffer0gbufferSampler");
    gRenderer.deferred.gbufferTextureLocations[1] =
        glGetUniformLocation(gRenderer.deferred.lightingProgram,
                             "SPIRV_Cross_Combinedgbuffer1gbufferSampler");
    gRenderer.deferred.gbufferTextureLocations[2] =
        glGetUniformLocation(gRenderer.deferred.lightingProgram,
                             "SPIRV_Cross_Combinedgbuffer2gbufferSampler");
  }

  gRenderer.cam.distance = 1;
  gRenderer.cam.phi = -90;
  gRenderer.cam.theta = 0;
  gRenderer.cam.target = (Float3){0, 3, 0};

  ViewUniforms tempViewUniforms = {0};
  tempViewUniforms.viewMat = getOrbitCameraMatrix(&gRenderer.cam);
  tempViewUniforms.projMat = mat4Perspective(
      degToRad(60), (float)app->width / (float)app->height, 0.01f, 1000.f);

  MaterialUniforms tempMaterialUniforms = {
      .baseColorFactor = {0.5f, 1, 0.5f, 1},
  };

  DrawUniforms tempDrawUniforms = {
      .modelMat = mat4Identity(),
      .normalMat = mat4Identity(),
  };

  glGenBuffers(1, &gRenderer.viewUniformBuffer);
  glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.viewUniformBuffer);
  glBufferData(GL_UNIFORM_BUFFER, sizeof(tempViewUniforms), &tempViewUniforms,
               GL_DYNAMIC_DRAW);

  glGenBuffers(1, &gRenderer.materialUniformBuffer);
  glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.materialUniformBuffer);
  glBufferData(GL_UNIFORM_BUFFER, sizeof(tempMaterialUniforms),
               &tempMaterialUniforms, GL_DYNAMIC_DRAW);

  glGenBuffers(1, &gRenderer.drawUniformBuffer);
  glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.drawUniformBuffer);
  glBufferData(GL_UNIFORM_BUFFER, sizeof(tempDrawUniforms), &tempDrawUniforms,
               GL_DYNAMIC_DRAW);

  String gltfPath = createResourcePath(ResourceType_Common, "gltf/Sponza.glb");
  loadGLTFModel(&gRenderer.tempModel, &gltfPath);
  destroyString(&gltfPath);
}

void destroyRenderer(void) {
  destroyModel(&gRenderer.tempModel);

  glDeleteBuffers(1, &gRenderer.drawUniformBuffer);
  glDeleteBuffers(1, &gRenderer.materialUniformBuffer);
  glDeleteBuffers(1, &gRenderer.viewUniformBuffer);

  glDeleteProgram(gRenderer.deferred.lightingProgram);
  glDeleteProgram(gRenderer.deferred.gbufferProgram);
  glDeleteSamplers(1, &gRenderer.deferred.gbufferSampler);
  glDeleteRenderbuffers(1, &gRenderer.deferred.gbufferDepth);
  glDeleteTextures(ARRAY_COUNT(gRenderer.deferred.gbufferTextures),
                   gRenderer.deferred.gbufferTextures);
  glDeleteFramebuffers(1, &gRenderer.deferred.gbufferFBO);

  glDeleteVertexArrays(1, &gRenderer.vao);
  glDeleteProgram(gRenderer.phong.program);

  gRenderer = (Renderer){0};
}

void render(float dt) {
  App *app = getApp();

  FORMAT_STRING(&app->title, "Playground (dt: %f)", dt);

  glDepthRange(-1, 1);

  ViewUniforms tempViewUniforms = {0};
  tempViewUniforms.viewMat = getOrbitCameraMatrix(&gRenderer.cam);
  tempViewUniforms.projMat = mat4Perspective(
      degToRad(60), (float)app->width / (float)app->height, 0.1f, 2000.f);
  glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.viewUniformBuffer);
  glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(tempViewUniforms),
                  &tempViewUniforms);

  glBindFramebuffer(GL_FRAMEBUFFER, gRenderer.deferred.gbufferFBO);
  glUseProgram(gRenderer.deferred.gbufferProgram);

  glClearColor(0, 0, 0, 0);
  glClearDepth(0);
  glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_GEQUAL);
  glViewport(0, 0, app->width, app->height);

  renderModel(&gRenderer.tempModel, mat4Identity());

  glBindFramebuffer(GL_FRAMEBUFFER, 0);
  glUseProgram(gRenderer.deferred.lightingProgram);
  for (uint32_t i = 0; i < 3; ++i) {
    setTexture(gRenderer.deferred.gbufferTextures[i],
               gRenderer.deferred.gbufferSampler,
               gRenderer.deferred.gbufferTextureLocations[i], i);
  }

  glDisable(GL_DEPTH_TEST);
  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glDrawArrays(GL_TRIANGLES, 0, 3);

  gRenderer.cam.phi += 20.f * dt;
}

void loadGLTFModel(Model *model, const String *basePath) {
  String filePath = {0};

  if (endsWithCString(basePath, ".glb")) {
    copyString(&filePath, basePath);
  } else {
    copyString(&filePath, basePath);
    appendPathCStr(&filePath, pathBaseName(basePath));
    appendCStr(&filePath, ".gltf");
  }

  cgltf_options options = {0};
  cgltf_data *gltf;
  cgltf_result gltfLoadResult = cgltf_parse_file(&options, filePath.buf, &gltf);
  ASSERT(gltfLoadResult == cgltf_result_success);
  cgltf_load_buffers(&options, gltf, filePath.buf);

  model->numTextures = gltf->textures_count;
  model->textures = MMALLOC_ARRAY_ZEROES(uint32_t, model->numTextures);

  {
    String imageFilePath = {0};
    for (cgltf_size textureIndex = 0; textureIndex < gltf->images_count;
         ++textureIndex) {
      cgltf_image *gltfImage = &gltf->images[textureIndex];
      int w, h, numComponents;
      stbi_uc *data;
      if (gltfImage->buffer_view) {
        data = stbi_load_from_memory(
            (uint8_t *)gltfImage->buffer_view->buffer->data +
                gltfImage->buffer_view->offset,
            gltfImage->buffer_view->size, &w, &h, &numComponents,
            STBI_rgb_alpha);
      } else {
        copyString(&imageFilePath, basePath);
        appendPathCStr(&imageFilePath, gltfImage->uri);

        data = stbi_load(imageFilePath.buf, &w, &h, &numComponents,
                         STBI_rgb_alpha);
      }
      ASSERT(data);

      uint32_t *tex = &model->textures[textureIndex];
      glGenTextures(1, tex);
      glBindTexture(GL_TEXTURE_2D, *tex);
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA,
                   GL_UNSIGNED_BYTE, data);
      glGenerateMipmap(GL_TEXTURE_2D);

      stbi_image_free(data);
    }
    glBindTexture(GL_TEXTURE_2D, 0);
    destroyString(&imageFilePath);
  }

  model->numSamplers = gltf->samplers_count;
  model->samplers = MMALLOC_ARRAY_ZEROES(uint32_t, model->numSamplers);

  for (cgltf_size samplerIndex = 0; samplerIndex < gltf->samplers_count;
       ++samplerIndex) {
    cgltf_sampler *gltfSampler = &gltf->samplers[samplerIndex];

    uint32_t *sampler = &model->samplers[samplerIndex];
    glGenSamplers(1, sampler);
    int32_t magFilter = gltfSampler->mag_filter;
    if (magFilter == 0) {
      magFilter = GL_LINEAR;
    }
    int32_t minFilter = gltfSampler->min_filter;
    if (minFilter == 0) {
      minFilter = GL_NEAREST_MIPMAP_LINEAR;
    }
    glSamplerParameteri(*sampler, GL_TEXTURE_MAG_FILTER, magFilter);
    glSamplerParameteri(*sampler, GL_TEXTURE_MIN_FILTER, minFilter);
    int32_t wrapModeS = gltfSampler->wrap_s;
    if (wrapModeS == 0) {
      wrapModeS = GL_REPEAT;
    }
    int32_t wrapModeT = gltfSampler->wrap_t;
    if (wrapModeT == 0) {
      wrapModeT = GL_REPEAT;
    }
    glSamplerParameteri(*sampler, GL_TEXTURE_WRAP_S, wrapModeS);
    glSamplerParameteri(*sampler, GL_TEXTURE_WRAP_T, wrapModeT);
    glSamplerParameteri(*sampler, GL_TEXTURE_WRAP_R, GL_REPEAT);
  }

  model->numMaterials = gltf->materials_count;
  model->materials = MMALLOC_ARRAY_ZEROES(Material, model->numMaterials);
  for (cgltf_size materialIndex = 0; materialIndex < gltf->materials_count;
       ++materialIndex) {
    cgltf_material *gltfMaterial = &gltf->materials[materialIndex];
    Material *material = &model->materials[materialIndex];
    ASSERT(gltfMaterial->has_pbr_metallic_roughness);

    cgltf_pbr_metallic_roughness *pbrMR = &gltfMaterial->pbr_metallic_roughness;

    memcpy(&material->baseColorFactor, pbrMR->base_color_factor,
           sizeof(Float4));

    if (pbrMR->base_color_texture.texture) {
      material->baseColorTexture = gltfMaterial->pbr_metallic_roughness
                                       .base_color_texture.texture->image -
                                   gltf->images;

      if (pbrMR->base_color_texture.texture->sampler) {
        material->baseColorSampler = gltfMaterial->pbr_metallic_roughness
                                         .base_color_texture.texture->sampler -
                                     gltf->samplers;
      } else {
        material->baseColorSampler = -1;
      }
    } else {
      material->baseColorTexture = -1;
      material->baseColorSampler = -1;
    }
  }

  model->numMeshes = gltf->meshes_count;
  model->meshes = MMALLOC_ARRAY_ZEROES(Mesh, model->numMeshes);

  int vertexBufferSize = 0;
  int indexBufferSize = 0;

  for (cgltf_size meshIndex = 0; meshIndex < gltf->meshes_count; ++meshIndex) {
    cgltf_mesh *gltfMesh = &gltf->meshes[meshIndex];
    Mesh *mesh = &model->meshes[meshIndex];

    mesh->numSubMeshes = gltfMesh->primitives_count;
    mesh->subMeshes = MMALLOC_ARRAY_ZEROES(SubMesh, mesh->numSubMeshes);

    for (cgltf_size primIndex = 0; primIndex < gltfMesh->primitives_count;
         ++primIndex) {
      cgltf_primitive *prim = &gltfMesh->primitives[primIndex];
      SubMesh *subMesh = &mesh->subMeshes[primIndex];

      subMesh->numIndices = prim->indices->count;
      subMesh->indices = MMALLOC_ARRAY(VertexIndex, subMesh->numIndices);
      VertexIndex maxIndex = 0;
      for (cgltf_size i = 0; i < prim->indices->count; ++i) {
        subMesh->indices[i] = cgltf_accessor_read_index(prim->indices, i);
        if (maxIndex < subMesh->indices[i]) {
          maxIndex = subMesh->indices[i];
        }
      }

      subMesh->numVertices = maxIndex + 1;
      subMesh->vertices = MMALLOC_ARRAY_ZEROES(Vertex, subMesh->numVertices);
      for (int i = 0; i < subMesh->numVertices; ++i) {
        subMesh->vertices[i].color = (Float4){1, 1, 1, 1};
      }
      for (cgltf_size attribIndex = 0; attribIndex < prim->attributes_count;
           ++attribIndex) {
        cgltf_attribute *attrib = &prim->attributes[attribIndex];
        ASSERT(!attrib->data->is_sparse); // Sparse is not supported yet;
        switch (attrib->type) {
        case cgltf_attribute_type_position:
          for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
               ++vertexIndex) {
            cgltf_size numComponents = cgltf_num_components(attrib->data->type);
            cgltf_bool readResult = cgltf_accessor_read_float(
                attrib->data, vertexIndex,
                (float *)&subMesh->vertices[vertexIndex].position,
                numComponents);
            ASSERT(readResult);
          }
          break;
        case cgltf_attribute_type_texcoord:
          for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
               ++vertexIndex) {
            cgltf_size numComponents = cgltf_num_components(attrib->data->type);
            cgltf_bool readResult = cgltf_accessor_read_float(
                attrib->data, vertexIndex,
                (float *)&subMesh->vertices[vertexIndex].texcoord,
                numComponents);
            ASSERT(readResult);
          }
          break;
        case cgltf_attribute_type_color:
          for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
               ++vertexIndex) {
            cgltf_size numComponents = cgltf_num_components(attrib->data->type);
            cgltf_bool readResult = cgltf_accessor_read_float(
                attrib->data, vertexIndex,
                (float *)&subMesh->vertices[vertexIndex].color, numComponents);
            ASSERT(readResult);
          }
          break;
        case cgltf_attribute_type_normal:
          for (cgltf_size vertexIndex = 0; vertexIndex < attrib->data->count;
               ++vertexIndex) {
            cgltf_size numComponents = cgltf_num_components(attrib->data->type);
            cgltf_bool readResult = cgltf_accessor_read_float(
                attrib->data, vertexIndex,
                (float *)&subMesh->vertices[vertexIndex].normal, numComponents);
            ASSERT(readResult);
          }
          break;
        default:
          break;
        }
      }
      vertexBufferSize += subMesh->numVertices * sizeof(Vertex);
      indexBufferSize += subMesh->numIndices * sizeof(VertexIndex);

      subMesh->material = prim->material - gltf->materials;
    }
  }

  uint32_t *vb = &model->gpuVertexBuffer;
  uint32_t *ib = &model->gpuIndexBuffer;
  glGenBuffers(1, vb);
  glBindBuffer(GL_ARRAY_BUFFER, *vb);
  glBufferData(GL_ARRAY_BUFFER, vertexBufferSize, NULL, GL_STATIC_DRAW);
  glGenBuffers(1, ib);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, *ib);
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexBufferSize, NULL, GL_STATIC_DRAW);

  int vertexOffsetInBytes = 0;
  int indexOffsetInBytes = 0;

  for (int meshIndex = 0; meshIndex < model->numMeshes; ++meshIndex) {
    Mesh *mesh = &model->meshes[meshIndex];
    for (int subMeshIndex = 0; subMeshIndex < mesh->numSubMeshes;
         ++subMeshIndex) {
      SubMesh *subMesh = &mesh->subMeshes[subMeshIndex];
      glBufferSubData(GL_ARRAY_BUFFER, vertexOffsetInBytes,
                      subMesh->numVertices * sizeof(Vertex), subMesh->vertices);
      glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, indexOffsetInBytes,
                      subMesh->numIndices * sizeof(VertexIndex),
                      subMesh->indices);
      subMesh->gpuVertexBufferOffsetInBytes = vertexOffsetInBytes;
      subMesh->gpuIndexBufferOffsetInBytes = indexOffsetInBytes;
      vertexOffsetInBytes += subMesh->numVertices * sizeof(Vertex);
      indexOffsetInBytes += subMesh->numIndices * sizeof(VertexIndex);
    }
  }

  glBindBuffer(GL_ARRAY_BUFFER, 0);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

  model->numNodes = gltf->nodes_count;
  model->nodes = MMALLOC_ARRAY_ZEROES(SceneNode, model->numNodes);
  for (cgltf_size nodeIndex = 0; nodeIndex < gltf->nodes_count; ++nodeIndex) {
    cgltf_node *gltfNode = &gltf->nodes[nodeIndex];
    SceneNode *node = &model->nodes[nodeIndex];

    cgltf_node_transform_local(gltfNode,
                               (float *)node->localTransform.matrix.cols);
    cgltf_node_transform_world(gltfNode,
                               (float *)node->worldTransform.matrix.cols);

    if (gltfNode->parent) {
      node->parent = gltfNode->parent - gltf->nodes;
    } else {
      node->parent = -1;
    }

    if (gltfNode->mesh) {
      node->mesh = gltfNode->mesh - gltf->meshes;
    } else {
      node->mesh = -1;
    }

    if (gltfNode->children_count > 0) {
      node->numChildNodes = gltfNode->children_count;
      node->childNodes = MMALLOC_ARRAY(int, node->numChildNodes);
      for (cgltf_size childIndex = 0; childIndex < gltfNode->children_count;
           ++childIndex) {
        node->childNodes[childIndex] =
            gltfNode->children[childIndex] - gltf->nodes;
      }
    }
  }

  model->numScenes = gltf->scenes_count;
  model->scenes = MMALLOC_ARRAY_ZEROES(Scene, model->numScenes);

  for (cgltf_size sceneIndex = 0; sceneIndex < gltf->scenes_count;
       ++sceneIndex) {
    cgltf_scene *gltfScene = &gltf->scenes[sceneIndex];
    Scene *scene = &model->scenes[sceneIndex];

    if (gltfScene->nodes_count > 0) {
      scene->numNodes = gltfScene->nodes_count;
      scene->nodes = MMALLOC_ARRAY(int, scene->numNodes);

      for (cgltf_size nodeIndex = 0; nodeIndex < gltfScene->nodes_count;
           ++nodeIndex) {
        cgltf_node *gltfNode = gltfScene->nodes[nodeIndex];
        scene->nodes[nodeIndex] = gltfNode - gltf->nodes;
      }
    }
  }

  cgltf_free(gltf);

  destroyString(&filePath);
}

void destroyModel(Model *model) {
  glDeleteBuffers(1, &model->gpuIndexBuffer);
  glDeleteBuffers(1, &model->gpuVertexBuffer);

  for (int i = 0; i < model->numScenes; ++i) {
    MFREE(model->scenes[i].nodes);
  }
  MFREE(model->scenes);

  for (int i = 0; i < model->numNodes; ++i) {
    MFREE(model->nodes[i].childNodes);
  }
  MFREE(model->nodes);

  for (int i = 0; i < model->numMeshes; ++i) {
    for (int j = 0; j < model->meshes[i].numSubMeshes; ++j) {
      MFREE(model->meshes[i].subMeshes[j].vertices);
      MFREE(model->meshes[i].subMeshes[j].indices);
    }
    MFREE(model->meshes[i].subMeshes);
  }
  MFREE(model->meshes);

  MFREE(model->materials);

  for (int i = 0; i < model->numSamplers; ++i) {
    glDeleteSamplers(1, &model->samplers[i]);
  }
  MFREE(model->samplers);

  for (int i = 0; i < model->numTextures; ++i) {
    glDeleteTextures(1, &model->textures[i]);
  }
  MFREE(model->textures);

  *model = (Model){0};
}

static void renderMesh(const Model *model, const Mesh *mesh) {
  for (int subMeshIndex = 0; subMeshIndex < mesh->numSubMeshes;
       ++subMeshIndex) {
    SubMesh *subMesh = &mesh->subMeshes[subMeshIndex];

    Material *material = &model->materials[subMesh->material];

    MaterialUniforms uniforms = {.baseColorFactor = material->baseColorFactor};
    glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.materialUniformBuffer);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(uniforms), &uniforms);

    glDrawElementsBaseVertex(
        GL_TRIANGLES, subMesh->numIndices, GL_UNSIGNED_INT,
        (void *)(uintptr_t)subMesh->gpuIndexBufferOffsetInBytes,
        subMesh->gpuVertexBufferOffsetInBytes / sizeof(Vertex));
  }
}

static void renderSceneNode(const Model *model, const SceneNode *node,
                            Mat4 baseTransform) {
  if (node->mesh >= 0) {
    DrawUniforms uniform;
    uniform.modelMat = mat4Multiply(node->worldTransform.matrix, baseTransform);
    uniform.normalMat = mat4Transpose(mat4Inverse(uniform.modelMat));

    glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.drawUniformBuffer);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(uniform), &uniform);

    Mesh *mesh = &model->meshes[node->mesh];
    renderMesh(model, mesh);
  }

  if (node->numChildNodes > 0) {
    for (int i = 0; i < node->numChildNodes; ++i) {
      SceneNode *childNode = &model->nodes[node->childNodes[i]];
      renderSceneNode(model, childNode, baseTransform);
    }
  }
}

void renderModel(Model *model, Mat4 transform) {
  glBindBuffer(GL_ARRAY_BUFFER, model->gpuVertexBuffer);
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, model->gpuIndexBuffer);

  glEnableVertexAttribArray(0);
  glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                        (void *)offsetof(Vertex, position));
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                        (void *)offsetof(Vertex, color));
  glEnableVertexAttribArray(2);
  glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                        (void *)offsetof(Vertex, texcoord));
  glEnableVertexAttribArray(3);
  glVertexAttribPointer(3, 4, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                        (void *)offsetof(Vertex, normal));

  glBindBufferRange(GL_UNIFORM_BUFFER, VIEW_BINDING,
                    gRenderer.viewUniformBuffer, 0, sizeof(ViewUniforms));
  glBindBufferRange(GL_UNIFORM_BUFFER, MATERIAL_BINDING,
                    gRenderer.materialUniformBuffer, 0,
                    sizeof(MaterialUniforms));
  glBindBufferRange(GL_UNIFORM_BUFFER, DRAW_BINDING,
                    gRenderer.drawUniformBuffer, 0, sizeof(DrawUniforms));

  for (int sceneIndex = 0; sceneIndex < model->numScenes; ++sceneIndex) {
    Scene *scene = &model->scenes[sceneIndex];
    for (int nodeIndex = 0; nodeIndex < scene->numNodes; ++nodeIndex) {
      SceneNode *node = &model->nodes[scene->nodes[nodeIndex]];
      renderSceneNode(model, node, transform);
    }
  }
}

static uint32_t createShader(uint32_t shaderType, const char *shaderFilePath) {
  LOG("Compiling %s", shaderFilePath);

  String resourcePath = createResourcePath(ResourceType_Shader, shaderFilePath);
  uint32_t shader = glCreateShader(shaderType);

  int length;
  void *source = readFileData(&resourcePath, true, &length);

  const char *sources[] = {(char *)source};
  int lengths[] = {(int)length};
  glShaderSource(shader, 1, sources, lengths);
  glCompileShader(shader);
  int compileResult = 0;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &compileResult);
  if (compileResult != GL_TRUE) {
    static char errorLog[512];
    int errorLogLength;
    glGetShaderInfoLog(shader, sizeof(errorLog), &errorLogLength, errorLog);
    LOG("Compile Error: %s", errorLog);
  }
  ASSERT(compileResult == GL_TRUE);

  destroyFileData(source);

  destroyString(&resourcePath);

  return shader;
}

static uint32_t createShaderProgram(const char *vertexShaderFilePath,
                                    const char *fragmentShaderFilePath) {
  uint32_t vertexShader = createShader(GL_VERTEX_SHADER, vertexShaderFilePath);
  uint32_t fragmentShader =
      createShader(GL_FRAGMENT_SHADER, fragmentShaderFilePath);

  uint32_t program = glCreateProgram();
  glAttachShader(program, vertexShader);
  glAttachShader(program, fragmentShader);
  glLinkProgram(program);
  int linkResult = 0;
  glGetProgramiv(program, GL_LINK_STATUS, &linkResult);
  if (linkResult != GL_TRUE) {
    static char errorLog[512];
    int errorLogLength;
    glGetProgramInfoLog(program, sizeof(errorLog), &errorLogLength, errorLog);
    LOG("Link Error: %s", errorLog);
  }
  ASSERT(linkResult == GL_TRUE);

  glDetachShader(program, vertexShader);
  glDetachShader(program, fragmentShader);
  glDeleteShader(vertexShader);
  glDeleteShader(fragmentShader);

  return program;
}