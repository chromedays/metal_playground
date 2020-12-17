#!/bin/sh

if [ ! -d bin ]
then
mkdir bin
fi
pushd bin
OUTPUT="playground"
COMPILE_COMMAND="clang -g -o ${OUTPUT} ../src/main.m -framework AppKit -fobjc-arc -fdiagnostics-absolute-paths"
CLANGD_COMMAND="${COMPILE_COMMAND} -MJ ../compile_commands.json"
eval "$COMPILE_COMMAND"
eval "$CLANGD_COMMAND"
popd