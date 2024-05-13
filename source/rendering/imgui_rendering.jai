init_imgui_pipeline :: (offset_buffer_set_layout: *RHIDescriptorSetLayout, bindless_set_layout: *RHIDescriptorSetLayout) {
    blend_states := RHIPipelineColorBlendAttachmentState.[
        .{
            blend_enable = true,
            src_color_blend_factor = .SRC_ALPHA,
            dst_color_blend_factor = .ONE_MINUS_SRC_ALPHA,
            color_blend_op = .ADD,
            src_alpha_blend_factor = .ONE_MINUS_SRC_ALPHA,
            dst_alpha_blend_factor = .ZERO,
            alpha_blend_op = .ADD,
        }
    ];

    attribute_descs := RHIVertexInputAttributeDesc.[
        .{ "POSITION", 0, 0, .R32G32_SFLOAT, xx offset_of(ImGui.ImDrawVert, "pos") },
        .{ "TEXCOORD", 1, 0, .R32G32_SFLOAT, xx offset_of(ImGui.ImDrawVert, "uv") },
        .{ "COLOR", 2, 0, .R8G8B8A8_UNORM, xx offset_of(ImGui.ImDrawVert, "col") },
    ];

    create_info := rhi_default_graphics_pipeline_create_info();
    rhi_set_vertex_shader(*create_info, "imgui_vs");
    rhi_set_pixel_shader(*create_info, "imgui_ps");
    rhi_set_vertex_binding_descs(*create_info, .[.{0, size_of(ImGui.ImDrawVert), .VERTEX}]);
    rhi_set_vertex_attrib_descs(*create_info, attribute_descs);
    rhi_set_color_blend_attachments(*create_info, blend_states);
    rhi_set_dynamic_state(*create_info, .VIEWPORT_BIT | .SCISSOR_BIT);
    rhi_set_color_attachment_formats(*create_info, .[.B8G8R8A8_UNORM]);

    used_bindless_bindings := RHIDescriptorSetLayoutBinding.[
        rhi_bindless_descriptor_set_layout_binding(.TEXTURE, 0, .PIXEL_BIT),
    ];


    layout_decls := RHIDescriptorSetLayoutDecl.[
        .{bindless_set_layout, used_bindless_bindings},
    ];

    static_samplers := RHIStaticSamplerDesc.[
        rhi_static_linear_repeat_sampler(0, 0, .PIXEL_BIT),
    ];

    rhi_set_pipeline_layout_desc(*create_info, layout_decls, size_of(ImGuiPushConsts), .VERTEX_BIT, static_samplers, 1);

    imgui_pipeline = rhi_graphics_pipeline_build(create_info);
}

destroy_imgui_pipeline :: () {
    rhi_graphics_pipeline_destroy(imgui_pipeline);
}

render_imgui_pass :: (rg: *RenderGraph, view_data: *RenderViewData, rt_handle: RDGResourceViewHandle) {
    usage_descs := RDGResourceUsageDesc.[
        .{rt_handle, .{resource_state = .WRITE_COLOR_ATTACHMENT}, .{}},
    ];

    pass_data := rdg_allocate_pass_data(rg, ImGuiPassData);
    pass_data.draw_data = ImGui.GetDrawData();
    pass_data.view_data = view_data;
    pass_data.rt_handle = rt_handle;
    rdg_add_pass(rg, "ImGui pass", .GRAPHICS, usage_descs, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) {
        pass_data := cast(*ImGuiPassData) pass_data_ptr;
        draw_data := pass_data.draw_data;
        view_data := pass_data.view_data;

        framebuffer_width: u32 = cast(u32) (draw_data.DisplaySize.x * draw_data.FramebufferScale.x);
        framebuffer_height: u32 = cast(u32) (draw_data.DisplaySize.y * draw_data.FramebufferScale.y);

        if framebuffer_width <= 0 || framebuffer_height <= 0 || draw_data.TotalVtxCount == 0 then return;

        vertex_dst, vertex_buffer_offset := rhi_allocate(view_data.vertex_buffer_allocator, size_of(ImGui.ImDrawVert), size_of(ImGui.ImDrawVert) * draw_data.TotalVtxCount);
        index_dst, index_buffer_offset := rhi_allocate(view_data.index_buffer_allocator, size_of(ImGui.ImDrawIdx), size_of(ImGui.ImDrawIdx) * draw_data.TotalIdxCount);

        for 0..draw_data.CmdListsCount-1 {
            ig_cmd_list: *ImGui.ImDrawList = draw_data.CmdLists.Data[it];

            memcpy(vertex_dst, ig_cmd_list.VtxBuffer.Data, size_of(ImGui.ImDrawVert) * ig_cmd_list.VtxBuffer.Size);
            memcpy(index_dst, ig_cmd_list.IdxBuffer.Data, size_of(ImGui.ImDrawIdx) * ig_cmd_list.IdxBuffer.Size);
            vertex_dst += ig_cmd_list.VtxBuffer.Size * size_of(ImGui.ImDrawVert);
            index_dst += ig_cmd_list.IdxBuffer.Size * size_of(ImGui.ImDrawIdx);
        }

        color_attach_desc := RHIColorAttachmentDesc.{
            image_view = rdg_get_image_view(pass_data.rt_handle),
            load_op = .LOAD,
            store_op = .STORE,
        };

        render_rect := RHIRect.{ .{ 0, 0 }, .{ framebuffer_width, framebuffer_height } };
        rhi_cmd_begin_renderpass(cmd_list, .[color_attach_desc], null, render_rect, false);
        {
            // setup render state
            {
                rhi_cmd_bind_pipeline(cmd_list, imgui_pipeline);
                rhi_cmd_bind_descriptor_sets(cmd_list, imgui_pipeline, 0, .[ view_data.bindless_set ], .[]);

                rhi_cmd_bind_vertex_buffers(cmd_list, 0, .[view_data.vertex_buffer_allocator.buffer], .[xx vertex_buffer_offset]);
                rhi_cmd_bind_index_buffer(cmd_list, view_data.index_buffer_allocator.buffer, xx index_buffer_offset, ifx size_of(ImGui.ImDrawIdx) == 2 then .UINT16 else .UINT32);

                viewport := RHIViewport.{ 0., 0., cast(float)framebuffer_width, cast(float)framebuffer_height, 0., 1. };

                rhi_cmd_set_viewport(cmd_list, 0, .[viewport]);

                scale: [2] float;
                scale[0] = (1. / (draw_data.DisplaySize.x - draw_data.DisplayPos.x)) * 2.;
                scale[1] = (1. / (draw_data.DisplaySize.y - draw_data.DisplayPos.y)) * -2.;
                translate: [2] float;
                translate[0] = -1.;
                translate[1] = 1.;

                rhi_cmd_push_constants(cmd_list, imgui_pipeline, .VERTEX_BIT, size_of(float) * 0, size_of(float) * 2, scale.data);
                rhi_cmd_push_constants(cmd_list, imgui_pipeline, .VERTEX_BIT, size_of(float) * 2, size_of(float) * 2, translate.data);
            }

            // begin rendering
            clip_offset := draw_data.DisplayPos;
            clip_scale := draw_data.FramebufferScale;

            vtx_offset: s32 = 0;
            idx_offset: s32 = 0;
            for list_index : 0..draw_data.CmdLists.Size-1 {
                ig_cmd_list := draw_data.CmdLists.Data[list_index];

                for cmd_index : 0..ig_cmd_list.CmdBuffer.Size-1 {
                    cmd := *ig_cmd_list.CmdBuffer.Data[cmd_index];

                    if cmd.UserCallback != null {
                        assert(false);
                        cmd.UserCallback(ig_cmd_list, cmd);
                    } else {
                        clip_rect: ImGui.ImVec4 = ---;
                        clip_rect.x = (cmd.ClipRect.x - clip_offset.x) * clip_scale.x;
                        clip_rect.y = (cmd.ClipRect.y - clip_offset.y) * clip_scale.y;
                        clip_rect.z = (cmd.ClipRect.z - clip_offset.x) * clip_scale.x;
                        clip_rect.w = (cmd.ClipRect.w - clip_offset.y) * clip_scale.y;

                        if clip_rect.x < xx framebuffer_width && clip_rect.y < xx framebuffer_height && clip_rect.z >= 0. && clip_rect.w >= 0. {
                            if clip_rect.x < 0. {
                                clip_rect.x = 0.;
                            }
                            if clip_rect.y < 0. {
                                clip_rect.y = 0.;
                            }
                            scissor: RHIRect = ---;
                            scissor.offset.x = xx clip_rect.x;
                            scissor.offset.y = xx clip_rect.y;
                            scissor.extent.width = xx (clip_rect.z - clip_rect.x);
                            scissor.extent.height = xx (clip_rect.w - clip_rect.y);

                            rhi_cmd_set_scissor(cmd_list, 0, .[scissor]);
                            tex_index: u32 = cast(u32)cmd.TextureId;
                            assert(tex_index != 0);
                            rhi_cmd_push_constants(cmd_list, imgui_pipeline, .VERTEX_BIT, 4 * size_of(float), size_of(type_of(tex_index)), *tex_index);
                            rhi_cmd_draw_indexed(cmd_list, cmd.ElemCount, 1, cmd.IdxOffset + cast(u32)(idx_offset), cast(s32)(cmd.VtxOffset) + vtx_offset, 0);
                        }
                    }
                }

                vtx_offset += ig_cmd_list.VtxBuffer.Size;
                idx_offset += ig_cmd_list.IdxBuffer.Size;
            }

        }
        rhi_cmd_end_renderpass(cmd_list);
    });
}

ImGui :: #import "ImGui";

#scope_file

ImGuiPushConsts :: struct {
    scale: [2] float;
    translate: [2] float;
    texture_index: u32;
}

ImGuiPassData :: struct {
    view_data: *RenderViewData;
    draw_data: *ImGui.ImDrawData;
    rt_handle: RDGResourceViewHandle;
}

imgui_pipeline: RHIGraphicsPipeline;