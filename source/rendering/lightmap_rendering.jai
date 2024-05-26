
/** Point light is a component that can be added to an entity to make it render a as a radial, point source light light */
Point_Light :: struct {
    color: Vector3;
    radius: float;
    intensity: float;
}

g_point_light_texture: TextureHandle;

init_lightmap_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    {
        // Store lightmap data in a higher precision, non-linear format for higher dynamic range
        render_target_formats := RHIFormat.[
            .R16G16B16A16_SFLOAT,
        ];

        // Use additive blending to add all light sources together
        blend_states := RHIPipelineColorBlendAttachmentState.[
            .{
                blend_enable = true,
                src_color_blend_factor = .DST_ALPHA,
                dst_color_blend_factor = .ONE,
                color_blend_op = .ADD,
                src_alpha_blend_factor = .ONE,
                dst_alpha_blend_factor = .ZERO,
                alpha_blend_op = .ADD,
            }
        ];

        attribute_descs := RHIVertexInputAttributeDesc.[
            .{ "VERTEX_POSITION", 0, 0, .R32G32_SFLOAT, xx offset_of(Vertex2D, "pos")},
            .{ "TEXCOORD", 1, 0, .R32G32_SFLOAT, xx offset_of(Vertex2D, "uv")},
        ];

        binding_descs := RHIVertexInputBindingDesc.[
            .{0, size_of(Vertex2D), .VERTEX },
        ];


        create_info := rhi_default_graphics_pipeline_create_info();
        rhi_set_vertex_shader(*create_info, "lightmap_vs");
        rhi_set_pixel_shader(*create_info, "lightmap_ps");
        rhi_set_vertex_binding_descs(*create_info, binding_descs);
        rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
        rhi_set_color_blend_attachments(*create_info, blend_states);
        rhi_set_depth_test(*create_info, false, false, .LESS_OR_EQUAL);
        rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
        rhi_set_color_attachment_formats(*create_info, render_target_formats);

        used_offset_buffer_binding := RHIDescriptorSetLayoutBinding.[.{
            descriptor_type = .OFFSET_CONSTANT_BUFFER,
            binding = 0,
            space = 0,
            descriptor_count = 1,
            stage_flags = .ALL_STAGES,
        }];

        used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
            rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT), // point light sprite
        ];

        layout_decls := RHIDescriptorSetLayoutDecl.[
            .{offset_buffer_set_layout, used_offset_buffer_binding },
            .{bindless_set_layout, used_bindless_bindings }
        ];

        static_samplers := RHIStaticSamplerDesc.[
            rhi_static_point_clamp_sampler(0, 0, .PIXEL_BIT),
        ];

        push_const_size: u32 = size_of(Lightmap_Push_Const);

        rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .VERTEX_BIT | .PIXEL_BIT, static_samplers, 2);
        
        lightmap_pipeline = rhi_graphics_pipeline_build(create_info);
    }

    {
        used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
            rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .ALL_STAGES),
            rhi_bindless_descriptor_set_layout_binding(.RW_TEXTURE, 0, .ALL_STAGES),
        ];

        layout_decls := RHIDescriptorSetLayoutDecl.[
            .{bindless_set_layout, used_bindless_bindings},
        ];

        pipeline_create_info: RHIComputePipelineCreateInfo;
        rhi_set_compute_shader(*pipeline_create_info, "apply_lighting_cs");

        push_const_size := size_of(Lighting_Push_Consts);
        rhi_set_pipeline_layout_desc(*pipeline_create_info, layout_decls, xx push_const_size, .COMPUTE_BIT, .[], 0);

        apply_lighting_pipeline = rhi_compute_pipeline_build(pipeline_create_info);
    }
}

destroy_lightmap_pipeline :: () {
    rhi_compute_pipeline_destroy(apply_lighting_pipeline);
    rhi_graphics_pipeline_destroy(lightmap_pipeline);
}

render_lightmap_pass :: (rg: *RenderGraph, view_data: *RenderViewData, lightmap_image_view: RDGResourceViewHandle, light_position: Position, point_light: Point_Light, render_rect: RHIRect) {
    light_data := Point_Light_Data.{
        color = point_light.color,
        position = light_position,
        radius = point_light.radius,
        intensity = point_light.intensity,
    };

    lightmap_pass_usages := RDGResourceUsageDesc.[
        .{lightmap_image_view, .{resource_state = .WRITE_COLOR_ATTACHMENT}, .{}},
    ];

    // calculate the maximum screenspace bounds for the light so we can build the scissor rect

    pass_data := rdg_allocate_pass_data(rg, Lightmap_Pass_Data);
    pass_data.view_data = view_data;
    pass_data.light_data = light_data;
    pass_data.lightmap_image_view = lightmap_image_view;
    pass_data.render_rect = render_rect;

    rdg_add_pass(rg, "Lightmap Pass", .GRAPHICS, lightmap_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
        pass_data := cast(*Lightmap_Pass_Data) pass_data_ptr;
        view_data := pass_data.view_data;

        lightmap_image_view := pass_data.lightmap_image_view;

        lightmap_buffer_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(lightmap_image_view),
            load_op = .LOAD,
            store_op = .STORE,
        };

        rhi_cmd_begin_renderpass(cmd_list, .[lightmap_buffer_desc], null, pass_data.render_rect, true);
        {
            viewport := RHIViewport.{ 0, 0, cast(float) view_data.scene_texture_size.width, cast(float) view_data.scene_texture_size.height, 0., 1.};

            rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);
            rhi_cmd_set_scissor(cmd_list, 0, .[pass_data.render_rect]);

            PassConstants :: struct {
                view_projection_matrix: Matrix4;
                camera_position: Vector3;
            }
            pass_consts: PassConstants = ---;
            pass_consts.view_projection_matrix = view_data.camera_proj;
            pass_consts.camera_position = view_data.camera_position;

            pass_const_addr := rhi_upload_struct(pass_data.view_data.constant_buffer_allocator, .OFFSET_CONSTANT_BUFFER, pass_consts);

            rhi_cmd_bind_pipeline(cmd_list, *lightmap_pipeline);

            descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.offset_buffer_set, pass_data.view_data.bindless_set];
            rhi_cmd_bind_descriptor_sets(cmd_list, *lightmap_pipeline, 0, descriptor_sets, .[ xx pass_const_addr ]);
            
            rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[quad_vertex_buffer], .[0]);
            rhi_cmd_bind_index_buffer(cmd_list, quad_index_buffer, 0, .UINT32);

            push_const: Lightmap_Push_Const = .{
                color = pass_data.light_data.color,
                position = pass_data.light_data.position,
                radius = pass_data.light_data.radius,
                intensity = pass_data.light_data.intensity,
                point_light_texture = cast(u32) get_texture_view_handle(g_point_light_texture),
            };
            rhi_cmd_push_constants(cmd_list, *lightmap_pipeline, .VERTEX_BIT | .PIXEL_BIT, 0, size_of(Lightmap_Push_Const), *push_const);

            rhi_cmd_draw_indexed(cmd_list, 6, 1, 0, 0, 0);
        }

        rhi_cmd_end_renderpass(cmd_list);
    });
}

render_lighting_pass :: (rg: *RenderGraph, view_data: *RenderViewData, color_image_view: RDGResourceViewHandle, lightmap_image_view: RDGResourceViewHandle) -> RDGResourceViewHandle {
    lit_image_desc := RDGImageDescription.{
        debug_name = "Lit Image",
        width = view_data.scene_texture_size.width,
        height = view_data.scene_texture_size.height,
        format = .R16G16B16A16_SFLOAT,
        usage_flags = .COLOR_ATTACHMENT_BIT,
    };

    lit_image_handle := rdg_create_image(rg, lit_image_desc);
    lit_image_view := rdg_create_image_view(rg, lit_image_handle, "Lightmap Buffer View");

    lighting_pass_usages := RDGResourceUsageDesc.[
        .{color_image_view, .{.READ_RESOURCE, .COMPUTE_SHADER_BIT}, .{}},
        .{lightmap_image_view, .{.READ_RESOURCE, .COMPUTE_SHADER_BIT}, .{}},
        .{lit_image_view, .{.RW_RESOURCE_WRITE_ONLY, .COMPUTE_SHADER_BIT}, .{}},
    ];

    Lighting_Pass_Data :: struct {
        view_data: *RenderViewData;
        input_color_image: RDGResourceViewHandle;
        input_lightmap_image: RDGResourceViewHandle;
        output_lit_image: RDGResourceViewHandle;
    }

    pass_data := rdg_allocate_pass_data(rg, Lighting_Pass_Data);
    pass_data.view_data = view_data;
    pass_data.input_color_image = color_image_view;
    pass_data.input_lightmap_image = lightmap_image_view;
    pass_data.output_lit_image = lit_image_view;

    rdg_add_pass(rg, "Lighting", .GRAPHICS, lighting_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
        pass_data := cast(*Lighting_Pass_Data) pass_data_ptr;
        rhi_cmd_bind_pipeline(cmd_list, apply_lighting_pipeline);

        rhi_cmd_bind_descriptor_sets(cmd_list, apply_lighting_pipeline, 0, .[pass_data.view_data.bindless_set], .[]);

        width := swapchain.extent.width;
        height := swapchain.extent.height;

        push_consts: Lighting_Push_Consts;
        push_consts.resolution[0] = width;
        push_consts.resolution[1] = height;
        push_consts.texel_size[0] = 1. / width;
        push_consts.texel_size[1] = 1. / height;
        push_consts.input_color_image_index = rdg_get_bindless_handle(pass_data.input_color_image, .TEXTURE);
        push_consts.input_lightmap_image_index = rdg_get_bindless_handle(pass_data.input_lightmap_image, .TEXTURE);
        push_consts.output_lit_image_index = rdg_get_bindless_handle(pass_data.output_lit_image, .RW_TEXTURE);

        rhi_cmd_push_constants(cmd_list, apply_lighting_pipeline, .COMPUTE_BIT, 0, size_of(Lighting_Push_Consts), *push_consts);
        rhi_cmd_dispatch(cmd_list, (width + 7) / 8, (height + 7) / 8, 1);
    });
    return lit_image_view;
}

#scope_file

Lightmap_Pass_Data :: struct {
    view_data: *RenderViewData;
    light_data: Point_Light_Data;
    lightmap_image_view: RDGResourceViewHandle;
    render_rect: RHIRect;
}

Point_Light_Data :: struct {
    color: Vector3;
    intensity: float;
    position: Vector2;
    radius: float;
}

Lightmap_Push_Const :: struct {
    color: Vector3;
    _pad: float;
    position: Vector2;
    radius: float;
    intensity: float;
    point_light_texture: u32;
}

Lighting_Push_Consts :: struct {
    resolution: [2] u32;
    texel_size: [2] float;

    input_color_image_index: u32;
    input_lightmap_image_index: u32;
    output_lit_image_index: u32;
}

lightmap_pipeline: RHIGraphicsPipeline;
apply_lighting_pipeline: RHIComputePipeline;
