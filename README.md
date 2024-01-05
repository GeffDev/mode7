# mode7
Typical 2D game engine

## How to use
- If on linux, install SDL2 development libraries
- Include repository as dependency in `build.zig.zon` (or use anonymous dependencies)
- ```zig
    exe.root_module.addImport("mode7", mode7_dep.module("mode7"));
    mode7.link(mode7_dep.builder, exe, optimise, target);

## TODOs
- Implement 3D rendering
- Implement OpenGL and Vulkan backends