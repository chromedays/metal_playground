#include "../renderer.h"

Mat4 getOrbitCameraMatrix(const OrbitCamera *cam) {
  Float3 camPos = sphericalToCartesian(cam->distance, degToRad(cam->theta),
                                       degToRad(cam->phi)) +
                  cam->target;
  Mat4 lookAt = mat4LookAt(camPos, cam->target, (Float3){0, 1, 0});
  return lookAt;
}