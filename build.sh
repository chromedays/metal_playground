#!/bin/sh

if [ ! -d bin ]
then
mkdir bin
fi
pushd bin
COMPILE_COMMAND="clang -g -o cs562 ../src/main.m -framework AppKit -fobjc-arc -fdiagnostics-absolute-paths"
CLANGD_COMMAND="${COMPILE_COMMAND} -MJ ../compile_commands.json"
eval "$COMPILE_COMMAND"
eval "$CLANGD_COMMAND"
popd