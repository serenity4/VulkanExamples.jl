module VulkanExamples

using Reexport
using MLStyle

@reexport using Vulkan

function __init__()
    debug_callback_c[] = @cfunction(
        default_debug_callback,
        UInt32,
        (
            VkDebugUtilsMessageSeverityFlagBitsEXT,
            VkDebugUtilsMessageTypeFlagBitsEXT,
            Ptr{vk.VkDebugUtilsMessengerCallbackDataEXT},
            Ptr{Cvoid},
        )
    )
end

include("init.jl")
include("memory.jl")
include("vertex.jl")

export init,

    # memory
    find_memory_type,
    buffer_size,
    upload_data,
    download_data,

    # vertex
    PosColor,
    PosUV,
    Point4f,
    invert_y_axis

end
