#!/bin/sh

if [ -d bin ]
then
trash bin
fi
mkdir bin

# ./FBuild Exe-playground-Unity -clean -verbose -showcmds
./FBuild Exe-playground-Unity
./FBuild Exe-playground -compdb

pushd bin
# CLANG="clang"
OUTPUT="playground"
# COMPILE_COMMAND="${CLANG} -g -c -std=c11 -o main.o ../src/main.m  -fobjc-arc -fdiagnostics-absolute-paths --target=arm64-apple-macos11"
# LINK_COMMAND="${CLANG} -g main.o -o ${OUTPUT} -framework AppKit -framework MetalKit -framework Metal"
# CLANGD_COMMAND="${COMPILE_COMMAND} -MJ ../compile_commands.json"

# eval "$COMPILE_COMMAND"
# eval "$LINK_COMMAND"
# eval "$CLANGD_COMMAND"
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