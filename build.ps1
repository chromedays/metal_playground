$shaderFiles = Get-ChildItem "./src/shaders" -Filter *.hlsl
$shaderFiles | ForEach-Object {
    $shaderName = $_.BaseName
    echo "Compiling $($_.FullName)..."
    & ./tools/dxc.exe -nologo -spirv -T vs_6_5 -E "${shaderName}_vert" -Fo "./tmp/${shaderName}_vert.spv" "$($_.FullName)"
    & ./tools/dxc.exe -nologo -spirv -T ps_6_5 -E "${shaderName}_frag" -Fo "./tmp/${shaderName}_frag.spv" "$($_.FullName)"
    & ./tools/spirv-cross.exe --msl --msl-version 20100 "./tmp/${shaderName}_vert.spv" --output "./src/shaders/generated/msl/${shaderName}_vert.metal"
    & ./tools/spirv-cross.exe --msl --msl-version 20100 "./tmp/${shaderName}_frag.spv" --output "./src/shaders/generated/msl/${shaderName}_frag.metal"
    & ./tools/spirv-cross.exe --hlsl --shader-model 50 "./tmp/${shaderName}_vert.spv" --output "./src/shaders/generated/hlsl50/${shaderName}_vert.hlsl"
    & ./tools/spirv-cross.exe --hlsl --shader-model 50 "./tmp/${shaderName}_frag.spv" --output "./src/shaders/generated/hlsl50/${shaderName}_frag.hlsl"
    & ./tools/spirv-cross.exe --no-es --version 330 --no-420pack-extension --rename-interface-variable out 0 VertexOut0 --rename-interface-variable out 1 VertexOut1 --rename-interface-variable out 2 VertexOut2 --rename-interface-variable out 3 VertexOut3 "./tmp/${shaderName}_vert.spv" --output "./src/shaders/generated/glsl330/${shaderName}_vert.glsl"
    & ./tools/spirv-cross.exe --no-es --version 330 --no-420pack-extension --rename-interface-variable in 0 VertexOut0 --rename-interface-variable in 1 VertexOut1 --rename-interface-variable in 2 VertexOut2 --rename-interface-variable in 3 VertexOut3 "./tmp/${shaderName}_frag.spv" --output "./src/shaders/generated/glsl330/${shaderName}_frag.glsl"
    & ./tools/spirv-cross.exe "./tmp/${shaderName}_vert.spv" --reflect --output "./tmp/${shaderName}_vert.json"
    & ./tools/spirv-cross.exe "./tmp/${shaderName}_frag.spv" --reflect --output "./tmp/${shaderName}_frag.json"
}

$target = "Exe-playground_gl33"

./FBuild.exe $target
./FBuild.exe $target -compdb