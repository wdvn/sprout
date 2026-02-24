# Project Plan: 2.5D HD Pixel Art Forest with NVRHI

## 1. Project Goal

The primary goal of this project is to create a visually appealing 2.5D HD pixel art forest environment. The rendering backend will exclusively utilize NVIDIA's NVRHI library, ensuring high performance and cross-platform compatibility (Linux and Windows). The project will serve as a practical demonstration of integrating NVRHI with Zig for graphics development.

## 2. Core Technologies

*   **Programming Languages**: Zig (for application logic and FFI), C++ (for NVRHI integration and low-level rendering).
*   **Graphics API Abstraction**: NVRHI (NVIDIA Rendering Hardware Interface).
*   **Windowing & Input**: RGFW (Raylib Game Framework Wrapper) for cross-platform window creation and input handling.
*   **Graphics Backends**: Vulkan (primary for Linux/Windows), potentially DirectX 12 (for Windows-specific optimization/testing).
*   **Shader Language**: GLSL/HLSL compiled to SPIR-V.
*   **Asset Creation**: Pixel art tools (e.g., Aseprite, Photoshop).

## 3. Project Phases

### Phase 1: Setup & Basic Rendering (Current State & Refinement)

*   **Objective**: Establish a stable build environment and render a basic NVRHI scene.
*   **Tasks**:
    *   **Build System Configuration**:
        *   Ensure `build.zig` correctly handles NVRHI, RGFW, and C++ compilation.
        *   Verify include paths and library linking for all dependencies.
        *   Confirm cross-compilation capabilities for Linux and Windows targets.
    *   **NVRHI Integration**:
        *   Refine `src/nvrhi_impl.h` and `src/nvrhi_impl.cpp` for a robust C-style interface.
        *   Implement NVRHI device, swapchain, command list, and basic pipeline creation.
        *   **Shader Management**: Implement a system for loading pre-compiled SPIR-V shaders (e.g., `@embedFile` in Zig, passed to C++).
        *   **Basic Triangle Rendering**: Successfully render a colored triangle using NVRHI.
    *   **Windowing & Input**:
        *   Initialize RGFW window and handle basic events (close, resize).
        *   Integrate RGFW window handle with NVRHI for surface creation.

### Phase 2: Asset Pipeline & 2.5D Rendering

*   **Objective**: Develop an asset pipeline for pixel art and implement 2.5D rendering techniques.
*   **Tasks**:
    *   **Pixel Art Asset Creation**:
        *   Define pixel art style guide (resolution, color palette, perspective).
        *   Create initial forest assets: background layers (sky, distant trees), mid-ground elements (trees, bushes), foreground elements (foliage, rocks).
        *   Design spritesheets for efficient texture loading.
    *   **Asset Loading**:
        *   Implement image loading (e.g., PNG) and texture creation using NVRHI.
        *   Develop a system to parse sprite definitions from metadata (e.g., JSON files).
    *   **2.5D Rendering Implementation**:
        *   **Layered Parallax Scrolling**: Render multiple background layers with different scroll speeds to create depth.
        *   **Billboard Sprites**: Render trees and other objects as 2D sprites always facing the camera, but with depth information.
        *   **Depth Sorting**: Implement a simple depth sorting mechanism for sprites to ensure correct rendering order.
        *   **Camera System**: Implement a 2D camera that can pan and zoom, respecting the 2.5D perspective.
    *   **Shader Development**:
        *   Write shaders for sprite rendering (texture sampling, color tinting).
        *   Consider shaders for simple lighting effects on sprites.

### Phase 3: Scene Management & Interactivity

*   **Objective**: Structure the forest environment and allow for basic user interaction.
*   **Tasks**:
    *   **Scene Graph/ECS**:
        *   Design a simple scene graph or Entity-Component-System (ECS) to manage forest elements.
        *   Define components for position, sprite, parallax layer, etc.
    *   **Basic Interaction**:
        *   Implement a simple "player" entity (e.g., a cursor or character sprite).
        *   Allow basic movement within the forest scene (e.g., horizontal scrolling).
    *   **Simple Lighting**:
        *   Introduce basic ambient lighting.
        *   Potentially add a simple directional light source (e.g., sun) affecting sprite colors.

### Phase 4: Optimization & Polish

*   **Objective**: Improve performance, ensure cross-platform stability, and refine visual quality.
*   **Tasks**:
    *   **Performance Profiling**:
        *   Use NVRHI's debugging tools and system profilers to identify bottlenecks.
        *   Optimize draw calls, texture uploads, and shader performance.
    *   **Cross-Platform Testing**:
        *   Thoroughly test on both Linux and Windows environments.
        *   Address any platform-specific rendering or input issues.
    *   **Visual Enhancements**:
        *   Implement post-processing effects (e.g., bloom, color grading) if performance allows.
        *   Add particle effects (e.g., falling leaves, dust motes).
    *   **Build & Deployment**:
        *   Automate build process for release binaries.
        *   Create deployment packages for target platforms.

## 4. Technical Details/Considerations

*   **NVRHI Backend Abstraction**: While NVRHI abstracts Vulkan/DX12, ensure the C++ wrapper correctly initializes the desired backend based on the platform. Focus on Vulkan first for cross-platform.
*   **Shader Compilation**: Use `glslang` or `shaderc` to pre-compile GLSL/HLSL to SPIR-V during the build process, or provide pre-compiled binaries.
*   **Memory Management**: Leverage Zig's powerful allocator system for efficient memory handling, especially for assets and NVRHI resources.
*   **2.5D Depth**: Carefully manage the Z-coordinate for different layers and sprites to maintain the 2.5D illusion.
*   **Coordinate Systems**: Define consistent coordinate systems for world space, screen space, and texture space.

## 5. Milestones

*   **Milestone 1**: NVRHI triangle rendering working on Linux/Windows. (Achieved basic setup)
*   **Milestone 2**: Basic pixel art asset loading and display (single sprite).
*   **Milestone 3**: Layered parallax background rendering.
*   **Milestone 4**: Interactive camera and player movement within the forest.
*   **Milestone 5**: Optimized and polished forest environment running smoothly on both platforms.

## 6. Tools

*   **IDE**: Android Studio (or other preferred IDE for Zig/C++).
*   **Version Control**: Git.
*   **Pixel Art**: Aseprite, Photoshop, GIMP.
*   **Shader Compilation**: `glslangValidator` or `shaderc`.
*   **Debugging**: RenderDoc (for Vulkan debugging), NVRHI's built-in debug layers.
*   **Profiling**: `perf` (Linux), Visual Studio Profiler (Windows).
