#pragma once
#include <stdbool.h>

typedef struct _String {
  int len;
  int cap;
  char *buf;
} String;

void destroyString(String *str);
bool compareString(const String *a, const String *b);
void appendCStr(String *str, const char *toAppend);
void appendString(String *str, const String *toAppend);
void copyStringFromCStr(String *dst, const char *src);
void copyString(String *dst, const String *src);

void appendPathCStr(String* str, const char* path);
const char* pathBaseName(const String* str);

bool endsWithCString(const String* str, const char* ch);