#scope_export

RHIPipeline :: struct {
    pipeline: VkPipeline;
    pipeline_layout: VkPipelineLayout;
    static_sampler_descriptor_set_index: s32;
    static_sampler_descriptor_set_layout: VkDescriptorSetLayout;
    static_sampler_descriptor_pool: VkDescriptorPool;
    static_sampler_descriptor_set: VkDescriptorSet;
    static_samplers: [..] VkSampler;
}

RHIGraphicsPipeline :: struct {
    using #as p: RHIPipeline;
}

RHIComputePipeline :: struct {
    using #as p: RHIPipeline;
}

rhi_graphics_pipeline_build :: (create_info: RHIGraphicsPipelineCreateInfo) -> RHIGraphicsPipeline {
    translate :: (state: RHIStencilOpState) -> VkStencilOpState {
        return VkStencilOpState.{
            failOp = rhi_translate(state.fail_op),
            passOp = rhi_translate(state.pass_op),
            depthFailOp = rhi_translate(state.depth_fail_op),
            compareOp = rhi_translate(state.compare_op),
            compareMask = state.compare_mask,
            writeMask = state.write_mask,
            reference = state.reference,
        };
    }

    translate :: (dynamic_state_flags: RHIDynamicStateFlags, out_dynamic_states: [] VkDynamicState) -> u32 {
        state_count: u32 = 0;
        if test_flag_bit(dynamic_state_flags, .VIEWPORT_BIT) {
            out_dynamic_states[state_count] = .VIEWPORT;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .SCISSOR_BIT) {
            out_dynamic_states[state_count] = .SCISSOR;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .LINE_WIDTH_BIT) {
            out_dynamic_states[state_count] = .LINE_WIDTH;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .DEPTH_BIAS_BIT) {
            out_dynamic_states[state_count] = .DEPTH_BIAS;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .BLEND_CONSTANTS_BIT) {
            out_dynamic_states[state_count] = .BLEND_CONSTANTS;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .DEPTH_BOUNDS_BIT) {
            out_dynamic_states[state_count] = .DEPTH_BOUNDS;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .STENCIL_COMPARE_MASK_BIT) {
            out_dynamic_states[state_count] = .STENCIL_COMPARE_MASK;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .STENCIL_WRITE_MASK_BIT) {
            out_dynamic_states[state_count] = .STENCIL_WRITE_MASK;
            state_count += 1;
        }
        if test_flag_bit(dynamic_state_flags, .STENCIL_REFERENCE_BIT) {
            out_dynamic_states[state_count] = .STENCIL_REFERENCE;
            state_count += 1;
        }

        return state_count;
    }

    result: RHIGraphicsPipeline;
    array_reserve(*result.static_samplers, 16);

    stage_count := 0;
    shader_modules: [5] VkShaderModule;
    shader_stages: [5] VkPipelineShaderStageCreateInfo;
    render_pass: VkRenderPass;

    {
        if create_info.vertex_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.vertex_shader, .VERTEX_BIT);
            shader_modules[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.hull_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.hull_shader, .TESSELLATION_CONTROL_BIT);
            shader_modules[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.domain_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.domain_shader, .TESSELLATION_EVALUATION_BIT);
            shader_modules[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.geometry_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.geometry_shader, .GEOMETRY_BIT);
            shader_modules[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }

        if create_info.pixel_shader.path.count > 0 {
            shader_module, shader_stage := create_shader_stage(create_info.pixel_shader, .FRAGMENT_BIT);
            shader_modules[stage_count] = shader_module;
            shader_stages[stage_count] = shader_stage;
            stage_count += 1;
        }
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
        pipeline_rendering_create_info.stencilAttachmentFormat = ifx rhi_is_stencil_format(create_info.attachment_formats.depth_stencil_format) then depth_stencil_format else .UNDEFINED;
    } else {
        assert(false);// nyi
    }

    result.static_sampler_descriptor_set_index = create_info.layout_create_info.static_sampler_set;

    create_pipeline_layout(create_info.layout_create_info, *result.pipeline_layout, *result.static_sampler_descriptor_set_layout, *result.static_sampler_descriptor_pool, *result.static_sampler_descriptor_set, *result.static_samplers);

    vertex_input_state: VkPipelineVertexInputStateCreateInfo;
    vertex_binding_descs: [RHIVertexInputState.MAX_VERTEX_BINDING_DESCRIPTIONS] VkVertexInputBindingDescription;
    vertex_attribute_descs: [RHIVertexInputState.MAX_VERTEX_ATTRIBUTE_DESCRIPTIONS] VkVertexInputAttributeDescription;
    {
        vertex_input_state.vertexBindingDescriptionCount = create_info.vertex_input_state.vertex_binding_count;
        vertex_input_state.pVertexBindingDescriptions = vertex_binding_descs.data;
        vertex_input_state.vertexAttributeDescriptionCount = create_info.vertex_input_state.vertex_attribute_count;
        vertex_input_state.pVertexAttributeDescriptions = vertex_attribute_descs.data;

        for 0..create_info.vertex_input_state.vertex_binding_count-1 {
            vertex_binding_descs[it] = VkVertexInputBindingDescription.{
                binding = create_info.vertex_input_state.vertex_binding_descs[it].binding,
                stride = create_info.vertex_input_state.vertex_binding_descs[it].stride,
                inputRate = rhi_translate(create_info.vertex_input_state.vertex_binding_descs[it].input_rate),
            };
        }

        for 0..create_info.vertex_input_state.vertex_attribute_count-1 {
            vertex_attribute_descs[it] = VkVertexInputAttributeDescription.{
                location = create_info.vertex_input_state.vertex_attribute_descs[it].location,
                binding = create_info.vertex_input_state.vertex_attribute_descs[it].binding,
                format = rhi_translate(create_info.vertex_input_state.vertex_attribute_descs[it].format),
                offset = create_info.vertex_input_state.vertex_attribute_descs[it].offset,
            };
        }
    }

    input_assembly_state := VkPipelineInputAssemblyStateCreateInfo.{
        topology = rhi_translate(create_info.input_assembly_state.primitive_topology),
        primitiveRestartEnable = create_info.input_assembly_state.primitive_restart_enabled,
    };

    tessellation_state := VkPipelineTessellationStateCreateInfo.{
        patchControlPoints = create_info.tessellation_state.patch_control_points,
    };

    viewport_state := VkPipelineViewportStateCreateInfo.{
        viewportCount = create_info.viewport_state.viewport_count,
        pViewports = cast(*VkViewport) create_info.viewport_state.viewports.data,
        scissorCount = create_info.viewport_state.viewport_count,
        pScissors = cast(*VkRect2D) create_info.viewport_state.scissors.data,
    };

    rasterization_state := VkPipelineRasterizationStateCreateInfo.{
        depthClampEnable = create_info.rasterization_state.depth_clamp_enable,
        rasterizerDiscardEnable = create_info.rasterization_state.rasterizer_discard_enable,
        polygonMode = rhi_translate(create_info.rasterization_state.polygon_mode),
        cullMode = rhi_translate(create_info.rasterization_state.cull_mode),
        frontFace = rhi_translate(create_info.rasterization_state.front_face),
        depthBiasEnable = create_info.rasterization_state.depth_bias_enable,
        depthBiasConstantFactor = create_info.rasterization_state.depth_bias_constant_factor,
        depthBiasClamp = create_info.rasterization_state.depth_bias_clamp,
        depthBiasSlopeFactor = create_info.rasterization_state.depth_bias_slope_factor,
        lineWidth = create_info.rasterization_state.line_width,
    };

    multisample_state := VkPipelineMultisampleStateCreateInfo.{
        rasterizationSamples = cast, force(VkSampleCountFlagBits) create_info.multisample_state.rasterization_samples,
        sampleShadingEnable = create_info.multisample_state.sample_shading_enable,
        minSampleShading = create_info.multisample_state.min_sample_shading,
        pSampleMask = *create_info.multisample_state.sample_mask,
        alphaToCoverageEnable = create_info.multisample_state.alpha_to_coverage_enable,
        alphaToOneEnable = create_info.multisample_state.alpha_to_one_enable,
    };

    depth_stencil_state := VkPipelineDepthStencilStateCreateInfo.{
        depthTestEnable = create_info.depth_stencil_state.depth_test_enable,
        depthWriteEnable = create_info.depth_stencil_state.depth_write_enable,
        depthCompareOp = rhi_translate(create_info.depth_stencil_state.depth_compare_op),
        depthBoundsTestEnable = create_info.depth_stencil_state.depth_bounds_test_enable,
        stencilTestEnable = create_info.depth_stencil_state.stencil_test_enable,
        front = translate(create_info.depth_stencil_state.front),
        back = translate(create_info.depth_stencil_state.back),
        minDepthBounds = create_info.depth_stencil_state.min_depth_bounds,
        maxDepthBounds = create_info.depth_stencil_state.max_depth_bounds,
    };

    color_blend_state: VkPipelineColorBlendStateCreateInfo;
    color_blend_attachment_states: [8] VkPipelineColorBlendAttachmentState;
    {
        color_blend_state.logicOpEnable = create_info.blend_state.logic_op_enable;
        color_blend_state.logicOp = rhi_translate(create_info.blend_state.logic_op);
        color_blend_state.attachmentCount = create_info.blend_state.attachment_count;
        color_blend_state.pAttachments = color_blend_attachment_states.data;
        color_blend_state.blendConstants[0] = create_info.blend_state.blend_constants[0];
        color_blend_state.blendConstants[1] = create_info.blend_state.blend_constants[1];
        color_blend_state.blendConstants[2] = create_info.blend_state.blend_constants[2];
        color_blend_state.blendConstants[3] = create_info.blend_state.blend_constants[3];

        for 0..create_info.blend_state.attachment_count-1 {
            color_blend_attachment_states[it] = VkPipelineColorBlendAttachmentState.{
                blendEnable = xx create_info.blend_state.attachments[it].blend_enable,
                srcColorBlendFactor = rhi_translate(create_info.blend_state.attachments[it].src_color_blend_factor),
                dstColorBlendFactor = rhi_translate(create_info.blend_state.attachments[it].dst_color_blend_factor),
                colorBlendOp = rhi_translate(create_info.blend_state.attachments[it].color_blend_op),
                srcAlphaBlendFactor = rhi_translate(create_info.blend_state.attachments[it].src_alpha_blend_factor),
                dstAlphaBlendFactor = rhi_translate(create_info.blend_state.attachments[it].dst_alpha_blend_factor),
                alphaBlendOp = rhi_translate(create_info.blend_state.attachments[it].alpha_blend_op),
                colorWriteMask = rhi_translate(create_info.blend_state.attachments[it].color_write_mask),
            };
        }
    }


    dynamic_states: [9] VkDynamicState;
    dynamic_states_count := translate(create_info.dynamic_state_flags, dynamic_states);
    dynamic_state := VkPipelineDynamicStateCreateInfo.{
        dynamicStateCount = dynamic_states_count,
        pDynamicStates = dynamic_states.data,
    };

    pipeline_create_info := VkGraphicsPipelineCreateInfo.{
        pNext = ifx rhi_is_dynamic_rendering_ext_supported() then *pipeline_rendering_create_info else null,
        flags = 0,
        stageCount = xx stage_count,
        pStages = shader_stages.data,
        pVertexInputState = *vertex_input_state,
        pInputAssemblyState = *input_assembly_state,
        pTessellationState = *tessellation_state,
        pViewportState = *viewport_state,
        pRasterizationState = *rasterization_state,
        pMultisampleState = *multisample_state,
        pDepthStencilState = *depth_stencil_state,
        pColorBlendState = *color_blend_state,
        pDynamicState = *dynamic_state,
        layout = result.pipeline_layout,
        renderPass = render_pass,
        subpass = 0,
        basePipelineHandle = VK_NULL_HANDLE,
        basePipelineIndex = 0,
    };

    vk_check_result(vkCreateGraphicsPipelines(device, VK_NULL_HANDLE, 1, *pipeline_create_info, null, *result.pipeline));


    for 0..stage_count-1 {
        vkDestroyShaderModule(device, shader_modules[it], null);
    }

    return result;
}

rhi_graphics_pipeline_destroy :: (pipeline: RHIGraphicsPipeline) {
    for sampler : pipeline.static_samplers {
        vkDestroySampler(device, sampler, null);
    }
    array_free(pipeline.static_samplers);

    vkDestroyPipeline(device, pipeline.pipeline, null);
    vkDestroyPipelineLayout(device, pipeline.pipeline_layout, null);
    vkDestroyDescriptorPool(device, pipeline.static_sampler_descriptor_pool, null);
    vkDestroyDescriptorSetLayout(device, pipeline.static_sampler_descriptor_set_layout, null);
}

rhi_compute_pipeline_build :: (create_info: RHIComputePipelineCreateInfo) -> RHIComputePipeline {
    compute_module:, compute_stage_info := create_shader_stage(create_info.compute_shader, .COMPUTE_BIT);
    defer vkDestroyShaderModule(device, compute_module, null);

    result: RHIComputePipeline;
    array_reserve(*result.static_samplers, 16);

    create_pipeline_layout(create_info.layout_create_info, *result.pipeline_layout, *result.static_sampler_descriptor_set_layout, *result.static_sampler_descriptor_pool, *result.static_sampler_descriptor_set, *result.static_samplers);

    vk_create_info := VkComputePipelineCreateInfo.{
        stage = compute_stage_info,
        layout = result.pipeline_layout,
    };

    vk_check_result(vkCreateComputePipelines(device, null, 1, *vk_create_info, null, *result.pipeline));
    
    return result;
}

rhi_compute_pipeline_destroy :: (pipeline: RHIComputePipeline) {
    for sampler : pipeline.static_samplers {
        vkDestroySampler(device, sampler, null);
    }
    array_free(pipeline.static_samplers);

    vkDestroyPipeline(device, pipeline.pipeline, null);
    vkDestroyPipelineLayout(device, pipeline.pipeline_layout, null);
    vkDestroyDescriptorPool(device, pipeline.static_sampler_descriptor_pool, null);
    vkDestroyDescriptorSetLayout(device, pipeline.static_sampler_descriptor_set_layout, null);
}

#scope_file

create_shader_stage :: (shader: RHIShaderStageCreateInfo, stage: VkShaderStageFlagBits) -> VkShaderModule, VkPipelineShaderStageCreateInfo {
    
    path := tprint("assets/shaders/compiled/%.spv", shader.path);
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
    if (<<out_static_sampler_descriptor_set_layout != VK_NULL_HANDLE) {
        vk_layouts[layout_create_info.static_sampler_set] = << out_static_sampler_descriptor_set_layout;
    }

    push_constant_range := VkPushConstantRange.{
        stageFlags = rhi_translate(layout_create_info.push_const_stage_flags),
        offset = 0,
        size = layout_create_info.push_const_range
    };


    set_layout_count := ifx (<<out_static_sampler_descriptor_set_layout != VK_NULL_HANDLE) then (layout_create_info.descriptor_set_layout_count + 1) else (layout_create_info.descriptor_set_layout_count);
    pipeline_layout_create_info := VkPipelineLayoutCreateInfo.{
        setLayoutCount = xx set_layout_count,
        pSetLayouts = vk_layouts.data,
        pushConstantRangeCount = xx ifx layout_create_info.push_const_range > 0 then 1 else 0,
        pPushConstantRanges = ifx layout_create_info.push_const_range > 0 then *push_constant_range else null,
    };

    vk_check_result(vkCreatePipelineLayout(device, *pipeline_layout_create_info, null, out_pipeline_layout));
}