
add_clear_image_pass :: (rg: *RenderGraph, texture_view: RDGResourceViewHandle, clear_color: RHIClearColorValue, range: RHIImageSubresourceRange = .{0, 1, 0, 1}) {
    Clear_Pass_Data :: struct {
        texture_view: RDGResourceViewHandle;
    }

    usage_descs := RDGResourceUsageDesc.[
        .{texture_view, .{.CLEAR_RESOURCE, .TOP_OF_PIPE_BIT}, .{.RW_RESOURCE, .PIXEL_SHADER_BIT}},
    ];

    pass_data := rdg_allocate_pass_data(rg, Clear_Pass_Data);
    pass_data.texture_view = texture_view;
    rdg_add_pass(rg, "Clear Image", .GRAPHICS, usage_descs, pass_data, (cmd_list: *RHICmdList, pass_data_ptr: *void) -> () {
        pass_data := cast(*Clear_Pass_Data)pass_data_ptr;
        clear_color: RHIClearColorValue;
        clear_color._float32 = .[0., 0., 0., 1.];

        range := RHIImageSubresourceRange.{
            0, 1, 0, 1
        };

        image: *RHIImage = rdg_get_image(pass_data.texture_view);
        assert(image != null);

        rhi_cmd_clear_image(cmd_list, image, clear_color, .[range]);

        barrier := RHIBarrier.{
            image,
            null,
            .CLEAR_BIT,
            .PIXEL_SHADER_BIT,
            .CLEAR_RESOURCE,
            .RW_RESOURCE,
            null,
            null,
            range,
            0,
        };

        rhi_cmd_barrier(cmd_list, .[barrier]);
    });
}

RDG_SCOPED_GPU_LABEL :: (name: string) #expand {
    // @speed we should be able to strip these passes in release builds
    Label_Data :: struct {
        name: string;
    }
    pass_data := rdg_allocate_pass_data(`rg, Label_Data);
    pass_data.name = name;
    rdg_add_pass(`rg, "", .GRAPHICS, .[], pass_data, (cmd_list: *RHICmdList, pass_data: *void) -> () {
        rhi_cmd_debug_label_begin(cmd_list, (cast(*Label_Data)pass_data).name);
    });

    `defer rdg_add_pass(`rg, "", .GRAPHICS, .[], null, (cmd_list: *RHICmdList, pass_data: *void) -> () {
        rhi_cmd_debug_label_end(cmd_list);
    });
}
