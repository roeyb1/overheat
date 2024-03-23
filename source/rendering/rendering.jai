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
    rhi_swapchain_init(g_window_width, g_window_height);

    rdg_initialize(*g_render_graph);
    rdg_init_view_registry(*g_render_graph.view_registry);

    recompute_camera_projection(*main_view_camera);

    log("Rendering systems initialized successfully");
    return true;
}

rendering_shutdown :: () {
    vkDeviceWaitIdle(device);

    rdg_shutdown(*g_render_graph);

    rhi_swapchain_destroy();
    destroy_device();
    destroy_surface();
    destroy_rhi();

    log("Rendering systems shutdown successfully");
}

application_window_update :: () {
    update_window_events();

    for get_window_resizes() {
        if it.window == game_window {
            rhi_swapchain_resize(g_window_width, g_window_height, acquire_image = true);

            recompute_camera_projection(*main_view_camera);
        }
    }

    for events_this_frame {
        if it.type == .QUIT then g_should_exit = true;
    }
}

rendering_begin_frame :: () {
    rhi_swapchain_image_index();
}   

rendering_end_frame :: () {
}

#scope_file
DrawBucket :: struct {
    start: u64;
    count: u64;
    sprite_sheet: *SpriteSheet;
}
#scope_export

render_scene :: (camera: *Camera) {
    rg := *g_render_graph;
    rdg_next_frame(rg);

    render_image_desc := RDGImageDescription.{
        debug_name = "Render Image",
        width = swapchain.extent.width,
        height = swapchain.extent.height,
        format = .B8G8R8A8_UNORM,
        usage_flags = .COLOR_ATTACHMENT_BIT | .TEXTURE_BIT | .RW_TEXTURE_BIT | . TRANSFER_SRC_BIT,
    };

    render_image_handle := rdg_create_image(rg, render_image_desc);
    render_view_handle := rdg_create_image_view(rg, render_image_handle, "Render Image View");

    {
        usage_desc := RDGResourceUsageDesc.{
            render_view_handle,
            .{resource_state = .CLEAR_RESOURCE},
            .{}
        };

        rdg_add_pass(rg, "Clear Render Image", .GRAPHICS, .[usage_desc], (cmd_list: *RHICmdList, views: [] RDGResourceViewHandle) -> () {
            render_view_handle := views[0];

            clear_color := RHIClearColorValue.{
                _float32 = .[0.1, 1.1, 0.1, 0.1]
            };
            range := RHIImageSubresourceRange.{ 0, 1, 0, 1};
            rhi_cmd_clear_image(cmd_list, rdg_get_image(render_view_handle), clear_color, .[range]);
        });
    }



    // present to swapchain:
    {
        swapchain_index := swapchain.current_image_index;
        swapchain_image_handle := rdg_import_image(rg, *swapchain.images[swapchain_index], "Swapchain Image");
        swapchain_view_handle := rdg_create_image_view(rg, swapchain_image_handle, "Swapchain Image View");


        // copy render image to swapchain image:
        {
            usage_descs: [2] RDGResourceUsageDesc;
            usage_descs[0] = RDGResourceUsageDesc.{view_handle = render_view_handle, state_and_stage = .{resource_state = .READ_TRANSFER}};
            usage_descs[1] = RDGResourceUsageDesc.{view_handle = swapchain_view_handle, state_and_stage = .{resource_state = .WRITE_TRANSFER}};

            rdg_add_pass(rg, "Copy to Swapchain", .GRAPHICS, usage_descs, (cmd_list: *RHICmdList, views: [] RDGResourceViewHandle) -> () {
                render_image_view := views[0];
                swapchain_image_view := views[1];

                image_copies := RHIImageCopy.[.{
                    src_layer_count = 1,
                    dst_layer_count = 1,
                    extent = .{swapchain.extent.width, swapchain.extent.height, 1},
                }];

                rhi_cmd_copy_image(cmd_list, rdg_get_image(render_image_view), rdg_get_image(swapchain_image_view), image_copies);
            });
        }

        present_transition_usages := RDGResourceUsageDesc.{
            swapchain_view_handle,
            .{ resource_state = RHIResourceState.PRESENT },
            .{},
        };

        rdg_add_pass(rg, "Present Transition", .GRAPHICS, .[present_transition_usages], (cmd_list: *RHICmdList, views: [] RDGResourceViewHandle) -> () {
            rhi_cmd_debug_label_insert(cmd_list, "Present");
        });
    }

    rdg_flush_resource_view_updates(*rg.view_registry);
    rdg_execute(rg);


    rhi_swapchain_present(rg.semaphores[RHIQueueIndex.GRAPHICS].handle, rg.semaphore_values[RHIQueueIndex.GRAPHICS], rg.semaphores[RHIQueueIndex.GRAPHICS].handle, rg.semaphore_values[RHIQueueIndex.GRAPHICS] + 1);
    rg.semaphore_values[RHIQueueIndex.GRAPHICS] += 1;
}

#import "Window_Creation";

#scope_file

#load "../rhi/rhi.jai";
#load "render_graph.jai";
#load "sprite_rendering.jai";

#import "Sort";
#import "File";

#if OS == .WINDOWS {
    #import "Windows";
}