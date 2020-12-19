#include "util.h"
#include <stdlib.h>

#define MALLOC(type) (type *)allocate(sizeof(type), _Alignof(type))
#define MALLOC_ARRAY(type, count)                                              \
  (type *)allocate(sizeof(type) * count, _Alignof(type))
#define FREE(p) deallocate(p)

C_INTERFACE_BEGIN

static void *allocate(int size, int alignment) {
  return aligned_alloc(alignment, size);
}
static void deallocate(void *memory) { free(memory); }

C_INTERFACE_END