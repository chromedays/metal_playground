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

  gRenderer.cam.distance = 10;
  gRenderer.cam.phi = -90;
  gRenderer.cam.theta = 0;

  ViewUniforms tempViewUniforms = {0};
  tempViewUniforms.viewMat = getOrbitCameraMatrix(&gRenderer.cam);
  tempViewUniforms.projMat = mat4Perspective(
      degToRad(60), (float)getApp()->width / (float)getApp()->height, 0.01f,
      1000.f);

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

  String gltfPath =
      createResourcePath(ResourceType_Common, "gltf/AnimatedCube");
  loadGLTFModel(&gRenderer.tempModel, &gltfPath);
  destroyString(&gltfPath);
}

void destroyRenderer(void) {
  glBindVertexArray(0);
  glUseProgram(0);

  glDeleteVertexArrays(1, &gRenderer.vao);
  glDeleteProgram(gRenderer.phong.program);

  gRenderer = (Renderer){0};
}

void render(void) {
  glUseProgram(gRenderer.phong.program);
  glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
  renderModel(&gRenderer.tempModel);
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

static void renderSceneNode(const Model *model, const SceneNode *node) {
  if (node->mesh >= 0) {
    DrawUniforms uniform;
    uniform.modelMat = node->worldTransform.matrix;
    uniform.normalMat = mat4Transpose(mat4Inverse(uniform.modelMat));

    glBindBuffer(GL_UNIFORM_BUFFER, gRenderer.drawUniformBuffer);
    glBufferSubData(GL_UNIFORM_BUFFER, 0, sizeof(uniform), &uniform);

    Mesh *mesh = &model->meshes[node->mesh];
    renderMesh(model, mesh);
  }

  if (node->numChildNodes > 0) {
    for (int i = 0; i < node->numChildNodes; ++i) {
      SceneNode *childNode = &model->nodes[node->childNodes[i]];
      renderSceneNode(model, childNode);
    }
  }
}

void renderModel(Model *model) {
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
      renderSceneNode(model, node);
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