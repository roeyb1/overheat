#scope_export

MEMORY_LEAK_CHECK :: false;

game_window: Window_Type;
g_window_width: u32 = 800;
g_window_height: u32 = 600;

main_view_camera: Camera;

Sprite :: struct {
    sheet: *SpriteSheet = null;
    scale: Vector2 = .{1, 1};
    index: s32 = 0;
    z_order: s8 = 0;
}


// Copy over the sprite data required for rendering so we don't need to directly reference it
Sprite_Draw_Cmd :: struct {
    sheet: *SpriteSheet;

    sprite_index: s32;
    z_order: s8;

    position: Vector2;
    scale: Vector2;
}

rendering_init :: () -> bool {
    log("Initialized rendering systems...");

    game_window = create_window(g_window_width, g_window_height, "Overheat");

    init_rhi();
    init_surface();
    init_device();
    init_swapchain(g_window_width, g_window_height);

    graphics_semaphore = create_semaphore(0);

    init_bindless_descriptor_set();

    recompute_camera_projection(*main_view_camera);

    log("Rendering systems initialized successfully");
    return true;
}

rendering_shutdown :: () {
    destroy_bindless_descriptor_set();

    destroy_semaphore(graphics_semaphore);

    destroy_swapchain();
    destroy_device();
    destroy_surface();
    destroy_rhi();

    log("Rendering systems shutdown successfully");
}

application_window_update :: () {
    update_window_events();

    for get_window_resizes() {
        if it.window == game_window {
            resize_swapchain(g_window_width, g_window_height);

            recompute_camera_projection(*main_view_camera);
        }
    }

    for events_this_frame {
        if it.type == .QUIT then g_should_exit = true;
    }
}

rendering_begin_frame :: () {
    get_swapchain_image_index();
}   

rendering_end_frame :: () {
}

draw_sprite :: (camera: *Camera, sprite: *Sprite, position: Vector2) {
    sprite_draw_cmd := array_add(*sprite_draw_cmds);

    sprite_draw_cmd.sheet = sprite.sheet;
    sprite_draw_cmd.scale = sprite.scale;
    sprite_draw_cmd.sprite_index = sprite.index;
    sprite_draw_cmd.z_order = sprite.z_order;

    sprite_draw_cmd.position = position;
}

#scope_file
DrawBucket :: struct {
    start: u64;
    count: u64;
    sprite_sheet: *SpriteSheet;
}
#scope_export

graphics_semaphore: RHISemaphore;
graphics_semaphore_value: u64 = 0;

render_scene :: (camera: *Camera) {


    swapchain_present(graphics_semaphore, graphics_semaphore_value, graphics_semaphore, graphics_semaphore_value + 1);
    graphics_semaphore_value += 1;
}

//load_texture_from_file :: (filename: string, image_usage: VkImageUsageFlags = .SAMPLED_BIT) -> Texture, bool {
//    tex_width, tex_height, tex_channels: s32;
//    pixel_data := stbi_load(temp_c_string(filename), *tex_width, *tex_height, *tex_channels, xx STBI.rgb_alpha);
//    defer stbi_image_free(pixel_data);
//    image_size: VkDeviceSize = xx (tex_width * tex_height * 4);
//    
//    assert(pixel_data != null);
//
//    staging_buffer, result := make_buffer(image_size, .TRANSFER_SRC_BIT, .CPU_ONLY);
//    assert(result == .SUCCESS);
//    result = copy_to_device(staging_buffer.allocation, pixel_data, image_size);
//    assert(result == .SUCCESS);
//
//    format := VkFormat.R8G8B8A8_SRGB;
//    image:, result = make_image(.{xx tex_width, xx tex_height}, format, .TRANSFER_DST_BIT | image_usage, .GPU_ONLY);
//    assert(result == .SUCCESS);
//
//
//    // #todo: this can be cleaned up, we could merge this whole operation into a single command buffer
//    cmd_buff := begin_single_use_commands();
//    {
//        transition_image_layout(cmd_buff, image.image, .R8G8B8A8_SRGB, .UNDEFINED, .TRANSFER_DST_OPTIMAL);
//
//        image_copy_region := VkBufferImageCopy.{
//            bufferOffset = 0,
//            bufferRowLength = 0,
//            bufferImageHeight = 0,
//            imageSubresource.aspectMask = .COLOR_BIT,
//            imageSubresource.mipLevel = 0,
//            imageSubresource.baseArrayLayer = 0,
//            imageSubresource.layerCount = 1,
//            imageOffset = .{ 0, 0, 0 },
//            imageExtent = .{ xx tex_width, xx tex_height, 1 },
//        };
//
//        vkCmdCopyBufferToImage(cmd_buff, staging_buffer.buffer, image.image, .TRANSFER_DST_OPTIMAL, 1, *image_copy_region);
//
//        transition_image_layout(cmd_buff, image.image, .R8G8B8A8_SRGB, .TRANSFER_DST_OPTIMAL, .SHADER_READ_ONLY_OPTIMAL);
//    }
//    end_single_use_commands(cmd_buff);
//
//    view:, result = make_image_view(image.image, format, .COLOR_BIT);
//    assert(result == .SUCCESS);
//
//    return .{image = image, image_view = view, format = format}, true;
//}

Simp :: #import "Simp";
#import "Window_Creation";

#scope_file

Vertex :: struct {
    pos: Vector2;
    uv: Vector2;
}

InstanceData :: struct {
    position: Vector3;
    scale: Vector2;

    sprite_index: s32;
} #no_padding;

sprite_draw_cmds: [..] Sprite_Draw_Cmd;

#scope_file

#load "rhi/vk_rhi.jai";

#import "Sort";
#import "File";

#if OS == .WINDOWS {
    #import "Windows";
}