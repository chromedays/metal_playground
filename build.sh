#!/bin/sh

if [ -d bin ]
then
trash bin
fi
mkdir bin
pushd bin
# CLANG="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
CLANG="clang"
OUTPUT="playground"
COMPILE_COMMAND="${CLANG} -g -std=c11 -o ${OUTPUT} ../src/main.m -framework AppKit -framework MetalKit -framework Metal -fobjc-arc -fdiagnostics-absolute-paths --target=arm64-apple-macos11"
CLANGD_COMMAND="${COMPILE_COMMAND} -MJ ../compile_commands.json"

eval "$COMPILE_COMMAND"
eval "$CLANGD_COMMAND"

xcrun -sdk macosx metal -c -gline-tables-only -MO ../src/shaders.metal -o shaders.air
xcrun -sdk macosx metallib shaders.air -o shaders.metallib
trash shaders.air

if [ -d "${OUTPUT}.app" ]
then
rm -rf "${OUTPUT}.app"
fi
mkdir "${OUTPUT}.app"
# ls -a
cp "${OUTPUT}" "${OUTPUT}.app/${OUTPUT}"
cp ../resources/Info.plist "${OUTPUT}.app/Info.plist"

trash "${OUTPUT}"

popd