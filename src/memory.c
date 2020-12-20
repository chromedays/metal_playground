#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
#define MIN_ALIGNMENT 16
#else
#define MIN_ALIGNMENT 1
#endif

void *allocate(int size, int alignment) {
  if (alignment < MIN_ALIGNMENT) {
    alignment = MIN_ALIGNMENT;
  }
  if (size < alignment) {
    size = alignment;
  }
  void *mem = aligned_alloc(alignment, size);
  return mem;
}

void *allocateZeroes(int size, int alignment) {
  void *mem = allocate(size, alignment);
  memset(mem, 0, size);

  return mem;
}

void deallocate(void *memory) { free(memory); }