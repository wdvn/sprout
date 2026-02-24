#include "nvrhi_impl.h"
#include <nvrhi/vulkan.h>
#include <nvrhi/utils.h>
#include <vector>

#ifdef _WIN32
#include <Windows.h>
#else
#include <X11/Xlib.h>
#endif

// Simplified RGFW_window struct
typedef struct RGFW_window {
    void* display;
    unsigned long window;
} RGFW_window;

// SPIR-V bytecode for a simple vertex shader (red triangle)
const uint32_t vs_spirv[] = {
    0x07230203,0x00010000,0x00080001,0x0000000d,0x00000000,0x00020011,0x00000001,0x0006000b,
    0x00000001,0x4c534c47,0x3435302e,0x3030302e,0x00000000,0x0003000e,0x00000000,0x00000001,
    0x0007000f,0x00000004,0x00000004,0x6e69616d,0x00000000,0x00000009,0x0000000b,0x00030010,
    0x00000004,0x00000007,0x00040047,0x00000009,0x0000001e,0x00000000,0x00040047,0x0000000b,
    0x00000022,0x00000000,0x00020013,0x00000002,0x00030021,0x00000003,0x00000002,0x00030016,
    0x00000006,0x00000020,0x00040017,0x00000007,0x00000006,0x00000004,0x00040020,0x00000008,
    0x00000003,0x00000007,0x0004003b,0x00000008,0x00000009,0x00000003,0x00040020,0x0000000a,
    0x00000001,0x00000007,0x0004003b,0x0000000a,0x0000000b,0x00000001,0x0004002b,0x00000006,
    0x0000000c,0x00000000,0x00040020,0x0000000d,0x00000006,0x0000000b,0x00050036,0x00000002,
    0x00000004,0x00000000,0x00000003,0x000200f8,0x00000005,0x0004003d,0x00000007,0x0000000c,
    0x0000000b,0x00050051,0x00000006,0x0000000d,0x0000000b,0x00000000,0x000100fd,0x00010038
};

// SPIR-V bytecode for a simple fragment shader (red triangle)
const uint32_t fs_spirv[] = {
    0x07230203,0x00010000,0x00080001,0x00000007,0x00000000,0x00020011,0x00000001,0x0006000b,
    0x00000001,0x4c534c47,0x3435302e,0x3030302e,0x00000000,0x0003000e,0x00000000,0x00000001,
    0x00030010,0x00000004,0x00000007,0x00040047,0x00000004,0x00000022,0x00000000,0x00020013,
    0x00000002,0x00030021,0x00000003,0x00000002,0x00040017,0x00000005,0x00000002,0x00000004,
    0x00040020,0x00000006,0x00000003,0x00000005,0x00050036,0x00000002,0x00000004,0x00000000,
    0x00000003,0x000200f8,0x00000005,0x00050041,0x00000006,0x00000004,0x00000003,0x00000000,
    0x000100fd,0x00010038
};

struct Vertex {
    float pos[2];
    float color[3];
};

const Vertex vertices[] = {
    { { 0.0f, -0.5f }, { 1.0f, 0.0f, 0.0f } },
    { { 0.5f,  0.5f }, { 0.0f, 1.0f, 0.0f } },
    { { -0.5f, 0.5f }, { 0.0f, 0.0f, 1.0f } },
};

struct NvrhiState {
    nvrhi::DeviceHandle device;
    nvrhi::SwapchainHandle swapchain;
    nvrhi::CommandListHandle commandList;
    nvrhi::GraphicsPipelineHandle pso;
    nvrhi::BufferHandle vertexBuffer;
    nvrhi::ShaderHandle vs;
    nvrhi::ShaderHandle fs;
    nvrhi::InputLayoutHandle inputLayout;
};

NvrhiState* nvrhi_init(void* window) {
    auto state = new NvrhiState();

    nvrhi::vulkan::DeviceDesc deviceDesc;
    nvrhi::utils::DefaultMessageCallback* messageCallback = new nvrhi::utils::DefaultMessageCallback();
    deviceDesc.messageCallback = messageCallback;

#ifdef _WIN32
    deviceDesc.window = (HWND)window; 
#else
    RGFW_window* rgfw_win = (RGFW_window*)window;
    deviceDesc.display = (Display*)rgfw_win->display;
    deviceDesc.window = (Window)rgfw_win->window;
#endif

    state->device = nvrhi::vulkan::createDevice(deviceDesc);
    if (!state->device) {
        delete messageCallback;
        delete state;
        return nullptr;
    }

    nvrhi::SwapchainDesc swapchainDesc;
    swapchainDesc.width = 800;
    swapchainDesc.height = 600;
    swapchainDesc.format = nvrhi::Format::SRGBA8_UNORM;
    
    if (state->device->createSwapchain(swapchainDesc, &state->swapchain) != nvrhi::Result::Success) {
        delete state;
        return nullptr;
    }

    state->commandList = state->device->createCommandList(nvrhi::CommandListType::Graphics);

    nvrhi::ShaderDesc vsDesc(nvrhi::ShaderType::Vertex);
    vsDesc.shaderCode = vs_spirv;
    vsDesc.shaderCodeSize = sizeof(vs_spirv);

    nvrhi::ShaderDesc fsDesc(nvrhi::ShaderType::Fragment);
    fsDesc.shaderCode = fs_spirv;
    fsDesc.shaderCodeSize = sizeof(fs_spirv);

    state->vs = state->device->createShader(vsDesc);
    state->fs = state->device->createShader(fsDesc);

    if (!state->vs || !state->fs) return nullptr;

    nvrhi::VertexAttributeDesc attributes[] = {
        nvrhi::VertexAttributeDesc()
            .setName("POSITION")
            .setFormat(nvrhi::Format::RG32_FLOAT)
            .setOffset(0)
            .setElementStride(sizeof(Vertex))
            .setBufferIndex(0),
        nvrhi::VertexAttributeDesc()
            .setName("COLOR")
            .setFormat(nvrhi::Format::RGB32_FLOAT)
            .setOffset(sizeof(float) * 2)
            .setElementStride(sizeof(Vertex))
            .setBufferIndex(0),
    };

    nvrhi::InputLayoutDesc inputLayoutDesc;
    inputLayoutDesc.attributes = attributes;
    inputLayoutDesc.numAttributes = 2;

    state->inputLayout = state->device->createInputLayout(inputLayoutDesc, state->vs);

    nvrhi::GraphicsPipelineDesc psoDesc;
    psoDesc.VS = state->vs;
    psoDesc.FS = state->fs;
    psoDesc.inputLayout = state->inputLayout;
    psoDesc.renderState.rasterState.cullMode = nvrhi::RasterCullMode::None;
    psoDesc.renderState.depthStencilState.depthTestEnable = false;
    psoDesc.renderState.blendState.targets[0].blendEnable = false;

    state->pso = state->device->createGraphicsPipeline(psoDesc);

    nvrhi::BufferDesc bufferDesc;
    bufferDesc.byteSize = sizeof(vertices);
    bufferDesc.isVertexBuffer = true;
    bufferDesc.initialState = nvrhi::ResourceStates::VertexBuffer;
    bufferDesc.keepInitialState = true;
    bufferDesc.debugName = "VertexBuffer";

    state->vertexBuffer = state->device->createBuffer(bufferDesc);

    state->commandList->open();
    state->commandList->writeBuffer(state->vertexBuffer, vertices, sizeof(vertices));
    state->commandList->close();
    state->device->executeCommandList(state->commandList);
    state->device->waitForIdle();

    return state;
}

void nvrhi_render(NvrhiState* state) {
    state->swapchain->acquireNextImage();
    auto framebuffer = state->swapchain->getCurrentFramebuffer();

    state->commandList->open();

    nvrhi::utils::ClearColorAttachment(state->commandList, framebuffer, 0, nvrhi::Color(0.f));

    nvrhi::GraphicsState graphicsState;
    graphicsState.pipeline = state->pso;
    graphicsState.framebuffer = framebuffer;
    graphicsState.vertexBuffers[0] = { state->vertexBuffer, 0, 0 };
    graphicsState.viewport.addViewportAndScissorRect(nvrhi::Viewport(800, 600));

    state->commandList->setGraphicsState(graphicsState);

    nvrhi::DrawArguments drawArgs;
    drawArgs.vertexCount = 3;
    state->commandList->draw(drawArgs);

    state->commandList->close();
    state->device->executeCommandList(state->commandList);

    state->swapchain->present();
}

void nvrhi_shutdown(NvrhiState* state) {
    if (state) {
        state->device->waitForIdle();
        delete state;
    }
}
