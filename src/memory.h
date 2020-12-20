#include "util.h"

#define MALLOC(type) (type *)allocate(sizeof(type), _Alignof(type))
#define MALLOC_ZEROES(type) (type *)allocateZeroes(sizeof(type), _Alignof(type))
#define MALLOC_ARRAY(type, count)                                              \
  (type *)allocate(sizeof(type) * count, _Alignof(type))
#define MALLOC_ARRAY_ZEROES(type, count)                                       \
  (type *)allocateZeroes(sizeof(type) * count, _Alignof(type))
#define FREE(p) deallocate(p)

C_INTERFACE_BEGIN

void *allocate(int size, int alignment);
void *allocateZeroes(int size, int alignment);
void deallocate(void *memory);

C_INTERFACE_END