#include "str.h"
#include "memory.h"
#include <string.h>
#include <stdlib.h>

#define STR_DEFAULT_CAP 64

void destroyString(String *str) {
  free(str->buf);
  *str = (String){0};
}

bool compareString(const String *a, const String *b) {
  bool result = false;

  if (a->len == b->len) {
    result = (memcmp(a->buf, b->buf, a->len * sizeof(char)) == 0);
  }

  return result;
}

static void tryExpand(String *str, int newLen) {
  if (str->cap < newLen + 1) {
    int newCap = MAX(str->cap, 1);
    do {
      newCap <<= 2;
    } while (newCap < (newLen + 1));

    char *oldBuf = str->buf;
    int oldCap = str->cap;
    str->cap = newCap;
    str->buf = MALLOC_ARRAY(char, str->cap);
    memcpy(str->buf, oldBuf, oldCap);
    free(oldBuf);
  }
}

void appendCStr(String *str, const char *toAppend) {
  int offset = str->len;
  int appendLen = (int)strlen(toAppend);
  int newLen = str->len + appendLen;
  tryExpand(str, newLen);
  str->len = newLen;

  memcpy(str->buf + offset, toAppend, appendLen);
  str->buf[str->len] = 0;
}

void appendString(String *str, const String *toAppend) {
  int offset = str->len;
  int appendLen = toAppend->len;
  int newLen = str->len + appendLen;
  tryExpand(str, newLen);
  str->len = newLen;

  memcpy(str->buf + offset, toAppend->buf, appendLen);
  str->buf[str->len] = 0;
}

void copyStringFromCStr(String *dst, const char *src) {
  int srcLen = (int)strlen(src);
  tryExpand(dst, srcLen);
  memcpy(dst->buf, src, srcLen);
  dst->buf[srcLen] = 0;
  dst->len = srcLen;
}

void copyString(String *dst, const String *src) {
  tryExpand(dst, src->len);
  memcpy(dst->buf, src->buf, src->len);
  dst->buf[src->len] = 0;
  dst->len = src->len;
}