#!/bin/sh

if [ ! -d bin ]
then
mkdir bin
fi
pushd bin
# CLANG="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
CLANG="clang"
OUTPUT="playground"
COMPILE_COMMAND="${CLANG} -g -o ${OUTPUT} ../src/main.m -framework AppKit -fobjc-arc -fdiagnostics-absolute-paths --target=arm64-apple-macos11"
CLANGD_COMMAND="${COMPILE_COMMAND} -MJ ../compile_commands.json"
eval "$COMPILE_COMMAND"
eval "$CLANGD_COMMAND"
popd