#scope_export

MAX_STORAGE_BUFFERS: u32 : 1024;
MAX_SAMPLED_IMAGES: u32 : 1024;
MAX_SAMPLERS: u32 : 1024;
MAX_UNIFORM_BUFFERS: u32 : 1024;

// These correspond exactly to the binding locations in the shaders
BindingLocations :: enum u32 {
    STORAGE_BUFFERS :: 0;
    TEXTURES :: 1;
    SAMPLERS :: 2;
    UNIFORMS :: 3;
}

BindlessSet :: struct {
    pool: VkDescriptorPool;
    layout: VkDescriptorSetLayout;
    set: VkDescriptorSet;
}

bindless: BindlessSet;

init_bindless_descriptor_set :: () {
    descriptor_indexing_properties: VkPhysicalDeviceDescriptorIndexingProperties;
    physical_device_properties2 := VkPhysicalDeviceProperties2.{
        pNext = *descriptor_indexing_properties,
    };
    vkGetPhysicalDeviceProperties2(physical_device, *physical_device_properties2);

    device_max_storage_buffers := descriptor_indexing_properties.maxPerStageDescriptorUpdateAfterBindStorageBuffers;
    device_max_sampled_images := descriptor_indexing_properties.maxPerStageDescriptorUpdateAfterBindSampledImages;
    device_max_storage_images := descriptor_indexing_properties.maxPerStageDescriptorUpdateAfterBindStorageImages;
    device_max_samplers := descriptor_indexing_properties.maxPerStageDescriptorUpdateAfterBindSamplers;
    device_max_uniform_buffers := descriptor_indexing_properties.maxPerStageDescriptorUpdateAfterBindUniformBuffers;


    num_storage_buffers := MAX_STORAGE_BUFFERS;
    if device_max_storage_buffers < MAX_STORAGE_BUFFERS {
        log_warning("Device only supports a maximum of % storage buffers. % requested", device_max_storage_buffers, MAX_STORAGE_BUFFERS);
        num_storage_buffers = device_max_storage_buffers;
    }
    num_sampled_images := MAX_SAMPLED_IMAGES;
    if device_max_sampled_images < MAX_SAMPLED_IMAGES {
        log_warning("Device only supports a maximum of % sampled images. % requested", device_max_sampled_images, MAX_SAMPLED_IMAGES);
        num_sampled_images = device_max_sampled_images;
    }
    num_samplers := MAX_SAMPLERS;
    if device_max_samplers < MAX_SAMPLERS {
        log_warning("Device only supports a maximum of % samplers. % requested", device_max_samplers, MAX_SAMPLERS);
        num_samplers = device_max_samplers;
    }
    num_uniform_buffers := MAX_UNIFORM_BUFFERS;
    if device_max_uniform_buffers < MAX_UNIFORM_BUFFERS {
        log_warning("Device only supports a maximum of % uniform buffers. % requested", device_max_uniform_buffers, MAX_UNIFORM_BUFFERS);
        num_uniform_buffers = device_max_uniform_buffers;
    }
    
    pool_sizes := VkDescriptorPoolSize.[
        .{
            type = .STORAGE_BUFFER,
            descriptorCount = num_storage_buffers,
        },
        .{
            type = .SAMPLED_IMAGE,
            descriptorCount = num_sampled_images,
        },
        .{
            type = .SAMPLER,
            descriptorCount = num_samplers,
        },
        .{
            type = .UNIFORM_BUFFER,
            descriptorCount = num_uniform_buffers,
        }
    ];

    pool_create_info := VkDescriptorPoolCreateInfo.{
        flags = .FREE_DESCRIPTOR_SET_BIT | .UPDATE_AFTER_BIND_BIT,
        maxSets = 1,
        poolSizeCount = pool_sizes.count,
        pPoolSizes = pool_sizes.data,
    };

    result := vkCreateDescriptorPool(device, *pool_create_info, null, *bindless.pool);
    assert(result == .SUCCESS);

    layout_bindings := VkDescriptorSetLayoutBinding.[
        .{
            binding = xx BindingLocations.STORAGE_BUFFERS,
            descriptorType = .STORAGE_BUFFER,
            descriptorCount = num_storage_buffers,
            stageFlags = .ALL,
        },
        .{
            binding = xx BindingLocations.TEXTURES,
            descriptorType = .SAMPLED_IMAGE,
            descriptorCount = num_sampled_images,
            stageFlags = .ALL,
        },
        .{
            binding = xx BindingLocations.SAMPLERS,
            descriptorType = .SAMPLER,
            descriptorCount = num_samplers,
            stageFlags = .ALL,
        },
        .{
            binding = xx BindingLocations.UNIFORMS,
            descriptorType = .UNIFORM_BUFFER,
            descriptorCount = num_uniform_buffers,
            stageFlags = .ALL,
        }
    ];

    flags := VkDescriptorBindingFlags.[
        .PARTIALLY_BOUND_BIT,
        .PARTIALLY_BOUND_BIT,
        .PARTIALLY_BOUND_BIT,
        .PARTIALLY_BOUND_BIT,
        .PARTIALLY_BOUND_BIT,
    ];

    binding_flags := VkDescriptorSetLayoutBindingFlagsCreateInfo.{
        bindingCount = layout_bindings.count,
        pBindingFlags = flags.data,
    };

    layout_create_info := VkDescriptorSetLayoutCreateInfo.{
        bindingCount = layout_bindings.count,
        pBindings = layout_bindings.data,
        pNext = *binding_flags,
        flags = .UPDATE_AFTER_BIND_POOL_BIT,
    };

    result = vkCreateDescriptorSetLayout(device, *layout_create_info, null, *bindless.layout);
    assert(result == .SUCCESS);

    set_alloc_info := VkDescriptorSetAllocateInfo.{
        descriptorPool = bindless.pool,
        descriptorSetCount = 1,
        pSetLayouts = *bindless.layout,
    };

    result = vkAllocateDescriptorSets(device, *set_alloc_info, *bindless.set);
    assert(result == .SUCCESS);
}

destroy_bindless_descriptor_set :: () {
    vkDestroyDescriptorSetLayout(device, bindless.layout, null);
    vkDestroyDescriptorPool(device, bindless.pool, null);
}