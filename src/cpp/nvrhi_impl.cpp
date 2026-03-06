#include "nvrhi_impl.h"

#include <nvrhi/nvrhi.h>
#include <nvrhi/vulkan.h>

#include <vulkan/vulkan.h>

#define RGFW_VULKAN
extern "C" {
#include "RGFW.h"
}

#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <vector>

#include "triangle_vert_spv.h"
#include "triangle_frag_spv.h"

namespace {

static void log_vk_error(const char* where, VkResult result) {
    std::fprintf(stderr, "%s failed: %d\n", where, int(result));
}

static nvrhi::Format map_vk_format(VkFormat format) {
    switch (format) {
        case VK_FORMAT_B8G8R8A8_UNORM: return nvrhi::Format::BGRA8_UNORM;
        case VK_FORMAT_B8G8R8A8_SRGB: return nvrhi::Format::SBGRA8_UNORM;
        case VK_FORMAT_R8G8B8A8_UNORM: return nvrhi::Format::RGBA8_UNORM;
        case VK_FORMAT_R8G8B8A8_SRGB: return nvrhi::Format::SRGBA8_UNORM;
        default: return nvrhi::Format::BGRA8_UNORM;
    }
}

struct NvrhiMessageCallback final : nvrhi::IMessageCallback {
    void message(nvrhi::MessageSeverity severity, const char* messageText) override {
        const char* tag = "info";
        if (severity == nvrhi::MessageSeverity::Warning) tag = "warn";
        if (severity == nvrhi::MessageSeverity::Error) tag = "error";
        if (severity == nvrhi::MessageSeverity::Fatal) tag = "fatal";
        std::fprintf(stderr, "[nvrhi:%s] %s\n", tag, messageText ? messageText : "(null)");
    }
};

} // namespace

struct NvrhiState {
    RGFW_window* window = nullptr;

    VkInstance instance = VK_NULL_HANDLE;
    VkPhysicalDevice physical_device = VK_NULL_HANDLE;
    VkDevice device = VK_NULL_HANDLE;
    VkSurfaceKHR surface = VK_NULL_HANDLE;
    VkQueue graphics_queue = VK_NULL_HANDLE;
    std::uint32_t graphics_queue_family = 0;

    VkSwapchainKHR swapchain = VK_NULL_HANDLE;
    VkFormat swapchain_vk_format = VK_FORMAT_B8G8R8A8_UNORM;
    VkExtent2D swapchain_extent = { 1, 1 };
    std::vector<VkImage> swapchain_images;

    VkFence acquire_fence = VK_NULL_HANDLE;

    NvrhiMessageCallback* message_cb = nullptr;
    nvrhi::vulkan::DeviceHandle nvrhi_device;
    nvrhi::CommandListHandle command_list;

    nvrhi::ShaderHandle vs;
    nvrhi::ShaderHandle ps;
    nvrhi::InputLayoutHandle input_layout;
    nvrhi::GraphicsPipelineHandle pipeline;

    std::vector<nvrhi::TextureHandle> backbuffers;
    std::vector<nvrhi::FramebufferHandle> framebuffers;
};

static bool create_vk_instance(NvrhiState* s) {
    size_t ext_count = 0;
    const char** exts = RGFW_getRequiredInstanceExtensions_Vulkan(&ext_count);
    if (!exts || ext_count == 0) {
        std::fprintf(stderr, "RGFW_getRequiredInstanceExtensions_Vulkan returned no extensions\n");
        return false;
    }

    VkApplicationInfo app_info{};
    app_info.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO;
    app_info.pApplicationName = "sprout";
    app_info.applicationVersion = VK_MAKE_VERSION(0, 1, 0);
    app_info.pEngineName = "none";
    app_info.engineVersion = VK_MAKE_VERSION(0, 1, 0);
    app_info.apiVersion = VK_API_VERSION_1_1;

    VkInstanceCreateInfo ci{};
    ci.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
    ci.pApplicationInfo = &app_info;
    ci.enabledExtensionCount = ext_count;
    ci.ppEnabledExtensionNames = exts;

    const VkResult r = vkCreateInstance(&ci, nullptr, &s->instance);
    if (r != VK_SUCCESS) {
        log_vk_error("vkCreateInstance", r);
        return false;
    }

    const VkResult sr = RGFW_window_createSurface_Vulkan(s->window, s->instance, &s->surface);
    if (sr != VK_SUCCESS) {
        log_vk_error("RGFW_window_createSurface_Vulkan", sr);
        return false;
    }

    return true;
}

static bool pick_physical_device_and_queue(NvrhiState* s) {
    std::uint32_t gpu_count = 0;
    VkResult r = vkEnumeratePhysicalDevices(s->instance, &gpu_count, nullptr);
    if (r != VK_SUCCESS || gpu_count == 0) {
        log_vk_error("vkEnumeratePhysicalDevices(count)", r);
        return false;
    }

    std::vector<VkPhysicalDevice> gpus(gpu_count);
    r = vkEnumeratePhysicalDevices(s->instance, &gpu_count, gpus.data());
    if (r != VK_SUCCESS) {
        log_vk_error("vkEnumeratePhysicalDevices(list)", r);
        return false;
    }

    for (VkPhysicalDevice gpu : gpus) {
        std::uint32_t queue_count = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(gpu, &queue_count, nullptr);
        if (queue_count == 0) continue;

        std::vector<VkQueueFamilyProperties> qprops(queue_count);
        vkGetPhysicalDeviceQueueFamilyProperties(gpu, &queue_count, qprops.data());

        for (std::uint32_t i = 0; i < queue_count; ++i) {
            if ((qprops[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) == 0) continue;

            VkBool32 supports_present = VK_FALSE;
            r = vkGetPhysicalDeviceSurfaceSupportKHR(gpu, i, s->surface, &supports_present);
            if (r != VK_SUCCESS) {
                log_vk_error("vkGetPhysicalDeviceSurfaceSupportKHR", r);
                continue;
            }

            if (supports_present == VK_TRUE) {
                s->physical_device = gpu;
                s->graphics_queue_family = i;
                return true;
            }
        }
    }

    std::fprintf(stderr, "No suitable Vulkan physical device with graphics+present queue found\n");
    return false;
}

static bool create_vk_device(NvrhiState* s) {
    const float prio = 1.0f;
    VkDeviceQueueCreateInfo qci{};
    qci.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
    qci.queueFamilyIndex = s->graphics_queue_family;
    qci.queueCount = 1;
    qci.pQueuePriorities = &prio;

    const char* device_exts[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };

    VkDeviceCreateInfo dci{};
    dci.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
    dci.queueCreateInfoCount = 1;
    dci.pQueueCreateInfos = &qci;
    dci.enabledExtensionCount = 1;
    dci.ppEnabledExtensionNames = device_exts;

    const VkResult r = vkCreateDevice(s->physical_device, &dci, nullptr, &s->device);
    if (r != VK_SUCCESS) {
        log_vk_error("vkCreateDevice", r);
        return false;
    }

    vkGetDeviceQueue(s->device, s->graphics_queue_family, 0, &s->graphics_queue);

    VkFenceCreateInfo fci{};
    fci.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO;
    const VkResult fr = vkCreateFence(s->device, &fci, nullptr, &s->acquire_fence);
    if (fr != VK_SUCCESS) {
        log_vk_error("vkCreateFence", fr);
        return false;
    }

    return true;
}

static void destroy_swapchain_wrappers(NvrhiState* s) {
    s->framebuffers.clear();
    s->backbuffers.clear();
    s->swapchain_images.clear();
}

static bool create_swapchain_and_wrappers(NvrhiState* s) {
    VkSurfaceCapabilitiesKHR caps{};
    VkResult r = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(s->physical_device, s->surface, &caps);
    if (r != VK_SUCCESS) {
        log_vk_error("vkGetPhysicalDeviceSurfaceCapabilitiesKHR", r);
        return false;
    }

    std::uint32_t format_count = 0;
    r = vkGetPhysicalDeviceSurfaceFormatsKHR(s->physical_device, s->surface, &format_count, nullptr);
    if (r != VK_SUCCESS || format_count == 0) {
        log_vk_error("vkGetPhysicalDeviceSurfaceFormatsKHR(count)", r);
        return false;
    }

    std::vector<VkSurfaceFormatKHR> formats(format_count);
    r = vkGetPhysicalDeviceSurfaceFormatsKHR(s->physical_device, s->surface, &format_count, formats.data());
    if (r != VK_SUCCESS) {
        log_vk_error("vkGetPhysicalDeviceSurfaceFormatsKHR(list)", r);
        return false;
    }

    VkSurfaceFormatKHR chosen = formats[0];
    for (const auto& f : formats) {
        if (f.format == VK_FORMAT_B8G8R8A8_UNORM) {
            chosen = f;
            break;
        }
    }

    std::uint32_t present_count = 0;
    r = vkGetPhysicalDeviceSurfacePresentModesKHR(s->physical_device, s->surface, &present_count, nullptr);
    if (r != VK_SUCCESS || present_count == 0) {
        log_vk_error("vkGetPhysicalDeviceSurfacePresentModesKHR(count)", r);
        return false;
    }

    std::vector<VkPresentModeKHR> presents(present_count);
    r = vkGetPhysicalDeviceSurfacePresentModesKHR(s->physical_device, s->surface, &present_count, presents.data());
    if (r != VK_SUCCESS) {
        log_vk_error("vkGetPhysicalDeviceSurfacePresentModesKHR(list)", r);
        return false;
    }

    VkPresentModeKHR present_mode = VK_PRESENT_MODE_FIFO_KHR;
    for (auto pm : presents) {
        if (pm == VK_PRESENT_MODE_MAILBOX_KHR) {
            present_mode = pm;
            break;
        }
    }

    int win_w = 0, win_h = 0;
    RGFW_window_getSize(s->window, &win_w, &win_h);

    VkExtent2D extent{};
    if (caps.currentExtent.width != UINT32_MAX) {
        extent = caps.currentExtent;
    } else {
        extent.width = std::clamp<std::uint32_t>(std::uint32_t(win_w > 0 ? win_w : 1), caps.minImageExtent.width, caps.maxImageExtent.width);
        extent.height = std::clamp<std::uint32_t>(std::uint32_t(win_h > 0 ? win_h : 1), caps.minImageExtent.height, caps.maxImageExtent.height);
    }

    std::uint32_t image_count = caps.minImageCount + 1;
    if (caps.maxImageCount > 0 && image_count > caps.maxImageCount) image_count = caps.maxImageCount;

    VkSwapchainCreateInfoKHR sci{};
    sci.sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    sci.surface = s->surface;
    sci.minImageCount = image_count;
    sci.imageFormat = chosen.format;
    sci.imageColorSpace = chosen.colorSpace;
    sci.imageExtent = extent;
    sci.imageArrayLayers = 1;
    sci.imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    sci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    sci.preTransform = caps.currentTransform;
    sci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    sci.presentMode = present_mode;
    sci.clipped = VK_TRUE;
    sci.oldSwapchain = s->swapchain;

    VkSwapchainKHR new_swapchain = VK_NULL_HANDLE;
    r = vkCreateSwapchainKHR(s->device, &sci, nullptr, &new_swapchain);
    if (r != VK_SUCCESS) {
        log_vk_error("vkCreateSwapchainKHR", r);
        return false;
    }

    if (s->swapchain != VK_NULL_HANDLE) {
        destroy_swapchain_wrappers(s);
        vkDestroySwapchainKHR(s->device, s->swapchain, nullptr);
    }

    s->swapchain = new_swapchain;
    s->swapchain_vk_format = chosen.format;
    s->swapchain_extent = extent;

    std::uint32_t sc_image_count = 0;
    r = vkGetSwapchainImagesKHR(s->device, s->swapchain, &sc_image_count, nullptr);
    if (r != VK_SUCCESS || sc_image_count == 0) {
        log_vk_error("vkGetSwapchainImagesKHR(count)", r);
        return false;
    }

    s->swapchain_images.resize(sc_image_count);
    r = vkGetSwapchainImagesKHR(s->device, s->swapchain, &sc_image_count, s->swapchain_images.data());
    if (r != VK_SUCCESS) {
        log_vk_error("vkGetSwapchainImagesKHR(list)", r);
        return false;
    }

    s->backbuffers.resize(sc_image_count);
    s->framebuffers.resize(sc_image_count);

    const nvrhi::Format color_format = map_vk_format(s->swapchain_vk_format);

    for (std::uint32_t i = 0; i < sc_image_count; ++i) {
        nvrhi::TextureDesc td;
        td.setWidth(s->swapchain_extent.width)
            .setHeight(s->swapchain_extent.height)
            .setFormat(color_format)
            .setDimension(nvrhi::TextureDimension::Texture2D)
            .setIsRenderTarget(true)
            .setDebugName("SwapchainBackbuffer")
            .setInitialState(nvrhi::ResourceStates::Present)
            .setKeepInitialState(true);

        s->backbuffers[i] = s->nvrhi_device->createHandleForNativeTexture(
            nvrhi::ObjectTypes::VK_Image,
            nvrhi::Object(reinterpret_cast<void*>(s->swapchain_images[i])),
            td);

        nvrhi::FramebufferDesc fbd;
        fbd.addColorAttachment(s->backbuffers[i]);
        s->framebuffers[i] = s->nvrhi_device->createFramebuffer(fbd);
    }

    return true;
}

static bool create_nvrhi_objects(NvrhiState* s) {
    s->message_cb = new NvrhiMessageCallback();

    size_t inst_ext_count = 0;
    const char** inst_exts = RGFW_getRequiredInstanceExtensions_Vulkan(&inst_ext_count);
    const char* dev_exts[] = { VK_KHR_SWAPCHAIN_EXTENSION_NAME };

    nvrhi::vulkan::DeviceDesc desc{};
    desc.errorCB = s->message_cb;
    desc.instance = s->instance;
    desc.physicalDevice = s->physical_device;
    desc.device = s->device;
    desc.graphicsQueue = s->graphics_queue;
    desc.graphicsQueueIndex = int(s->graphics_queue_family);
    desc.instanceExtensions = inst_exts;
    desc.numInstanceExtensions = inst_ext_count;
    desc.deviceExtensions = dev_exts;
    desc.numDeviceExtensions = 1;

    s->nvrhi_device = nvrhi::vulkan::createDevice(desc);
    if (!s->nvrhi_device) {
        std::fprintf(stderr, "nvrhi::vulkan::createDevice failed\n");
        return false;
    }

    s->command_list = s->nvrhi_device->createCommandList();
    if (!s->command_list) {
        std::fprintf(stderr, "createCommandList failed\n");
        return false;
    }

    s->vs = s->nvrhi_device->createShader(
        nvrhi::ShaderDesc().setShaderType(nvrhi::ShaderType::Vertex).setDebugName("TriangleVS"),
        src_cpp_triangle_vert_spv,
        src_cpp_triangle_vert_spv_len);

    s->ps = s->nvrhi_device->createShader(
        nvrhi::ShaderDesc().setShaderType(nvrhi::ShaderType::Pixel).setDebugName("TrianglePS"),
        src_cpp_triangle_frag_spv,
        src_cpp_triangle_frag_spv_len);

    if (!s->vs || !s->ps) {
        std::fprintf(stderr, "createShader failed\n");
        return false;
    }

    s->input_layout = s->nvrhi_device->createInputLayout(nullptr, 0, s->vs);

    nvrhi::FramebufferInfo fb_info;
    fb_info.addColorFormat(map_vk_format(s->swapchain_vk_format));
    fb_info.setSampleCount(1);

    nvrhi::GraphicsPipelineDesc pso_desc;
    pso_desc.setPrimType(nvrhi::PrimitiveType::TriangleList);
    pso_desc.setVertexShader(s->vs);
    pso_desc.setPixelShader(s->ps);
    pso_desc.setInputLayout(s->input_layout);
    pso_desc.renderState.rasterState.setCullNone();

    s->pipeline = s->nvrhi_device->createGraphicsPipeline(pso_desc, fb_info);
    if (!s->pipeline) {
        std::fprintf(stderr, "createGraphicsPipeline failed\n");
        return false;
    }

    return true;
}

NvrhiState* nvrhi_init(void* window) {
    auto* s = new NvrhiState();
    s->window = reinterpret_cast<RGFW_window*>(window);

    if (!s->window) {
        std::fprintf(stderr, "nvrhi_init got null window\n");
        nvrhi_shutdown(s);
        return nullptr;
    }

    if (!create_vk_instance(s)) {
        nvrhi_shutdown(s);
        return nullptr;
    }

    if (!pick_physical_device_and_queue(s)) {
        nvrhi_shutdown(s);
        return nullptr;
    }

    if (!create_vk_device(s)) {
        nvrhi_shutdown(s);
        return nullptr;
    }

    if (!create_nvrhi_objects(s)) {
        nvrhi_shutdown(s);
        return nullptr;
    }

    if (!create_swapchain_and_wrappers(s)) {
        nvrhi_shutdown(s);
        return nullptr;
    }

    return s;
}

void nvrhi_render(NvrhiState* s) {
    if (!s || !s->swapchain) return;

    vkWaitForFences(s->device, 1, &s->acquire_fence, VK_TRUE, UINT64_MAX);
    vkResetFences(s->device, 1, &s->acquire_fence);

    std::uint32_t image_index = 0;
    VkResult r = vkAcquireNextImageKHR(s->device, s->swapchain, UINT64_MAX, VK_NULL_HANDLE, s->acquire_fence, &image_index);

    if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR) {
        vkDeviceWaitIdle(s->device);
        if (!create_swapchain_and_wrappers(s)) return;
        return;
    }

    if (r != VK_SUCCESS) {
        log_vk_error("vkAcquireNextImageKHR", r);
        return;
    }

    nvrhi::ICommandList* cmd = s->command_list;
    cmd->open();
    cmd->beginTrackingTextureState(s->backbuffers[image_index], nvrhi::AllSubresources, nvrhi::ResourceStates::Present);
    cmd->setTextureState(s->backbuffers[image_index], nvrhi::AllSubresources, nvrhi::ResourceStates::RenderTarget);

    cmd->clearTextureFloat(
        s->backbuffers[image_index],
        nvrhi::AllSubresources,
        nvrhi::Color(0.08f, 0.08f, 0.12f, 1.0f));

    nvrhi::GraphicsState state;
    state.setPipeline(s->pipeline);
    state.setFramebuffer(s->framebuffers[image_index]);
    state.viewport.addViewportAndScissorRect(
        nvrhi::Viewport(float(s->swapchain_extent.width), float(s->swapchain_extent.height)));

    cmd->setGraphicsState(state);
    cmd->draw(nvrhi::DrawArguments().setVertexCount(3));

    cmd->setTextureState(s->backbuffers[image_index], nvrhi::AllSubresources, nvrhi::ResourceStates::Present);
    cmd->close();

    s->nvrhi_device->executeCommandList(cmd);
    s->nvrhi_device->waitForIdle();

    VkPresentInfoKHR present{};
    present.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR;
    present.swapchainCount = 1;
    present.pSwapchains = &s->swapchain;
    present.pImageIndices = &image_index;

    r = vkQueuePresentKHR(s->graphics_queue, &present);
    if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR) {
        vkDeviceWaitIdle(s->device);
        create_swapchain_and_wrappers(s);
        return;
    }
    if (r != VK_SUCCESS) {
        log_vk_error("vkQueuePresentKHR", r);
    }

    s->nvrhi_device->runGarbageCollection();
}

void nvrhi_shutdown(NvrhiState* s) {
    if (!s) return;

    if (s->nvrhi_device) {
        s->nvrhi_device->waitForIdle();
    } else if (s->device != VK_NULL_HANDLE) {
        vkDeviceWaitIdle(s->device);
    }

    destroy_swapchain_wrappers(s);
    s->pipeline = nullptr;
    s->input_layout = nullptr;
    s->ps = nullptr;
    s->vs = nullptr;
    s->command_list = nullptr;
    s->nvrhi_device = nullptr;

    if (s->acquire_fence != VK_NULL_HANDLE) {
        vkDestroyFence(s->device, s->acquire_fence, nullptr);
        s->acquire_fence = VK_NULL_HANDLE;
    }

    if (s->swapchain != VK_NULL_HANDLE) {
        vkDestroySwapchainKHR(s->device, s->swapchain, nullptr);
        s->swapchain = VK_NULL_HANDLE;
    }

    if (s->device != VK_NULL_HANDLE) {
        vkDestroyDevice(s->device, nullptr);
        s->device = VK_NULL_HANDLE;
    }

    if (s->surface != VK_NULL_HANDLE && s->instance != VK_NULL_HANDLE) {
        vkDestroySurfaceKHR(s->instance, s->surface, nullptr);
        s->surface = VK_NULL_HANDLE;
    }

    if (s->instance != VK_NULL_HANDLE) {
        vkDestroyInstance(s->instance, nullptr);
        s->instance = VK_NULL_HANDLE;
    }

    if (s->message_cb) {
        delete s->message_cb;
        s->message_cb = nullptr;
    }

    delete s;
}
