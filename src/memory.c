#include "util.h"
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <malloc.h>
#endif

#ifdef __APPLE__
#define MIN_ALIGNMENT 16
#else
#define MIN_ALIGNMENT 1
#endif

static int divideRounded(int n, int d) {
  int result = (n + d - 1) / d;
  return result;
}

static int alignUp(int n, int alignment) {
  int result = divideRounded(n, alignment) * alignment;
  return result;
}

void *allocate(int size, int alignment) {
  if (alignment < MIN_ALIGNMENT) {
    alignment = MIN_ALIGNMENT;
  }
  size = alignUp(size, alignment);
  void *mem =
#ifdef _WIN32
      _aligned_malloc(size, alignment);
#else
      aligned_alloc(alignment, size);
#endif

  return mem;
}

void *allocateZeroes(int size, int alignment) {
  if (alignment < MIN_ALIGNMENT) {
    alignment = MIN_ALIGNMENT;
  }
  size = alignUp(size, alignment);
  void *mem =
#ifdef _WIN32
      _aligned_malloc(size, alignment);
#else
      aligned_alloc(alignment, size);
#endif
  memset(mem, 0, size);

  return mem;
}

void deallocate(void *memory) {
#ifdef _WIN32
  _aligned_free(memory);
#else
  free(memory);
#endif
}