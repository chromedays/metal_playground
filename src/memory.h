#include "util.h"

#define MMALLOC(type) (type *)allocate(sizeof(type), (int)_Alignof(type))
#define MMALLOC_ZEROES(type)                                                   \
  (type *)allocateZeroes(sizeof(type), (int)_Alignof(type))
#define MMALLOC_ARRAY(type, count)                                             \
  (type *)allocate(sizeof(type) * count, (int)_Alignof(type))
#define MMALLOC_ARRAY_ZEROES(type, count)                                      \
  (type *)allocateZeroes(sizeof(type) * count, (int)_Alignof(type))
#define MFREE(p) deallocate(p)

C_INTERFACE_BEGIN

void *allocate(int size, int alignment);
void *allocateZeroes(int size, int alignment);
void deallocate(void *memory);

C_INTERFACE_END