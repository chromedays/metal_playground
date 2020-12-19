#include <stdlib.h>

void *allocate(int size, int alignment) {
  return aligned_alloc(alignment, size);
}

void deallocate(void *memory) { free(memory); }