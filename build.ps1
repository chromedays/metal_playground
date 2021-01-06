$shaderFiles = Get-ChildItem "./src/shaders" -Filter *.hlsl
$shaderFiles | ForEach-Object {
    $shaderName = $_.BaseName
    echo "Compiling $($_.FullName)..."
    & ./dxc.exe -nologo -spirv -T vs_6_5 -E "${shaderName}_vert" -Fo "./tmp/${shaderName}_vert.spv" "$($_.FullName)"
    & ./dxc.exe -nologo -spirv -T ps_6_5 -E "${shaderName}_frag" -Fo "./tmp/${shaderName}_frag.spv" "$($_.FullName)"
    & ./spirv-cross.exe --msl --msl-version 20100 "./tmp/${shaderName}_vert.spv" --output "./src/shaders/generated/msl/${shaderName}_vert.metal"
    & ./spirv-cross.exe --msl --msl-version 20100 "./tmp/${shaderName}_frag.spv" --output "./src/shaders/generated/msl/${shaderName}_frag.metal"
    & ./spirv-cross.exe --hlsl --shader-model 50 "./tmp/${shaderName}_vert.spv" --output "./src/shaders/generated/hlsl50/${shaderName}_vert.hlsl"
    & ./spirv-cross.exe --hlsl --shader-model 50 "./tmp/${shaderName}_frag.spv" --output "./src/shaders/generated/hlsl50/${shaderName}_frag.hlsl"
    & ./spirv-cross.exe --no-es --version 330 --no-420pack-extension "./tmp/${shaderName}_vert.spv" --output "./src/shaders/generated/glsl330/${shaderName}_vert.glsl"
    & ./spirv-cross.exe --no-es --version 330 --no-420pack-extension "./tmp/${shaderName}_frag.spv" --output "./src/shaders/generated/glsl330/${shaderName}_frag.glsl"
    & ./spirv-cross.exe "./tmp/${shaderName}_vert.spv" --reflect --output "./tmp/${shaderName}_vert.json"
    & ./spirv-cross.exe "./tmp/${shaderName}_frag.spv" --reflect --output "./tmp/${shaderName}_frag.json"
}

./FBuild.exe Exe-playground