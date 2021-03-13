const debug_callback_c = Ref{Ptr{Cvoid}}(C_NULL)

function init(;
    instance_layers=[],
    instance_extensions=[],
    device_extensions=[],
    enabled_features=PhysicalDeviceFeatures(),
    nqueues=1,
    queue_flags=QUEUE_COMPUTE_BIT | QUEUE_GRAPHICS_BIT,
    with_validation=true,
)

    if with_validation && "VK_LAYER_KHRONOS_validation" ∉ instance_layers
        push!(instance_layers, "VK_LAYER_KHRONOS_validation")
    end
    if "VK_EXT_debug_utils" ∉ instance_extensions
        push!(instance_extensions, "VK_EXT_debug_utils")
    end
    instance = Instance(instance_layers, instance_extensions; application_info=ApplicationInfo(v"1", v"1", v"1.2"))
    messenger = DebugUtilsMessengerEXT(instance,
        |(
            DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT,
            DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT,
            DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT,
            DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT
        ),
        |(
            DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT,
            DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT
        ),
        debug_callback_c[], function_pointer(instance, "vkCreateDebugUtilsMessengerEXT"), function_pointer(instance, "vkDestroyDebugUtilsMessengerEXT"))
    physical_device = first(unwrap(enumerate_physical_devices(instance)))
    device = Device(physical_device, [DeviceQueueCreateInfo(find_queue_index(physical_device, queue_flags), ones(Float32, nqueues))], [], device_extensions; enabled_features)
    device, messenger
end
