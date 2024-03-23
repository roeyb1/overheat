#scope_export

RHIGraphicsPipelineCreateInfo :: struct {
    vertex_shader: RHIShaderStageCreateInfo;
    hull_shader: RHIShaderStageCreateInfo;
    domain_shader: RHIShaderStageCreateInfo;
    geometry_shader: RHIShaderStageCreateInfo;
    pixel_shader: RHIShaderStageCreateInfo;

    vertex_input_stage: RHIVertexInputState;
    input_assembly_state: RHIInputAssemblyState;
    tessellation_state: RHITessellationState;
    viewport_state: RHIViewportState;
    rasterization_state: RHIRasterizationState;
    multisample_state: RHIMultisampleState;
    depth_stencil_state: RHIDepthStencilState;
    blend_state: RHIBlendState;
    dynamic_state_flags: RHIDynamicStateFlags = 0;
    attachment_formats: RHIAttachmentFormats;
    layout_create_info: RHIPipelineLayoutCreateInfo;
}

rhi_set_vertex_shader :: (create_info: *RHIGraphicsPipelineCreateInfo, path: string) {
    create_info.vertex_shader.path = path;
}
rhi_set_hull_shader :: (create_info: *RHIGraphicsPipelineCreateInfo, path: string) {
    create_info.hull_shader.path = path;
}
rhi_set_domain_shader :: (create_info: *RHIGraphicsPipelineCreateInfo, path: string) {
    create_info.domain_shader.path = path;
}
rhi_set_geometry_shader :: (create_info: *RHIGraphicsPipelineCreateInfo, path: string) {
    create_info.geometry_shader.path = path;
}
rhi_set_pixel_shader :: (create_info: *RHIGraphicsPipelineCreateInfo, path: string) {
    create_info.pixel_shader.path = path;
}

rhi_set_vertex_binding_descs :: (create_info: *RHIGraphicsPipelineCreateInfo, descs: [] RHIVertexInputBindingDesc) {
    assert(descs.count < RHIVertexInputState.MAX_VERTEX_BINDING_DESCRIPTIONS);

    create_info.vertex_input_stage.vertex_binding_count = xx descs.count;
    for desc : descs {
        create_info.vertex_input_stage.vertex_binding_descs[it_index] = desc;
    }
}

rhi_set_vertex_attrib_descs :: (create_info: *RHIGraphicsPipelineCreateInfo, descs: [] RHIVertexInputAttributeDesc) {
    assert(descs.count < RHIVertexInputState.MAX_VERTEX_ATTRIBUTE_DESCRIPTIONS);

    create_info.vertex_input_stage.vertex_attribute_count = xx descs.count;
    for desc : descs {
        create_info.vertex_input_stage.vertex_attribute_descs[it_index] = desc;
    }
}

rhi_set_input_assembly_state :: (create_info: *RHIGraphicsPipelineCreateInfo, topology: RHIPrimitiveTopology, primitive_restart_enable: bool) {
    create_info.input_assembly_state.primitive_topology = topology;
    create_info.input_assembly_state.primitive_restart_enabled = xx primitive_restart_enable;
}

rhi_set_tesselation_state :: (create_info: *RHIGraphicsPipelineCreateInfo, patch_control_points: u32) {
    create_info.tessellation_state.patch_control_points = patch_control_points;
}

rhi_set_viewport_scissors :: (create_info: *RHIGraphicsPipelineCreateInfo, viewports: [] RHIViewport, scissors: [] RHIRect) {
    assert(viewports.count < RHIViewportState.MAX_VIEWPORTS && scissors.count == viewports.count);

    create_info.viewport_state.viewport_count = xx viewports.count;
    for 0..viewports.count-1 {
        create_info.viewport_state.viewports[it] = viewports[it];
        create_info.viewport_state.scissors[it] = scissors[it];
    }
}


rhi_set_depth_clamp_enable :: (create_info: *RHIGraphicsPipelineCreateInfo, depth_clamp_enable: bool) {
    create_info.rasterization_state.depth_clamp_enable = xx depth_clamp_enable;
}

rhi_set_rasterizer_discard_enable :: (create_info: *RHIGraphicsPipelineCreateInfo, rasterizer_discard_enable: bool) {
    create_info.rasterization_state.rasterizer_discard_enable = xx rasterizer_discard_enable;
}

rhi_set_polygon_and_cull_mode :: (create_info: *RHIGraphicsPipelineCreateInfo, polygon_mode: RHIPolygonMode, cull_mode: RHICullModeFlags, front_face: RHIFrontFace) {
    create_info.rasterization_state.polygon_mode = polygon_mode;
    create_info.rasterization_state.cull_mode = cull_mode;
    create_info.rasterization_state.front_face = front_face;
}

rhi_set_depth_bias :: (create_info: *RHIGraphicsPipelineCreateInfo, enable: bool, constant_factor: float, clamp: float, slope_factor: float) {
    create_info.rasterization_state.depth_bias_enable = xx enable;
    create_info.rasterization_state.depth_bias_constant_factor = constant_factor;
    create_info.rasterization_state.depth_bias_clamp = clamp;
    create_info.rasterization_state.depth_bias_slope_factor = slope_factor;
}

rhi_set_line_width :: (create_info: *RHIGraphicsPipelineCreateInfo, line_width: float) {
    create_info.rasterization_state.line_width = line_width;
}

rhi_set_multisample_state :: (create_info: *RHIGraphicsPipelineCreateInfo, rasterization_samples: RHISampleCount, sample_shading_enable: bool, min_sample_shading: float, sample_mask: u32, alpha_to_coverage_enable: bool, alpha_to_one_enable: bool) {
    create_info.multisample_state.rasterization_samples = rasterization_samples;
    create_info.multisample_state.sample_shading_enable = xx sample_shading_enable;
    create_info.multisample_state.min_sample_shading = min_sample_shading;
    create_info.multisample_state.alpha_to_coverage_enable = xx alpha_to_coverage_enable;
    create_info.multisample_state.alpha_to_one_enable = xx alpha_to_one_enable;
}

rhi_set_depth_test :: (create_info: *RHIGraphicsPipelineCreateInfo, depth_test_enable: bool, depth_write_enable: bool, compare_op: RHICompareOp) {
    create_info.depth_stencil_state.depth_test_enable = xx depth_test_enable;
    create_info.depth_stencil_state.depth_write_enable = xx depth_write_enable;
    create_info.depth_stencil_state.depth_compare_op = compare_op;
}

rhi_set_stencil_test :: (create_info: *RHIGraphicsPipelineCreateInfo, stencil_test_enable: bool, front: RHIStencilOpState, back: RHIStencilOpState) {
    create_info.depth_stencil_state.stencil_test_enable = xx stencil_test_enable;
    create_info.depth_stencil_state.front = front;
    create_info.depth_stencil_state.back = back;
}

rhi_set_depth_bounds_test :: (create_info: *RHIGraphicsPipelineCreateInfo, depth_bounds_test: bool, min_depth_bounds: float, max_depth_bounds: float) {
    create_info.depth_stencil_state.depth_bounds_test_enable = xx depth_bounds_test;
    create_info.depth_stencil_state.min_depth_bounds = min_depth_bounds;
    create_info.depth_stencil_state.max_depth_bounds = max_depth_bounds;
}

rhi_set_blend_state_logic_op :: (create_info: *RHIGraphicsPipelineCreateInfo, logic_op_enable: bool, logic_op: RHILogicOp) {
    create_info.blend_state.logic_op_enable = xx logic_op_enable;
    create_info.blend_state.logic_op = logic_op;
}

rhi_set_blend_constants :: (create_info: *RHIGraphicsPipelineCreateInfo, blend_consts: [] float) {
    assert(blend_consts.count == 4);
    for 0..blend_consts.count-1 {
        create_info.blend_state.blend_constants[it] = blend_consts[it];
    }
}

rhi_set_color_blend_attachment :: (create_info: *RHIGraphicsPipelineCreateInfo, color_blend_attachments: [] RHIPipelineColorBlendAttachmentState) {
    assert(color_blend_attachments.count < 8);
    create_info.blend_state.attachment_count = xx color_blend_attachments.count;
    for attach : color_blend_attachments {
        create_info.blend_state.attachments[it_index] = attach;
    }
}

rhi_set_dynamic_state :: (create_info: *RHIGraphicsPipelineCreateInfo, dynamic_state_flags: RHIDynamicStateFlags) {
    create_info.dynamic_state_flags = dynamic_state_flags;
}

rhi_set_color_attachment_formats :: (create_info: *RHIGraphicsPipelineCreateInfo, formats: [] RHIFormat) {
    assert(formats.count < 8);
    create_info.attachment_formats.color_attachment_count = xx formats.count;
    for format : formats {
        create_info.attachment_formats.color_attachment_formats[it_index] = format;
    }
}

rhi_set_depth_stencil_attachment_format :: (create_info: *RHIGraphicsPipelineCreateInfo, format: RHIFormat) {
    create_info.attachment_formats.depth_stencil_format = format;
}

rhi_set_pipeline_layout_desc :: (create_info: *RHIGraphicsPipelineCreateInfo, set_layout_decls: [] RHIDescriptorSetLayoutDecl, push_const_range: u32, push_const_stage_flags: RHIShaderStageFlags, static_sampler_descs: [] RHIStaticSamplerDesc, static_sampler_set: u32) {
    assert(set_layout_decls.count < 4);
    create_info.layout_create_info.descriptor_set_layout_count = xx set_layout_decls.count;
    for layout_decl : set_layout_decls {
        create_info.layout_create_info.descriptor_set_layout_decls[it_index] = layout_decl;
    }

    create_info.layout_create_info.push_const_range = push_const_range;
    create_info.layout_create_info.push_const_stage_flags = push_const_stage_flags;
    create_info.layout_create_info.static_sampler_descs = static_sampler_descs;
    create_info.layout_create_info.static_sampler_set = static_sampler_set;
}

