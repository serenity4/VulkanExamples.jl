function find_memory_type(physical_device::PhysicalDevice, type_flag, properties::MemoryPropertyFlag)
    mem_props = get_physical_device_memory_properties(physical_device)
    indices = findall(x -> (x.property_flags & properties) == properties, mem_props.memory_types[1:mem_props.memory_type_count]) .- 1
    if isempty(indices)
        error("Could not find memory with properties $properties")
    else
        ind = findfirst(i -> type_flag & 1 << i ≠ 0, indices)
        if isnothing(ind)
            error("Could not find memory with type $type_flag")
        else
            indices[ind]
        end
    end
end

function Vulkan.DeviceMemory(device::Device, memory_requirements::MemoryRequirements, properties)
    DeviceMemory(device, memory_requirements.size, find_memory_type(device.physical_device, memory_requirements.memory_type_bits, properties))
end