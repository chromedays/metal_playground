#pragma once
#ifdef DEBUG
#include <assert.h>
#include <stdio.h>
#endif

#ifdef __cplusplus
#define C_INTERFACE_BEGIN extern "C" {
#define C_INTERFACE_END }
#else
#define C_INTERFACE_BEGIN
#define C_INTERFACE_END
#endif

#ifdef DEBUG
#define ASSERT(condition) assert(condition)
#else
#define ASSERT(condition)
#endif

#ifdef DEBUG
#define LOG(...)                                                               \
  do {                                                                         \
    printf(__VA_ARGS__);                                                       \
    printf("\n");                                                              \
  } while (0)
#else
#define LOG(...)
#endif
