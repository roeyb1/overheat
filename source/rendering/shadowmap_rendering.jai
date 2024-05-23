Shadow_Caster :: struct {
    box: AABB;
}

init_shadowmap_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    // Store lightmap data in a higher precision, non-linear format for higher dynamic range
    render_target_formats := RHIFormat.[
        .R16G16B16A16_SFLOAT,
    ];

    // Use additive blending to add all light sources together
    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = true,
            src_color_blend_factor = .ZERO, // we don't write color in the shadowmap pass
            dst_color_blend_factor = .ONE, // retain whatever the color is in the lightmap (usually the ambient light)
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ONE,
            dst_alpha_blend_factor = .ZERO,
            alpha_blend_op = .ADD, // take the min of the current value and the drawn value. Ensures we always write 0's over cleared data
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "VERTEX_POSITION", 0, 0, .R32G32B32A32_SFLOAT, xx offset_of(Shadow_Vertex, "pos")},
    ];

    binding_descs := RHIVertexInputBindingDesc.[
        .{0, size_of(Shadow_Vertex), .VERTEX },
    ];


    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "shadowmap_vs");
    rhi_set_pixel_shader(*create_info, "shadowmap_ps");
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
    ];

    push_const_size: u32 = 0;

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, push_const_size, .PIXEL_BIT, static_samplers);
    
    shadowmap_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_shadowmap_pipeline :: () {
    rhi_graphics_pipeline_destroy(shadowmap_pipeline);
}

render_shadowmap_pass :: (rg: *RenderGraph, view_data: *RenderViewData, lightmap_image_view: RDGResourceViewHandle, light_position: Vector2, render_rect: RHIRect) {
    shadow_vertex_data: [..] Shadow_Vertex;
    shadow_vertex_data.allocator = temp;

    add_segment :: (shadow_vertex_data: *[..] Shadow_Vertex, light_position: Vector2, a: Vector2, b: Vector2) {
        array_add(shadow_vertex_data, .{ make_vector4(a, 0., 1.) });
        array_add(shadow_vertex_data, .{ make_vector4(a - light_position, 0., 0.) });
        array_add(shadow_vertex_data, .{ make_vector4(b, 0., 1.) });
        array_add(shadow_vertex_data, .{ make_vector4(b - light_position, 0., 0.) });
    }

    for Query(Shadow_Caster, Position).{world = *g_world} {
        box := translate(it.shadow_caster.box, it.position);

        add_segment(*shadow_vertex_data, light_position, .{box.min.x, box.min.y}, .{box.max.x, box.min.y});
        add_segment(*shadow_vertex_data, light_position, .{box.max.x, box.min.y}, .{box.max.x, box.max.y});
        add_segment(*shadow_vertex_data, light_position, .{box.max.x, box.max.y}, .{box.min.x, box.max.y});
        add_segment(*shadow_vertex_data, light_position, .{box.min.x, box.max.y}, .{box.min.x, box.min.y});
    }

    // early out if we have no shadow geometry
    if shadow_vertex_data.count == 0 then return;

    lightmap_pass_usages := RDGResourceUsageDesc.[
        .{lightmap_image_view, .{resource_state = .WRITE_COLOR_ATTACHMENT}, .{}},
    ];

    pass_data := rdg_allocate_pass_data(rg, Shadowmap_Pass_Data);
    pass_data.view_data = view_data;
    pass_data.shadow_vertex_data = shadow_vertex_data;
    pass_data.lightmap_image_view = lightmap_image_view;
    pass_data.render_rect = render_rect;

    rdg_add_pass(rg, "Shadowmap Pass", .GRAPHICS, lightmap_pass_usages, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
        pass_data := cast(*Shadowmap_Pass_Data) pass_data_ptr;
        view_data := pass_data.view_data;

        vertex_buffer_offset: s64 = -1;
        {
            vertex_dst:, vertex_buffer_offset = rhi_allocate(view_data.vertex_buffer_allocator, size_of(Shadow_Vertex), size_of(Shadow_Vertex) * pass_data.shadow_vertex_data.count);

            memcpy(vertex_dst,pass_data.shadow_vertex_data.data, size_of(Shadow_Vertex) * pass_data.shadow_vertex_data.count);

            assert(vertex_buffer_offset != -1);
        }

        lightmap_buffer_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(pass_data.lightmap_image_view),
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

            rhi_cmd_bind_pipeline(cmd_list, *shadowmap_pipeline);

            descriptor_sets := RHIDescriptorSet.[ pass_data.view_data.offset_buffer_set, pass_data.view_data.bindless_set];
            rhi_cmd_bind_descriptor_sets(cmd_list, *shadowmap_pipeline, 0, descriptor_sets, .[ xx pass_const_addr ]);
            
            rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[view_data.vertex_buffer_allocator.buffer], .[xx vertex_buffer_offset]);
            rhi_cmd_bind_index_buffer(cmd_list, quad_index_buffer, 0, .UINT32);

            for 0..(pass_data.shadow_vertex_data.count / 4)-1 {
                rhi_cmd_draw_indexed(cmd_list, 6, 1, 0, cast(s32) (it * 4), 0);
            }
        }

        rhi_cmd_end_renderpass(cmd_list);
    });
}

#scope_file

shadowmap_pipeline: RHIGraphicsPipeline;

Shadowmap_Pass_Data :: struct {
    view_data: *RenderViewData;
    shadow_vertex_data: [..] Shadow_Vertex;
    lightmap_image_view: RDGResourceViewHandle;
    render_rect: RHIRect;
}

Shadow_Vertex :: struct {
    pos: Vector4;
}
