#scope_export

RHIGraphicsPipeline :: struct {
    pipeline: VkPipeline;
    pipeline_layout: VkPipelineLayout;
    static_sampler_descriptor_set_index: u32;
    static_sampler_descriptor_set_layout: VkDescriptorSetLayout;
    static_sampler_descriptor_pool: VkDescriptorPool;
    static_sampler_descriptor_set: VkDescriptorSet;
    static_samplers: [..] VkSampler;
}

rhi_graphics_pipeline_build :: (create_info: RHIGraphicsPipelineCreateInfo) -> RHIGraphicsPipeline {
    result: RHIGraphicsPipeline;
    array_reserve(*result.static_samplers, 16);

    stage_count := 0;
    shader_modules: [5] VkShaderModule;
    shader_stages: [5] VkPipelineShaderStageCreateInfo;
    render_pass: VkRenderPass;

    {
        if create_info.vertex_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.vertex_shader, .VERTEX_BIT);
            shader_module[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.hull_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.hull_shader, .TESSELLATION_CONTROL_BIT);
            shader_module[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.domain_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.domain_shader, .TESSELLATION_EVALUATION_BIT);
            shader_module[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.geometry_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.geometry_shader, .GEOMETRY_BIT);
            shader_module[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.pixel_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.pixel_shader, .FRAGMENT_BIT);
            shader_module[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        pipeline_rendering_create_info: VkPipelineRenderingCreateInfoKHR;
        color_attachment_formats: [8] VkFormat;

        dynamic_rendering_enabled := rhi_is_dynamic_rendering_ext_supported();

        if dynamic_rendering_enabled {
            for 0..create_info.attachment_formats.color_attachment_count-1 {
                color_attachment_formats[it] = rhi_translate(create_info.attachment_formats.color_attachment_formats[it]);
            }

            depth_stencil_format := rhi_translate(create_info.attachment_formats.depth_stencil_format);

            pipeline_rendering_create_info.viewMask = 0;
            pipeline_rendering_create_info.colorAttachmentCount = create_info.attachment_formats.color_attachment_count;
            pipeline_rendering_create_info.pColorAttachmentFormats = color_attachment_formats.data;
            pipeline_rendering_create_info.depthAttachmentFormat = depth_stencil_format;
            pipeline_rendering_create_info.stencilAttachmentFormat = depth_stencil_format;
        } else {
            assert(false);// nyi
        }

        result.static_sampler_descriptor_set_index = create_info.layout_create_info.static_sampler_set;

        create_pipeline_layout(create_info.layout_create_info, *result.pipeline_layout, *result.static_sampler_descriptor_set_layout, *result.static_sampler_descriptor_pool, *result.static_sampler_descriptor_set, *result.static_samplers);
    }

    return result;
}

rhi_graphics_pipeline_destroy :: (pipeline: RHIGraphicsPipeline) {
    vkDestroyPipeline(device, pipeline.pipeline, null);
    vkDestroyPipelineLayout(device, pipeline.pipeline_layout, null);
    vkDestroyDescriptorPool(device, pipeline.static_sampler_descriptor_pool, null);
    vkDestroyDescriptorSetLayout(device, pipeline.static_sampler_descriptor_set_layout, null);
}

#scope_file

create_shader_stage :: (shader: RHIShaderStageCreateInfo, stage: VkShaderStageFlagBits) -> VkShaderModule, VkPipelineShaderStageCreateInfo {
    
    path := tprint("%.spv", shader.path);
    shader_code := read_entire_file(path);
    defer free(shader_code);

    create_info := VkShaderModuleCreateInfo.{
        codeSize = xx shader_code.count,
        pCode = cast(*u32) shader_code.data
    };

    shader_module: VkShaderModule;
    vk_check_result(vkCreateShaderModule(device, *create_info, null, *shader_module));

    stage_create_info := VkPipelineShaderStageCreateInfo.{
        stage = stage,
        module = shader_module,
        pName = "main",
    };

    return shader_module, stage_create_info;
}

create_pipeline_layout :: (layout_create_info: RHIPipelineLayoutCreateInfo, out_pipeline_layout: *VkPipelineLayout, out_static_sampler_descriptor_set_layout: *VkDescriptorSetLayout, out_static_sampler_descriptor_pool: *VkDescriptorPool, out_static_sampler_descriptor_set: *VkDescriptorSet, out_static_samplers: *[..] VkSampler) {
    << out_static_sampler_descriptor_set_layout = VK_NULL_HANDLE;
    << out_static_sampler_descriptor_pool = VK_NULL_HANDLE;
    << out_static_sampler_descriptor_set = VK_NULL_HANDLE;
    out_static_samplers.count = 0;

    if layout_create_info.static_sampler_descs.count > 0 {
        static_sampler_bindings: [..] VkDescriptorSetLayoutBinding;
        static_sampler_bindings.allocator = temp;
        array_reserve(*static_sampler_bindings, 16);

        for 0..layout_create_info.static_sampler_descs.count-1 {
            static_sampler_desc := *layout_create_info.static_sampler_descs[it];

            sampler_create_info := VkSamplerCreateInfo.{
                magFilter = rhi_translate(static_sampler_desc.mag_filter),
                minFilter = rhi_translate(static_sampler_desc.min_filter),
                mipmapMode = rhi_translate(static_sampler_desc.mipmap_mode),
                addressModeU = rhi_translate(static_sampler_desc.address_mode_u),
                addressModeV = rhi_translate(static_sampler_desc.address_mode_v),
                addressModeW = rhi_translate(static_sampler_desc.address_mode_w),
                mipLodBias = static_sampler_desc.mip_lod_bias,
                anisotropyEnable = xx static_sampler_desc.anisotropy_enable,
                maxAnisotropy = static_sampler_desc.max_anisotropy,
                compareEnable = xx static_sampler_desc.compare_enable,
                compareOp = rhi_translate(static_sampler_desc.compare_op),
                minLod = static_sampler_desc.min_lod,
                maxLod = static_sampler_desc.max_lod,
                borderColor = rhi_translate(static_sampler_desc.border_color),
                unnormalizedCoordinates = xx static_sampler_desc.unnormalized_coordinates,
            };

            sampler: VkSampler;
            vk_check_result(vkCreateSampler(device, *sampler_create_info, null, *sampler));
            array_add(out_static_samplers, sampler);

            binding := VkDescriptorSetLayoutBinding.{
                binding = static_sampler_desc.binding,
                descriptorType = .SAMPLER,
                descriptorCount = 1,
                stageFlags = rhi_translate(static_sampler_desc.stage_flags),
                pImmutableSamplers = *((<<out_static_samplers)[out_static_samplers.count - 1]),
            };

            array_add(*static_sampler_bindings, binding);
        }

        sampler_set_layout_create_info := VkDescriptorSetLayoutCreateInfo.{
            bindingCount = xx layout_create_info.static_sampler_descs.count,
            pBindings = static_sampler_bindings.data,
        };

        vk_check_result(vkCreateDescriptorSetLayout(device, *sampler_set_layout_create_info, null, out_static_sampler_descriptor_set_layout));

        descriptor_pool_size := VkDescriptorPoolSize.{ descriptorCount = xx layout_create_info.static_sampler_descs.count };
        static_sampler_descriptor_pool_create_info := VkDescriptorPoolCreateInfo.{
            maxSets = 1,
            poolSizeCount = 1,
            pPoolSizes = *descriptor_pool_size,
        };

        vk_check_result(vkCreateDescriptorPool(device, *static_sampler_descriptor_pool_create_info, null, out_static_sampler_descriptor_pool));

        static_sampler_descriptor_set_alloc_info := VkDescriptorSetAllocateInfo.{
            descriptorPool = << out_static_sampler_descriptor_pool,
            descriptorSetCount = 1,
            pSetLayouts = out_static_sampler_descriptor_set_layout,
        };
        
        vk_check_result(vkAllocateDescriptorSets(device, *static_sampler_descriptor_set_alloc_info, out_static_sampler_descriptor_set));
    }

    vk_layouts: [5] VkDescriptorSetLayout;
    for 0..layout_create_info.descriptor_set_layout_count-1 {
        vk_layouts[it] = layout_create_info.descriptor_set_layout_decls[it].layout.handle;
    }
    if out_static_sampler_descriptor_set_layout != VK_NULL_HANDLE {
        vk_layouts[layout_create_info.static_sampler_set] = << out_static_sampler_descriptor_set_layout;
    }

    push_constant_range := VkPushConstantRange.{
        stageFlags = rhi_translate(layout_create_info.push_const_stage_flags),
        offset = 0,
        size = layout_create_info.push_const_range
    };

    pipeline_layout_create_info := VkPipelineLayoutCreateInfo.{
        setLayoutCount = xx ifx (<<out_static_sampler_descriptor_set_layout != VK_NULL_HANDLE) then (layout_create_info.descriptor_set_layout_count + 1) else (layout_create_info.descriptor_set_layout_count),
        pSetLayouts = vk_layouts.data,
        pushConstantRangeCount = xx ifx layout_create_info.push_const_range > 0 then 1 else 0,
        pPushConstantRanges = ifx layout_create_info.push_const_range > 0 then *push_constant_range else null,
    };

    vk_check_result(vkCreatePipelineLayout(device, *pipeline_layout_create_info, null, out_pipeline_layout));
}