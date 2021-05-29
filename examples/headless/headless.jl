using Vulkan
using VulkanExamples
using VulkanShaders
using ColorTypes
using FileIO
using Meshes

function main(output_png, points, colors; width = 1000, height = 1000)
    device, queue, messenger = init(enabled_features = PhysicalDeviceFeatures(:geometry_shader))

    VertexType = PosColor{eltype(points),eltype(colors)}
    format = Format(eltype(colors))

    # define render pass
    target_attachment = AttachmentDescription(
        format,
        SAMPLE_COUNT_1_BIT,
        ATTACHMENT_LOAD_OP_CLEAR,
        ATTACHMENT_STORE_OP_STORE,
        ATTACHMENT_LOAD_OP_DONT_CARE,
        ATTACHMENT_STORE_OP_DONT_CARE,
        IMAGE_LAYOUT_UNDEFINED,
        IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    )
    render_pass = RenderPass(
        device,
        [target_attachment],
        [
            SubpassDescription(
                PIPELINE_BIND_POINT_GRAPHICS,
                [],
                [AttachmentReference(0, IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL)],
                [],
            ),
        ],
        [
            SubpassDependency(
                vk.VK_SUBPASS_EXTERNAL,
                0;
                src_stage_mask = PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                dst_stage_mask = PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
                dst_access_mask = ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
            ),
        ],
    )

    # create image and framebuffer
    fb_image = Image(
        device,
        IMAGE_TYPE_2D,
        format,
        Extent3D(width, height, 1),
        1,
        1,
        SAMPLE_COUNT_1_BIT,
        IMAGE_TILING_OPTIMAL,
        IMAGE_USAGE_COLOR_ATTACHMENT_BIT | IMAGE_USAGE_TRANSFER_SRC_BIT,
        SHARING_MODE_EXCLUSIVE,
        [0],
        IMAGE_LAYOUT_UNDEFINED,
    )
    fb_image_memory = DeviceMemory(fb_image, MEMORY_PROPERTY_DEVICE_LOCAL_BIT)
    fb_image_view = ImageView(
        fb_image.device,
        fb_image,
        IMAGE_VIEW_TYPE_2D,
        format,
        ComponentMapping(fill(COMPONENT_SWIZZLE_IDENTITY, 4)...),
        ImageSubresourceRange(IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1),
    )
    framebuffer = Framebuffer(render_pass.device, render_pass, [fb_image_view], width, height, 1)

    # prepare shaders
    vert_shader = Shader(device, ShaderFile(joinpath(@__DIR__, "triangle.vert"), FormatGLSL()), DescriptorBinding[])
    frag_shader = Shader(device, ShaderFile(joinpath(@__DIR__, "triangle.frag"), FormatGLSL()), DescriptorBinding[])
    shaders = [vert_shader, frag_shader]

    # prepare vertex and index data
    p = PolyArea(Meshes.CircularVector(points))
    mesh = discretize(p, FIST())
    idata = Iterators.flatten(map(x -> UInt32.(x.indices), mesh.topology.connec)) .- UInt32(1)
    vdata = VertexType.(points, colors)

    # prepare vertex buffer
    vbuffer = Buffer(device, buffer_size(vdata), BUFFER_USAGE_VERTEX_BUFFER_BIT, SHARING_MODE_EXCLUSIVE, [0])
    vmemory = DeviceMemory(vbuffer, vdata)

    # prepare index buffer
    ibuffer = Buffer(device, buffer_size(idata), BUFFER_USAGE_INDEX_BUFFER_BIT, SHARING_MODE_EXCLUSIVE, [0])
    imemory = DeviceMemory(ibuffer, idata)

    # build graphics pipeline
    shader_stage_cis = PipelineShaderStageCreateInfo.(shaders)
    vertex_input_state = PipelineVertexInputStateCreateInfo(
        [VertexInputBindingDescription(eltype(vdata), 0)],
        VertexInputAttributeDescription(eltype(vdata), 0),
    )
    input_assembly_state = PipelineInputAssemblyStateCreateInfo(PRIMITIVE_TOPOLOGY_TRIANGLE_LIST, false)
    viewport_state = PipelineViewportStateCreateInfo(
        viewports = [Viewport(0, 0, width, height, 0, 1)],
        scissors = [Rect2D(Offset2D(0, 0), Extent2D(width, height))],
    )
    rasterizer = PipelineRasterizationStateCreateInfo(
        false,
        false,
        POLYGON_MODE_FILL,
        FRONT_FACE_CLOCKWISE,
        false,
        0.0,
        0.0,
        0.0,
        1.0,
        cull_mode = CULL_MODE_BACK_BIT,
    )
    multisample_state = PipelineMultisampleStateCreateInfo(SAMPLE_COUNT_1_BIT, false, 1.0, false, false)
    color_blend_attachment = PipelineColorBlendAttachmentState(
        true,
        BLEND_FACTOR_SRC_ALPHA,
        BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        BLEND_OP_ADD,
        BLEND_FACTOR_SRC_ALPHA,
        BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        BLEND_OP_ADD;
        color_write_mask = COLOR_COMPONENT_R_BIT | COLOR_COMPONENT_G_BIT | COLOR_COMPONENT_B_BIT,
    )
    color_blend_state = PipelineColorBlendStateCreateInfo(
        false,
        LOGIC_OP_CLEAR,
        [color_blend_attachment],
        Float32.((0.0, 0.0, 0.0, 0.0)),
    )
    pipeline_layout = PipelineLayout(device, [], [])
    (pipeline, _...), _ = unwrap(
        create_graphics_pipelines(
            device,
            [
                GraphicsPipelineCreateInfo(
                    shader_stage_cis,
                    rasterizer,
                    pipeline_layout,
                    render_pass,
                    0,
                    0;
                    vertex_input_state,
                    multisample_state,
                    color_blend_state,
                    input_assembly_state,
                    viewport_state,
                ),
            ],
        ),
    )

    # create local image for transfer
    local_image = Image(
        device,
        IMAGE_TYPE_2D,
        format,
        Extent3D(width, height, 1),
        1,
        1,
        SAMPLE_COUNT_1_BIT,
        IMAGE_TILING_LINEAR,
        IMAGE_USAGE_TRANSFER_DST_BIT,
        SHARING_MODE_EXCLUSIVE,
        [0],
        IMAGE_LAYOUT_UNDEFINED,
    )

    local_image_memory = DeviceMemory(local_image, MEMORY_PROPERTY_HOST_COHERENT_BIT | MEMORY_PROPERTY_HOST_VISIBLE_BIT)

    # record commands
    command_pool = CommandPool(device, 0)
    command_buffer, _... = unwrap(
        allocate_command_buffers(device, CommandBufferAllocateInfo(command_pool, COMMAND_BUFFER_LEVEL_PRIMARY, 1)),
    )
    begin_command_buffer(command_buffer, CommandBufferBeginInfo())
    cmd_bind_vertex_buffers(command_buffer, [vbuffer], [0])
    cmd_bind_index_buffer(command_buffer, ibuffer, 0, INDEX_TYPE_UINT32)
    cmd_bind_pipeline(command_buffer, PIPELINE_BIND_POINT_GRAPHICS, pipeline)
    cmd_pipeline_barrier(
        command_buffer,
        PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        PIPELINE_STAGE_TRANSFER_BIT,
        [],
        [],
        [
            ImageMemoryBarrier(
                AccessFlag(0),
                ACCESS_MEMORY_READ_BIT,
                IMAGE_LAYOUT_UNDEFINED,
                IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                vk.VK_QUEUE_FAMILY_IGNORED,
                vk.VK_QUEUE_FAMILY_IGNORED,
                local_image,
                ImageSubresourceRange(IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1),
            ),
        ],
    )
    cmd_begin_render_pass(
        command_buffer,
        RenderPassBeginInfo(
            render_pass,
            framebuffer,
            Rect2D(Offset2D(0, 0), Extent2D(width, height)),
            [vk.VkClearValue(vk.VkClearColorValue((0.1f0, 0.1f0, 0.15f0, 1.0f0)))],
        ),
        SUBPASS_CONTENTS_INLINE,
    )
    cmd_draw_indexed(command_buffer, length(idata), 1, 0, 0, 0)
    cmd_end_render_pass(command_buffer)
    cmd_pipeline_barrier(
        command_buffer,
        PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        PIPELINE_STAGE_TRANSFER_BIT,
        [],
        [],
        [
            ImageMemoryBarrier(
                ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
                ACCESS_MEMORY_READ_BIT,
                IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
                vk.VK_QUEUE_FAMILY_IGNORED,
                vk.VK_QUEUE_FAMILY_IGNORED,
                fb_image,
                ImageSubresourceRange(IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1),
            ),
        ],
    )
    cmd_copy_image(
        command_buffer,
        fb_image,
        IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        local_image,
        IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        [
            ImageCopy(
                ImageSubresourceLayers(IMAGE_ASPECT_COLOR_BIT, 0, 0, 1),
                Offset3D(0, 0, 0),
                ImageSubresourceLayers(IMAGE_ASPECT_COLOR_BIT, 0, 0, 1),
                Offset3D(0, 0, 0),
                Extent3D(width, height, 1),
            ),
        ],
    )
    end_command_buffer(command_buffer)

    # execute computation
    queue_submit(queue, [SubmitInfo([], [], [command_buffer], [])])
    GC.@preserve framebuffer imemory vmemory fb_image_memory fb_image_view command_buffer command_pool unwrap(
        queue_wait_idle(queue),
    )

    # map image into a Julia array
    image = download_data(Vector{eltype(colors)}, local_image_memory, (width, height))

    save(output_png, image)

    nothing
end

main(
    joinpath(@__DIR__, "render.png"),
    Point2f[(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)],
    [
        RGBA{Float16}(0.0, 0.0, 1.0, 0.0),
        RGBA{Float16}(0.0, 1.0, 0.0, 0.05),
        RGBA{Float16}(1.0, 1.0, 1.0, 0.4),
        RGBA{Float16}(1.0, 0.0, 0.0, 1.0),
    ],
)
