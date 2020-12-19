#include <stdlib.h>

#define MALLOC(type) (type *)allocate(sizeof(type), _Alignof(type))
#define MALLOC_ARRAY(type, count)                                              \
  (type *)allocate(sizeof(type) * count, _Alignof(type))
#define FREE(p) deallocate(p)

static void *allocate(int size, int alignment) {
  return aligned_alloc(alignment, size);
}
static void deallocate(void *memory) { free(memory); }