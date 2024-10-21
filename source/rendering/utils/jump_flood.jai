init_jump_flood_pipeline :: (bindless_set_layout: *RHIDescriptorSetLayout) {
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


    {
        create_info := rhi_default_graphics_pipeline_create_info();
        rhi_set_vertex_shader(*create_info, "fullscreen_vs");
        rhi_set_pixel_shader(*create_info, "draw_uvs_ps");
        rhi_set_vertex_binding_descs(*create_info, binding_descs);
        rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
        rhi_set_color_blend_attachments(*create_info, blend_states);
        rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
        rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
        rhi_set_color_attachment_formats(*create_info, render_target_formats);

        push_const_size: u32 = size_of(Jump_Flood_Seed_Push_Consts);

        rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 1);
        
        jump_flood_seed_pipeline = rhi_graphics_pipeline_build(create_info);
    }
    {
        create_info := rhi_default_graphics_pipeline_create_info();
        rhi_set_vertex_shader(*create_info, "fullscreen_vs");
        rhi_set_pixel_shader(*create_info, "jump_flood_ps");
        rhi_set_vertex_binding_descs(*create_info, binding_descs);
        rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
        rhi_set_color_blend_attachments(*create_info, blend_states);
        rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
        rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
        rhi_set_color_attachment_formats(*create_info, render_target_formats);

        push_const_size: u32 = size_of(Jump_Flood_Push_Consts);

        rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 1);
        
        jump_flood_pipeline = rhi_graphics_pipeline_build(create_info);
    }
}

destroy_jump_flood_pipeline :: () {
    rhi_graphics_pipeline_destroy(jump_flood_seed_pipeline);
    rhi_graphics_pipeline_destroy(jump_flood_pipeline);
}

create_transient_jfa_texture :: (rg: *RenderGraph, resolution: Extent2D, debug_name: string) -> RDGResourceViewHandle {
    jfa_image_view: RDGResourceViewHandle;
    jfa_image_desc := RDGImageDescription.{
        debug_name = debug_name,
        width = resolution.width,
        height = resolution.height,
        format = .R16G16B16A16_SFLOAT,
        usage_flags = .COLOR_ATTACHMENT_BIT | .CLEAR_BIT,
    };

    jfa_image_handle := rdg_create_image(rg, jfa_image_desc);
    jfa_image_view = rdg_create_image_view(rg, jfa_image_handle, tprint("% View", debug_name));

    return jfa_image_view;
}

render_jump_flood :: (rg: *RenderGraph, view_data: *RenderViewData, input: RDGResourceViewHandle) -> RDGResourceViewHandle {
    jfa_a := create_transient_jfa_texture(rg, view_data.scene_texture_size, "JumpFlood RT A");
    jfa_b := create_transient_jfa_texture(rg, view_data.scene_texture_size, "JumpFlood RT B");

    clear_color: RHIClearColorValue;
    clear_color._float32 = .[0, 0, 0, 0];
    add_clear_image_pass(rg, jfa_a, clear_color);
    add_clear_image_pass(rg, jfa_b, clear_color);

    jump_flood_seed_pass_usages := RDGResourceUsageDesc.[
        .{jfa_a, .{resource_state = .WRITE_COLOR_ATTACHMENT, stage_mask = .PIXEL_SHADER_BIT}, .{}},
        .{input, .{resource_state = .READ_RESOURCE, stage_mask = .PIXEL_SHADER_BIT}, .{}},
    ];


    {
        pass_data := rdg_allocate_pass_data(rg, Jump_Flood_Pass_Data);
        pass_data.view_data = view_data;
        pass_data.seed_tex = input;
        pass_data.jfa_rt = jfa_a;

        rdg_add_pass(rg, "Jump Flood Seed Pass", .GRAPHICS, jump_flood_seed_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
            pass_data := cast(*Jump_Flood_Pass_Data) pass_data_ptr;
            view_data := pass_data.view_data;

            seed_tex := pass_data.seed_tex;
            jfa_rt := pass_data.jfa_rt;

            jfa_rt_buffer_desc := RHIColorAttachmentDesc.{
                image_view = rdg_get_image_view(jfa_rt),
                load_op = .LOAD,
                store_op = .STORE,
            };

            render_rect := RHIRect.{ .{0, 0}, .{xx g_window_width, xx g_window_height}};
            viewport := RHIViewport.{ 0, 0, cast(float) g_window_width, cast(float) g_window_height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{xx g_window_width, xx g_window_height}};


            // seed the input into RT A:
            rhi_cmd_begin_renderpass(cmd_list, .[jfa_rt_buffer_desc], null, render_rect, true);
            {
                rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
                rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

                rhi_cmd_bind_pipeline(cmd_list, *jump_flood_seed_pipeline);

                descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.bindless_set];
                rhi_cmd_bind_descriptor_sets(cmd_list, *jump_flood_seed_pipeline, 0, descriptor_sets, .[]);

                push_const: Jump_Flood_Seed_Push_Consts = .{
                    input_tex = rdg_get_bindless_handle(seed_tex, .TEXTURE),
                };
                rhi_cmd_push_constants(cmd_list, *jump_flood_seed_pipeline, .PIXEL_BIT, 0, size_of(Jump_Flood_Seed_Push_Consts), *push_const);

                rhi_cmd_draw(cmd_list, 3, 1, 0, 0);
            }
            rhi_cmd_end_renderpass(cmd_list);
        });
    }

    LOG_2 :: #run log(2);

    num_passes := cast(s32) ceil(log(max(cast(float) view_data.scene_texture_size.width, cast(float) view_data.scene_texture_size.height)) / LOG_2);
    
    current_seed := jfa_a;
    current_rt := jfa_b;

    for 0..num_passes-1 {
        pass_data := rdg_allocate_pass_data(rg, Jump_Flood_Pass_Data);
        pass_data.view_data = view_data;
        pass_data.seed_tex = current_seed;
        pass_data.jfa_rt = current_rt;

        jump_flood_pass_usages := RDGResourceUsageDesc.[
            .{pass_data.jfa_rt, .{resource_state = .WRITE_COLOR_ATTACHMENT, stage_mask = .PIXEL_SHADER_BIT}, .{}},
            .{pass_data.seed_tex, .{resource_state = .READ_RESOURCE, stage_mask = .PIXEL_SHADER_BIT}, .{}},
        ];

        u_offset := pow(2., cast(float) (num_passes - it - 1));
        pass_data.u_offset_over_res = Vector2.{u_offset, u_offset} / Vector2.{ cast(float) view_data.scene_texture_size.width, cast(float) view_data.scene_texture_size.height};

        rdg_add_pass(rg, tprint("Jump Flood Iter: %", it), .GRAPHICS, jump_flood_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
            pass_data := cast(*Jump_Flood_Pass_Data) pass_data_ptr;
            view_data := pass_data.view_data;

            seed_tex := pass_data.seed_tex;
            jfa_rt := pass_data.jfa_rt;

            jfa_rt_buffer_desc := RHIColorAttachmentDesc.{
                image_view = rdg_get_image_view(jfa_rt),
                load_op = .CLEAR,
                store_op = .STORE,
            };

            render_rect := RHIRect.{ .{0, 0}, .{xx g_window_width, xx g_window_height}};
            viewport := RHIViewport.{ 0, 0, cast(float) g_window_width, cast(float) g_window_height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{xx g_window_width, xx g_window_height}};


            // seed the input into RT A:
            rhi_cmd_begin_renderpass(cmd_list, .[jfa_rt_buffer_desc], null, render_rect, true);
            {
                rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
                rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

                rhi_cmd_bind_pipeline(cmd_list, *jump_flood_pipeline);

                descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.bindless_set];
                rhi_cmd_bind_descriptor_sets(cmd_list, *jump_flood_pipeline, 0, descriptor_sets, .[]);

                push_const: Jump_Flood_Push_Consts = .{
                    input_tex = rdg_get_bindless_handle(seed_tex, .TEXTURE),
                    u_offset_over_res = pass_data.u_offset_over_res,
                };
                rhi_cmd_push_constants(cmd_list, *jump_flood_pipeline, .PIXEL_BIT, 0, size_of(Jump_Flood_Push_Consts), *push_const);

                rhi_cmd_draw(cmd_list, 3, 1, 0, 0);
            }
            rhi_cmd_end_renderpass(cmd_list);
        });

        current_rt, current_seed = swap(current_rt, current_seed);
    }

    return current_seed;
}

#scope_file

Jump_Flood_Pass_Data :: struct {
    view_data: *RenderViewData;
    seed_tex: RDGResourceViewHandle;
    jfa_rt: RDGResourceViewHandle;
    u_offset_over_res: Vector2;
}

Jump_Flood_Seed_Push_Consts :: struct {
    input_tex: u32;
}

Jump_Flood_Push_Consts :: struct {
    u_offset_over_res: Vector2;
    input_tex: u32;
}

jump_flood_seed_pipeline: RHIGraphicsPipeline;
jump_flood_pipeline: RHIGraphicsPipeline;
