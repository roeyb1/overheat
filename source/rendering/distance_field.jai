init_distance_field_pipeline :: (bindless_set_layout: *RHIDescriptorSetLayout) {
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
    rhi_set_pixel_shader(*create_info, "df_from_jf_ps");
    rhi_set_vertex_binding_descs(*create_info, binding_descs);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_color_attachment_formats(*create_info, render_target_formats);

    push_const_size: u32 = size_of(Distance_Field_Push_Consts);

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers, 1);
    
    distance_field_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_distance_field_pipeline :: () {
    rhi_graphics_pipeline_destroy(distance_field_pipeline);
}

render_distance_field :: (rg: *RenderGraph, view_data: *RenderViewData, jfa_input: RDGResourceViewHandle) -> RDGResourceViewHandle {
    df_image_view: RDGResourceViewHandle;
    df_image_desc := RDGImageDescription.{
        debug_name = "Lighting Distance Field",
        width = view_data.scene_texture_size.width,
        height = view_data.scene_texture_size.height,
        format = .R16G16B16A16_SFLOAT,
        usage_flags = .COLOR_ATTACHMENT_BIT,
    };

    df_image_handle := rdg_create_image(rg, df_image_desc);
    df_image_view = rdg_create_image_view(rg, df_image_handle, "Lighting Distance Field View");

    distance_field_pass_usages := RDGResourceUsageDesc.[
        .{df_image_view, .{resource_state = .WRITE_COLOR_ATTACHMENT, stage_mask = .PIXEL_SHADER_BIT}, .{}},
        .{jfa_input, .{resource_state = .READ_RESOURCE, stage_mask = .PIXEL_SHADER_BIT}, .{}},
    ];

    {
        pass_data := rdg_allocate_pass_data(rg, Distance_Field_Pass_Data);
        pass_data.view_data = view_data;
        pass_data.df_rt = df_image_view;
        pass_data.jfa_input = jfa_input;

        rdg_add_pass(rg, "Distance Field Pass", .GRAPHICS, distance_field_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
            pass_data := cast(*Distance_Field_Pass_Data) pass_data_ptr;
            view_data := pass_data.view_data;


            df_rt_buffer_desc := RHIColorAttachmentDesc.{
                image_view = rdg_get_image_view(pass_data.df_rt),
                load_op = .CLEAR,
                store_op = .STORE,
            };

            render_rect := RHIRect.{ .{0, 0}, .{xx g_window_width, xx g_window_height}};
            viewport := RHIViewport.{ 0, 0, cast(float) g_window_width, cast(float) g_window_height, 0., 1.};
            scissor := RHIRect.{.{0, 0}, .{xx g_window_width, xx g_window_height}};


            // seed the input into RT A:
            rhi_cmd_begin_renderpass(cmd_list, .[df_rt_buffer_desc], null, render_rect, true);
            {
                rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
                rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);

                rhi_cmd_bind_pipeline(cmd_list, *distance_field_pipeline);

                descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.bindless_set];
                rhi_cmd_bind_descriptor_sets(cmd_list, *distance_field_pipeline, 0, descriptor_sets, .[]);

                push_const: Distance_Field_Push_Consts = .{
                    jfa_input = rdg_get_bindless_handle(pass_data.jfa_input, .TEXTURE),
                };
                rhi_cmd_push_constants(cmd_list, *distance_field_pipeline, .PIXEL_BIT, 0, size_of(Distance_Field_Push_Consts), *push_const);

                rhi_cmd_draw(cmd_list, 3, 1, 0, 0);
            }
            rhi_cmd_end_renderpass(cmd_list);
        });
    }

    return df_image_view;
}

#scope_file

Distance_Field_Pass_Data :: struct {
    view_data: *RenderViewData;
    df_rt: RDGResourceViewHandle;
    jfa_input: RDGResourceViewHandle;
}

Distance_Field_Push_Consts :: struct {
    jfa_input: u32;
}

distance_field_pipeline: RHIGraphicsPipeline;