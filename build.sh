#!/bin/sh

if [[ $1 == "clean" ]]
then
echo "Performing clean build..."
fi

if [[ $1 == "clean" ]] && [ -d tmp ]
then
trash tmp
fi

if [ -d bin ]
then
trash bin
fi
mkdir bin

# ./FBuild Exe-playground-Unity -clean -verbose -showcmds
if [[ $1 == "clean" ]]
then
./FBuild Exe-playground -clean
else
./FBuild Exe-playground
fi
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
mkdir "${OUTPUT}.app/Resources"
mv shaders.metallib "${OUTPUT}.app/Resources/shaders.metallib"
# cp -R ../resources/AnimatedCube "${OUTPUT}.app/Resources/AnimatedCube"
# cp -R ../resources/BoxVertexColors "${OUTPUT}.app/Resources/BoxVertexColors"
# cp -R ../resources/Avocado.glb "${OUTPUT}.app/Resources/Avocado.glb"
# cp -R ../resources/CesiumMilkTruck "${OUTPUT}.app/Resources/CesiumMilkTruck"
# cp -R ../resources/EnvironmentTest "${OUTPUT}.app/Resources/EnvironmentTest"
# cp -R ../resources/Sponza.glb "${OUTPUT}.app/Resources/Sponza.glb"
# cp -R ../resources/DamagedHelmet "${OUTPUT}.app/Resources/DamagedHelmet"
# cp -R ../resources/VC "${OUTPUT}.app/Resources/VC"
# cp -R ../resources/MetalRoughSpheres "${OUTPUT}.app/Resources/MetalRoughSpheres"
# cp -R ../resources/MultiUVTest.glb "${OUTPUT}.app/Resources/MultiUVTest.glb"

cp -R ../resources/gltf "${OUTPUT}.app/Resources/gltf"

GLTF_FILE_NAMES=`ls ../resources/gltf`
GLTF_TOML="files=[\n"
for FILE_NAME in $GLTF_FILE_NAMES
do
    GLTF_TOML+="    \"${FILE_NAME}\",\n"
done
GLTF_TOML+="]"
echo ${GLTF_TOML} > "${OUTPUT}.app/Resources/gltf_list.toml"

trash "${OUTPUT}"

popd