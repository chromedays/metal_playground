#include "../renderer.h"

Mat4 getOrbitCameraMatrix(const OrbitCamera *cam) {
  Float3 camPos = sphericalToCartesian(cam->distance, degToRad(cam->theta),
                                       degToRad(cam->phi));
  Mat4 lookAt = mat4LookAt(camPos, (Float3){0}, (Float3){0, 1, 0});
  return lookAt;
}