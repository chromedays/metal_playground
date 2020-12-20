#pragma once
#ifdef DEBUG
#include <assert.h>
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
#define LOG(format, ...) printf(format "\n", __VA_ARGS__)
#else
#define LOG(format, ...)
#endif
