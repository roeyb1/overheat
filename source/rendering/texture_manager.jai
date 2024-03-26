#scope_export

TextureHandle :: enum u32 {}

Texture :: struct {
    image: *RHIImage = null;
    view: *RHIImageView = null;
    view_handle: RDGTextureViewHandle = 0;
}

TextureManager :: struct {
    texture_handle_manager: HandleManager;
    textures: [..] Texture;

    textures_to_free: [RDG_NUM_FRAMES][..] Texture;
    textures_to_free_index: u32 = 0;
}

g_texture_manager: TextureManager;

init_texture_manager :: () {
    array_resize(*g_texture_manager.textures, 32);
}

destroy_texture_manager :: () {
    for texture : g_texture_manager.textures {
        if texture.image != null {
            rhi_image_view_destroy(texture.view);
            rhi_image_destroy(texture.image);
        }

        if texture.view_handle != 0 {
            rdg_destroy_handle(*g_view_registry, texture.view_handle);
        }
    }
}

texture_manager_add :: (image: *RHIImage, view: *RHIImageView) -> TextureHandle {
    handle := alloc_handle(*g_texture_manager.texture_handle_manager);
    assert(handle > 0);

    view_handle := rdg_create_texture_view_handle(*g_view_registry, view);
    assert(view_handle > 0);

    if handle >= g_texture_manager.textures.count {
        array_resize(*g_texture_manager.textures, g_texture_manager.textures.count * 2);
    }

    g_texture_manager.textures[handle] = Texture.{
        image, view, view_handle
    };

    return cast(TextureHandle) handle;
}

texture_manager_free :: (handle: TextureHandle) {
    assert(handle != 0 && cast(u32) handle < g_texture_manager.textures.count);

    texture := g_texture_manager.textures[handle];
    rdg_destroy_handle(*g_view_registry, texture.view_handle);

    g_texture_manager.textures[handle] = .{};

    array_add(*g_texture_manager.textures_to_free[(g_texture_manager.textures_to_free_index + 1) % RDG_NUM_FRAMES], texture);
}

texture_manager_flush_deletions :: () {
    defer g_texture_manager.textures_to_free_index = (g_texture_manager.textures_to_free_index + 1) % RDG_NUM_FRAMES;

    textures_to_free := *g_texture_manager.textures_to_free[g_texture_manager.textures_to_free_index];

    for texture : (<< textures_to_free) {
        if texture.view != null then rhi_image_view_destroy(<< texture.view);
        if texture.image != null then rhi_image_destroy(<< texture.image);
    }
    array_reset_keeping_memory(textures_to_free);
}