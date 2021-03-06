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

function main()
    instance = Instance(INSTANCE_LAYERS, INSTANCE_EXTENSIONS; application_info=ApplicationInfo(v"1", v"1", v"1.2"))
    messenger = DebugUtilsMessengerEXT(instance, 
        |(
            DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
            DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
            DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT
        ),
        |(
            DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
            DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
        ),
        debug_callback_c, function_pointer(instance, "vkCreateDebugUtilsMessengerEXT"), function_pointer(instance, "vkDestroyDebugUtilsMessengerEXT"))
    physical_device = first(unwrap(enumerate_physical_devices(instance)))
    device = Device(physical_device, [DeviceQueueCreateInfo(find_queue_index(physical_device, QUEUE_COMPUTE_BIT | QUEUE_GRAPHICS_BIT), [1f0, 1f0])], [], DEVICE_EXTENSIONS; enabled_features=ENABLED_FEATURES)
    format = VK_FORMAT_R16G16B16A16_UINT
    @show get_physical_device_format_properties(physical_device, format)
    target_attachment = AttachmentDescription(format, VK_SAMPLE_COUNT_1_BIT, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
    render_pass = RenderPass(
        device,
        [
            target_attachment,
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
    buffer, _... = unwrap(allocate_command_buffers(device, CommandBufferAllocateInfo(command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, 1)))
    width = height = 100
    fb_image = Image(device, VK_IMAGE_TYPE_2D, format, Extent3D(width, height, 1), 1, 1, VK_SAMPLE_COUNT_1_BIT, VK_IMAGE_TILING_OPTIMAL, IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VK_SHARING_MODE_EXCLUSIVE, [0], VK_IMAGE_LAYOUT_UNDEFINED)
    fb_image_memory = DeviceMemory(device, width * height * 16^4, 1)
    bind_image_memory(device, fb_image, fb_image_memory, 0)
    fb_image_view = ImageView(fb_image.device, fb_image, VK_IMAGE_VIEW_TYPE_2D, format, ComponentMapping(fill(VK_COMPONENT_SWIZZLE_IDENTITY, 4)...), ImageSubresourceRange(IMAGE_ASPECT_COLOR_BIT,0,1,0,1))
    framebuffer = Framebuffer(render_pass.device, render_pass, [fb_image_view], width, height, 1)
    begin_command_buffer(buffer, CommandBufferBeginInfo())
    cmd_begin_render_pass(buffer, RenderPassBeginInfo(render_pass, framebuffer, Rect2D(Offset2D(0,0),Extent2D(width, height)), [vk.VkClearValue(vk.VkClearColorValue((0f0,0f0,0f0,0f0)))]), VK_SUBPASS_CONTENTS_INLINE)
    cmd_end_render_pass(buffer)
    end_command_buffer(buffer)
end

main()

GC.gc()

# include("examples.jl")
# using .VulkanAppExample

# VulkanAppExample.main()
