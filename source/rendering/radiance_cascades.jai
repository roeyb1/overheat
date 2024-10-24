init_radiance_cascades_pipeline :: (bindless_set_layout: *RHIDescriptorSetLayout) {
    render_target_formats := RHIFormat.[
        .R16G16B16A16_SFLOAT,
    ];

    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = false,
            src_color_blend_factor = .SRC_ALPHA,
            dst_color_blend_factor = .ONE_MINUS_SRC_ALPHA,
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ONE,
            dst_alpha_blend_factor = .ONE,
            alpha_blend_op = .ADD,
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[];

    binding_descs := RHIVertexInputBindingDesc.[];

    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT), // input tex
    ];

    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{bindless_set_layout, used_bindless_bindings }
    ];

    static_samplers := RHIStaticSamplerDesc.[
        rhi_static_linear_clamp_sampler(0, 0, .PIXEL_BIT),
    ];

    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "fullscreen_vs");
    rhi_set_pixel_shader(*create_info, "radiance_cascades_ps");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_color_attachment_formats(*create_info, render_target_formats);

    push_const_size: u32 = size_of(Radiance_Cascades_Push_Consts);

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 1);
    
    radiance_cascades_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_radiance_cascades_pipeline :: () {
    rhi_graphics_pipeline_destroy(radiance_cascades_pipeline);
}

create_transient_rc_texture :: (rg: *RenderGraph, resolution: Extent2D, debug_name: string) -> RDGResourceViewHandle {
    rc_image_view: RDGResourceViewHandle;
    rc_image_desc := RDGImageDescription.{
        debug_name = debug_name,
        width = resolution.width,
        height = resolution.height,
        format = .R16G16B16A16_SFLOAT,
        usage_flags = .COLOR_ATTACHMENT_BIT | .CLEAR_BIT,
    };

    rc_image_handle := rdg_create_image(rg, rc_image_desc);
    rc_image_view = rdg_create_image_view(rg, rc_image_handle, tprint("% View", debug_name));

    return rc_image_view;
}

render_radiance_cascades :: (rg: *RenderGraph, view_data: *RenderViewData, df_input: RDGResourceViewHandle, lightmap_input: RDGResourceViewHandle) -> RDGResourceViewHandle {
    render_extent := Vector2.{ cast(float) view_data.scene_texture_size.width, cast(float) view_data.scene_texture_size.height };

    render_linear :: 1;
    render_interval := length(.{render_linear, render_linear});
    cascade_count := ceil(log(length(render_extent)) / log(4));

    cascade_interval := round_up_multiple_of_n(render_interval, 2);
    cascade_linear := round_up_power_2(render_linear);

    error_rate := pow(2., cascade_count - 1);
    errorx := ceil(render_extent.x / error_rate);
    errory := ceil(render_extent.y / error_rate);
    render_extent.x = errorx * error_rate;
    render_extent.y = errory * error_rate;

    cascades_extent := Extent2D.{cast(u32) floor(render_extent.x / cascade_linear), cast(u32) floor(render_extent.y / cascade_linear)};

    rc_a := create_transient_rc_texture(rg, Extent2D.{xx render_extent.x, xx render_extent.y}, "Radiance Cascades RT A");
    rc_b := create_transient_rc_texture(rg, Extent2D.{xx render_extent.x, xx render_extent.y}, "Radiance Cascades RT B");

    clear_color: RHIClearColorValue;
    clear_color._float32 = .[0, 0, 0, 0];
    add_clear_image_pass(rg, rc_a, clear_color);
    add_clear_image_pass(rg, rc_b, clear_color);

    current_rt := rc_a;
    previous_rt := rc_b;

    for < (cast(s64)cascade_count)-1..0 {
        pass_data := rdg_allocate_pass_data(rg, Radiance_Cascades_Pass_Data);
        pass_data.view_data = view_data;
        pass_data.cascades_extent = cascades_extent;
        pass_data.render_extent = render_extent;

        pass_data.df_input = df_input;
        pass_data.lightmap_input = lightmap_input;
        pass_data.previous_rt = previous_rt;
        pass_data.rc_rt = current_rt;

        pass_data.cascade_index = cast(u32) it;
        pass_data.cascade_count = cast(u32) cascade_count;
        pass_data.cascade_interval = render_interval;
        pass_data.cascade_linear = render_linear;

        rc_pass_usages := RDGResourceUsageDesc.[
            .{pass_data.rc_rt,          .{resource_state = .WRITE_COLOR_ATTACHMENT, stage_mask = .PIXEL_SHADER_BIT}, .{}},
            .{pass_data.previous_rt,    .{resource_state = .READ_RESOURCE,          stage_mask = .PIXEL_SHADER_BIT}, .{}},
            .{df_input,                 .{resource_state = .READ_RESOURCE,          stage_mask = .PIXEL_SHADER_BIT}, .{}},
            .{lightmap_input,           .{resource_state = .READ_RESOURCE,          stage_mask = .PIXEL_SHADER_BIT}, .{}},
        ];

        rdg_add_pass(rg, tprint("Radiance Cascades Iter: %", it), .GRAPHICS, rc_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
            pass_data := cast(*Radiance_Cascades_Pass_Data) pass_data_ptr;
            view_data := pass_data.view_data;

            rc_rt_buffer_desc := RHIColorAttachmentDesc.{
                image_view = rdg_get_image_view(pass_data.rc_rt),
                load_op = .CLEAR,
                store_op = .STORE,
            };

            render_rect := RHIRect.{ .{0, 0}, .{ xx pass_data.render_extent.x, xx pass_data.render_extent.y }};
            viewport := RHIViewport.{ 0, 0, pass_data.render_extent.x, pass_data.render_extent.y, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{ xx pass_data.render_extent.x, xx pass_data.render_extent.y }};

            // seed the input into RT A:
            rhi_cmd_begin_renderpass(cmd_list, .[rc_rt_buffer_desc], null, render_rect, true);
            {
                rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
                rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

                rhi_cmd_bind_pipeline(cmd_list, *radiance_cascades_pipeline);

                descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.bindless_set];
                rhi_cmd_bind_descriptor_sets(cmd_list, *radiance_cascades_pipeline, 0, descriptor_sets, .[]);

                push_const: Radiance_Cascades_Push_Consts = .{
                    cascade_extent = Vector2.{ cast(float) pass_data.cascades_extent.width, cast(float) pass_data.cascades_extent.height},
                    render_extent = pass_data.render_extent,
                    df_input = rdg_get_bindless_handle(pass_data.df_input, .TEXTURE),
                    lightmap_input = rdg_get_bindless_handle(pass_data.lightmap_input, .TEXTURE),
                    previous_rt = rdg_get_bindless_handle(pass_data.previous_rt, .TEXTURE),
                    cascade_index = cast(float) pass_data.cascade_index,
                    cascade_count = cast(float) pass_data.cascade_count,
                    cascade_linear = cast(float) pass_data.cascade_linear,
                    cascade_interval = cast(float) pass_data.cascade_interval,
                };
                rhi_cmd_push_constants(cmd_list, *radiance_cascades_pipeline, .PIXEL_BIT, 0, size_of(Radiance_Cascades_Push_Consts), *push_const);

                rhi_cmd_draw(cmd_list, 3, 1, 0, 0);
            }
            rhi_cmd_end_renderpass(cmd_list);
        });

        previous_rt, current_rt = swap(previous_rt, current_rt);
    }

    return previous_rt;
}

#scope_file

Radiance_Cascades_Pass_Data :: struct {
    view_data: *RenderViewData;

    cascades_extent: Extent2D;
    render_extent: Vector2;

    df_input: RDGResourceViewHandle;
    lightmap_input: RDGResourceViewHandle;
    rc_rt: RDGResourceViewHandle;
    previous_rt: RDGResourceViewHandle;

    cascade_index: u32;
    cascade_count: u32;
    cascade_linear: float;
    cascade_interval: float;
}

Radiance_Cascades_Push_Consts :: struct {
    cascade_extent: Vector2;
    render_extent: Vector2;

    df_input: u32;
    lightmap_input: u32;
    previous_rt: u32;

    cascade_index: float;
    cascade_count: float;
    cascade_linear: float;
    cascade_interval: float;
}

radiance_cascades_pipeline: RHIGraphicsPipeline;
