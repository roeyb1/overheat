#scope_export

TextureLoader :: struct {
    upload_queue: [..] TextureUpload;
    staging_buffers_to_delete: [RDG_NUM_FRAMES][..] *RHIBuffer;
    staging_buffers_index: u32 = 0;
}

TextureUpload :: struct {
    subresource_range: RHIImageSubresourceRange;
    staging_buffer: *RHIBuffer;
    texture: *RHIImage;
    copy_region: RHIBufferImageCopy; // #todo: when we support multiple layers, one per layer
}

g_texture_loader: TextureLoader;

texture_load :: (filename: string) -> TextureHandle {
    texture_name := basename(filename);

    width: s32 = 0;
    height: s32 = 0;
    num_channels: s32 = 0;
    pixel_data := stbi_load(temp_c_string(filename), *width, *height, *num_channels, 4);
    defer stbi_image_free(pixel_data);

    // @todo: support fewer than 4 channel textures
    assert(pixel_data != null && width > 0 && height > 0 && num_channels == 4);
    
    // #todo: support array textures

    image_create_info := RHIImageCreateInfo.{
        extent.width = xx width,
        extent.height = xx height,
        depth = 1,
        layers = 1,
        levels = 1,
        samples = ._1,
        image_type = ._2D,
        format = .R8G8B8A8_SRGB,
        create_flags = 0,
        usage_flags = .TEXTURE_BIT | .TRANSFER_DST_BIT,
    };

    image := rhi_image_create(image_create_info, .DEVICE_LOCAL_BIT, 0, false);
    assert(image != null);
    rhi_debug_set_object_name(image, texture_name);
    image_view := rhi_image_view_create(image);
    assert(image_view != null);
    rhi_debug_set_object_name(image, tprint("% View", texture_name));

    image_memory_size := width * height * num_channels * 1; // 1 byte per pixel
    staging_buffer_size := image_memory_size;

    staging_buffer: *RHIBuffer = null;
    {
        buffer_create_info := RHIBufferCreateInfo.{
            usage_flags = .TRANSFER_SRC_BIT,
            size = xx staging_buffer_size,
        };

        staging_buffer = rhi_buffer_create(buffer_create_info, .HOST_COHERENT_BIT | .HOST_VISIBLE_BIT, 0, false);
        rhi_debug_set_object_name(staging_buffer, "Staging Buffer");
    }


    mapped_ptr := rhi_buffer_map(staging_buffer);
    {
        memcpy(mapped_ptr, pixel_data, image_memory_size);
    }
    rhi_buffer_unmap(staging_buffer);

    // #todo: implement optimal row length/height for copies
    buffer_copy := RHIBufferImageCopy.{
        buffer_offset = 0,
        buffer_row_length = 0,
        buffer_image_height = 0,
        image_mip_level = 0,
        image_base_layer = 0,
        image_layer_count = 1,
        offset = .{0, 0, 0},
        extent = .{xx width, xx height, 1},
    };

    upload := TextureUpload.{
        subresource_range.base_mip_level = 0,
        subresource_range.level_count = 1,
        subresource_range.base_array_layer = 0,
        subresource_range.layer_count = 1,
        staging_buffer = staging_buffer,
        texture = image,
        copy_region = buffer_copy,
    };

    
    array_add(*g_texture_loader.upload_queue, upload);

    return texture_manager_add(image, image_view);
}

texture_loader_flush_uploads :: (cmd_list: *RHICmdList) {
    defer g_texture_loader.staging_buffers_index = (g_texture_loader.staging_buffers_index + 1) % RDG_NUM_FRAMES;

    staging_buffers_to_delete := *g_texture_loader.staging_buffers_to_delete[g_texture_loader.staging_buffers_index];
    // delete the buffers from the previous frame:
    for buffer_to_delete : (<<staging_buffers_to_delete) {
        rhi_buffer_destroy(buffer_to_delete);
    }
    array_reset_keeping_memory(staging_buffers_to_delete);


    if g_texture_loader.upload_queue.count == 0 {
        return;
    }

    barriers: [..] RHIBarrier;
    barriers.allocator = temp;
    array_reserve(*barriers, g_texture_loader.upload_queue.count);

    // transition image to transfer dst
    {
        for upload : g_texture_loader.upload_queue {
            array_add(*barriers, RHIBarrier.{
                image = upload.texture,
                stages_before = .TOP_OF_PIPE_BIT,
                stages_after = .TRANSFER_BIT,
                state_before = .UNDEFINED,
                state_after = .WRITE_TRANSFER,
                image_subresource_range = upload.subresource_range,
            });
        }

        rhi_cmd_barrier(cmd_list, barriers);
    }

    // copy data:
    {
        for upload : g_texture_loader.upload_queue {
            rhi_cmd_copy_buffer_to_image(cmd_list, upload.staging_buffer, upload.texture, .[upload.copy_region]);

            array_add(staging_buffers_to_delete, upload.staging_buffer);
        }
    }

    array_reset_keeping_memory(*barriers);
    // transition image from transfer dst to texture
    {
        for upload : g_texture_loader.upload_queue {
            array_add(*barriers, RHIBarrier.{
                image = upload.texture,
                stages_before = .TRANSFER_BIT,
                stages_after = .VERTEX_SHADER_BIT | .PIXEL_SHADER_BIT | .COMPUTE_SHADER_BIT,
                state_before = .WRITE_TRANSFER,
                state_after = .READ_RESOURCE,
                image_subresource_range = upload.subresource_range,
            });
        }

        rhi_cmd_barrier(cmd_list, barriers);
    }


    array_reset_keeping_memory(*g_texture_loader.upload_queue);
}

texture_loader_destroy :: () {
    for upload : g_texture_loader.upload_queue {
        rhi_buffer_destroy(upload.staging_buffer);
    }

    for 0..RDG_NUM_FRAMES-1 {
        staging_buffers_to_delete: [] *RHIBuffer = g_texture_loader.staging_buffers_to_delete[it];
        for buffer : staging_buffers_to_delete {
            rhi_buffer_destroy(buffer);
        }
    }
}
