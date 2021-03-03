using Test
using Vulkan

const debug_callback_c = @cfunction(default_debug_callback, UInt32, (VkDebugUtilsMessageSeverityFlagBitsEXT, VkDebugUtilsMessageTypeFlagBitsEXT, Ptr{vk.VkDebugUtilsMessengerCallbackDataEXT}, Ptr{Cvoid}))
const INSTANCE_LAYERS = [
    "VK_LAYER_KHRONOS_validation",
]
const INSTANCE_EXTENSIONS = [
    "VK_EXT_debug_utils",
    "VK_KHR_surface",
]
const DEVICE_EXTENSIONS = [
    "VK_KHR_swapchain",
]
const ENABLED_FEATURES = PhysicalDeviceFeatures(
)

const instance = Instance(INSTANCE_LAYERS, INSTANCE_EXTENSIONS; application_info=ApplicationInfo(v"1", v"1", v"1.2"))
const debug_messenger = DebugUtilsMessengerEXT(instance, DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT, DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT | DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT | DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT, debug_callback_c, function_pointer(instance, "vkCreateDebugUtilsMessengerEXT"), function_pointer(instance, "vkDestroyDebugUtilsMessengerEXT"))
const physical_device = first(unwrap(enumerate_physical_devices(instance)))
const device = Device(physical_device, [DeviceQueueCreateInfo(find_queue_index(physical_device, QUEUE_COMPUTE_BIT | QUEUE_GRAPHICS_BIT), ones(2))], [], DEVICE_EXTENSIONS; enabled_features=ENABLED_FEATURES)

renderpass = RenderPass(
    device,
    [
        AttachmentDescription(VK_FORMAT_B8G8R8A8_SRGB, VK_SAMPLE_COUNT_1_BIT, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL),
    ],
    [
        SubpassDescription(
            VK_PIPELINE_BIND_POINT_GRAPHICS,
            [],
            [
                AttachmentReference(0, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
            ],
            []
        )
    ],
    [
        SubpassDependency(VK_SUBPASS_EXTERNAL, 0, PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT; dst_access_mask=ACCESS_COLOR_ATTACHMENT_WRITE_BIT)
    ]
)

command_pool = CommandPool(device, 0)
buffer = first(unwrap(allocate_command_buffers(device, CommandBufferAllocateInfo(command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, 1))))

GC.gc()

# include("examples.jl")
# using .VulkanAppExample

# VulkanAppExample.main()
