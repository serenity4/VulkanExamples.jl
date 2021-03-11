using Test
using Vulkan
using VulkanShaders
using Meshes

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

const Point4f = Point{4, Float32}

abstract type VertexData end

binding_description(::Type{T}, binding; input_rate=VK_VERTEX_INPUT_RATE_VERTEX) where {T <: VertexData} = VertexInputBindingDescription(binding, sizeof(T), input_rate)

const formats = Dict(
    Point1f => VK_FORMAT_R32_SFLOAT,
    Point2f => VK_FORMAT_R32G32_SFLOAT,
    Point3f => VK_FORMAT_R32G32B32_SFLOAT,
    Point4f => VK_FORMAT_R32G32B32A32_SFLOAT,
)

Vulkan.VertexInputAttributeDescription(::Type{T}, binding) where {T <: VertexData} = VertexInputAttributeDescription.(0:fieldcount(T)-1, binding, getindex.(Ref(formats), fieldtypes(T)), fieldoffset.(T, 1:fieldcount(T)))
invert_y_axis(p::Point{2}) = typeof(p)(p.coords[1], -p.coords[2])

struct PosColor{PDim, CDim, T <: Real} <: VertexData
    position::Point{PDim, T}
    color::Point{CDim, T}
end

indices(ps) = collect(0:(length(ps)-1))
pos_color(ps, colors) = PosColor.(invert_y_axis.(coordinates(ps)), colors)

ps = [
    Point2f(-0.5, -0.5),
    Point2f(-0.5, 0.5),
    Point2f(0.5, -0.5),
    Point2f(0.5, 0.5),
]

colors = [
    Point4f(0., 0., 1., 0.7),
    Point4f(0., 1., 0., 0.05),
    Point4f(1., 0., 0., 1.),
    Point4f(1., 1., 1., 0.4),
]

function find_memory_type(physical_device, type_flag, properties)
    mem_props = get_physical_device_memory_properties(physical_device)
    indices = findall(x -> (MemoryPropertyFlag(x.property_flags) & properties) == properties, mem_props.memory_types[1:mem_props.memory_type_count]) .- 1
    indices[findfirst(i -> type_flag & 1 << i ≠ 0, indices)]
end

function main()
    instance = Instance(INSTANCE_LAYERS, INSTANCE_EXTENSIONS; application_info=ApplicationInfo(v"1", v"1", v"1.2"))
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
        debug_callback_c, function_pointer(instance, "vkCreateDebugUtilsMessengerEXT"), function_pointer(instance, "vkDestroyDebugUtilsMessengerEXT"))
    physical_device = first(unwrap(enumerate_physical_devices(instance)))
    device = Device(physical_device, [DeviceQueueCreateInfo(find_queue_index(physical_device, QUEUE_COMPUTE_BIT | QUEUE_GRAPHICS_BIT), [1f0, 1f0])], [], DEVICE_EXTENSIONS; enabled_features=ENABLED_FEATURES)
    # format = FORMAT_B8G8R8A8_SRGB
    format = VK_FORMAT_R8G8B8A8_SRGB
    target_attachment = AttachmentDescription(format, SAMPLE_COUNT_1_BIT, VK_ATTACHMENT_LOAD_OP_CLEAR, VK_ATTACHMENT_STORE_OP_STORE, VK_ATTACHMENT_LOAD_OP_DONT_CARE, VK_ATTACHMENT_STORE_OP_DONT_CARE, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)
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
    width = height = 100
    fb_image = Image(device, VK_IMAGE_TYPE_2D, format, Extent3D(width, height, 1), 1, 1, SAMPLE_COUNT_1_BIT, VK_IMAGE_TILING_OPTIMAL, IMAGE_USAGE_COLOR_ATTACHMENT_BIT, VK_SHARING_MODE_EXCLUSIVE, [0], VK_IMAGE_LAYOUT_UNDEFINED)
    mem_reqs = get_image_memory_requirements(fb_image.device, fb_image)
    fb_image_memory = DeviceMemory(device, mem_reqs.size, 1)
    bind_image_memory(device, fb_image, fb_image_memory, 0)
    fb_image_view = ImageView(fb_image.device, fb_image, VK_IMAGE_VIEW_TYPE_2D, format, ComponentMapping(fill(VK_COMPONENT_SWIZZLE_IDENTITY, 4)...), ImageSubresourceRange(IMAGE_ASPECT_COLOR_BIT,0,1,0,1))
    framebuffer = Framebuffer(render_pass.device, render_pass, [fb_image_view], width, height, 1)

    vert_shader = Shader(device, ShaderFile(joinpath(@__DIR__, "triangle.vert"), FormatGLSL()), [DescriptorBinding(VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER, 0, 0)])
    vertices = PosColor.(ps, colors)
    frag_shader = Shader(device, ShaderFile(joinpath(@__DIR__, "triangle.frag"), FormatGLSL()), DescriptorBinding[])
    shaders = [vert_shader, frag_shader]

    shader_stage_cis = PipelineShaderStageCreateInfo.(shaders)
    vertex_input_state = PipelineVertexInputStateCreateInfo([binding_description(eltype(vertices), 0)], VertexInputAttributeDescription(eltype(vertices), 0))
    input_assembly_state = PipelineInputAssemblyStateCreateInfo(VK_PRIMITIVE_TOPOLOGY_TRIANGLE_STRIP, false)
    rasterizer = PipelineRasterizationStateCreateInfo(false, true, VK_POLYGON_MODE_FILL, VK_FRONT_FACE_CLOCKWISE, false, 0., 0., 0., 1., cull_mode=CULL_MODE_BACK_BIT)
    multisample_state = PipelineMultisampleStateCreateInfo(SAMPLE_COUNT_1_BIT, false, 1., false, false)
    color_blend_attachment = PipelineColorBlendAttachmentState(false, VK_BLEND_FACTOR_ONE, VK_BLEND_FACTOR_ZERO, VK_BLEND_OP_ADD, VK_BLEND_FACTOR_ONE, VK_BLEND_FACTOR_ZERO, VK_BLEND_OP_ADD)
    color_blend_state = PipelineColorBlendStateCreateInfo(false, VK_LOGIC_OP_CLEAR, [color_blend_attachment], Float32.((0.0, 1.0, 1.0, 0.01)))
    (pipeline, _...), _ = unwrap(create_graphics_pipelines(
        device,
        [GraphicsPipelineCreateInfo(
            shader_stage_cis,
            rasterizer,
            PipelineLayout(device, descriptor_set_layouts(shaders), []),
            render_pass,
            0,
            0;
            vertex_input_state,
            multisample_state,
            color_blend_state,
            input_assembly_state
        )]
    ))

    datasize = sizeof(eltype(vertices)) * length(vertices)
    vertex_buffer = Buffer(device, datasize, BUFFER_USAGE_VERTEX_BUFFER_BIT, VK_SHARING_MODE_EXCLUSIVE, [0])
    vertex_buffer_memreqs = get_buffer_memory_requirements(vertex_buffer.device, vertex_buffer)
    vertex_buffer_memory = DeviceMemory(vertex_buffer.device, vertex_buffer_memreqs.size, find_memory_type(vertex_buffer.device.physical_device, vertex_buffer_memreqs.memory_type_bits, MEMORY_PROPERTY_HOST_VISIBLE_BIT | MEMORY_PROPERTY_HOST_COHERENT_BIT))
    bind_buffer_memory(vertex_buffer.device, vertex_buffer, vertex_buffer_memory, 0)
    dataptr = unwrap(map_memory(vertex_buffer_memory.device, vertex_buffer_memory, 0, datasize))
    unsafe_copyto!(Ptr{eltype(vertices)}(dataptr), pointer(vertices), length(vertices))
    unwrap(unmap_memory(vertex_buffer_memory.device, vertex_buffer_memory))
    command_buffer, _... = unwrap(allocate_command_buffers(device, CommandBufferAllocateInfo(command_pool, VK_COMMAND_BUFFER_LEVEL_PRIMARY, 1)))
    begin_command_buffer(command_buffer, CommandBufferBeginInfo())
    cmd_begin_render_pass(command_buffer, RenderPassBeginInfo(render_pass, framebuffer, Rect2D(Offset2D(0,0),Extent2D(width, height)), [vk.VkClearValue(vk.VkClearColorValue((0f0,0f0,0f0,0f0)))]), VK_SUBPASS_CONTENTS_INLINE)
    cmd_bind_pipeline(command_buffer, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline)
    cmd_bind_vertex_buffers(command_buffer, [vertex_buffer], [0])
    cmd_draw(command_buffer, 4, 1, 0, 0)
    cmd_end_render_pass(command_buffer)
    end_command_buffer(command_buffer)
    queue_submit(get_device_queue(device, 0, 0), [SubmitInfo([], [], [command_buffer], [])])
    device_wait_idle(device)
end

main()

GC.gc()

# include("examples.jl")
# using .VulkanAppExample

# VulkanAppExample.main()
