#scope_export

RDGTextureViewHandle :: enum u32 {};
RDGRWTextureViewHandle :: enum u32 {};
RDGTypedBufferViewHandle :: enum u32 {};
RDGRWTypedBufferViewHandle :: enum u32 {};
RDGByteBufferViewHandle :: enum u32 {};
RDGRWByteBufferViewHandle :: enum u32 {};
RDGStructuredBufferViewHandle :: enum u32 {};
RDGRWStructuredBufferViewHandle :: enum u32 {};

RDGViewRegistry :: struct {
    texture_handles: HandleManager;
    rw_texture_handles: HandleManager;
    typed_buffer_handles: HandleManager;
    rw_typed_buffer_handles: HandleManager;
    byte_buffer_handles: HandleManager;
    rw_byte_buffer_handles: HandleManager;

    descriptor_set_pool: RHIDescriptorPool;
    descriptor_set_layout: RHIDescriptorSetLayout;
    descriptor_sets: [RDG_NUM_FRAMES] RHIDescriptorSet;

    pending_updates: [RDG_NUM_FRAMES][..] RHIDescriptorSetUpdate;
    frame_index: u32;
}

g_view_registry: RDGViewRegistry;

rdg_init_view_registry :: (using view_registry: *RDGViewRegistry) {
    texture_handles.max_handle = 65536;
    rw_texture_handles.max_handle = 65536;
    typed_buffer_handles.max_handle = 65536;
    rw_typed_buffer_handles.max_handle = 65536;
    byte_buffer_handles.max_handle = 65536;
    rw_byte_buffer_handles.max_handle = 65536;

    stages := RHIShaderStageFlags.ALL_STAGES;
    binding_flags := RHIDescriptorBindingFlags.UPDATE_AFTER_BIND_BIT | RHIDescriptorBindingFlags.PARTIALLY_BOUND_BIT;

    bindings := RHIDescriptorSetLayoutBinding.[
        .{.TEXTURE, RHI_TEXTURE_BINDING, 0, 65536, stages, binding_flags },
        .{.BYTE_BUFFER, RHI_BYTE_BUFFER_BINDING, 0, 65536, stages, binding_flags },
        .{.TYPED_BUFFER, RHI_TYPED_BUFFER_BINDING, 0, 65536, stages, binding_flags },
        .{.RW_TEXTURE, RHI_RW_TEXTURE_BINDING, 0, 65536, stages, binding_flags },
        .{.RW_BYTE_BUFFER, RHI_RW_BYTE_BUFFER_BINDING, 0, 65536, stages, binding_flags },
        .{.RW_TYPED_BUFFER, RHI_RW_TYPED_BUFFER_BINDING, 0, 65536, stages, binding_flags },
    ];

    view_registry.descriptor_set_layout = rhi_descriptor_set_layout_create(bindings);
    view_registry.descriptor_set_pool = rhi_descriptor_pool_create(2, *view_registry.descriptor_set_layout);
    rhi_descriptor_set_allocate(*view_registry.descriptor_set_pool, 2, view_registry.descriptor_sets);
}

rdg_destroy_view_registry :: (view_registry: *RDGViewRegistry) {
    rhi_descriptor_pool_destroy(view_registry.descriptor_set_pool);
    rhi_descriptor_set_layout_destroy(view_registry.descriptor_set_layout);
}

rdg_flush_resource_view_updates :: (view_registry: *RDGViewRegistry) {
    frame_index := view_registry.frame_index % RDG_NUM_FRAMES;

    rhi_descriptor_set_update(view_registry.descriptor_sets[frame_index], view_registry.pending_updates[frame_index]);
    array_reset_keeping_memory(*view_registry.pending_updates[frame_index]);
}

rdg_swap_sets :: (view_registry: *RDGViewRegistry) {
    free_transient_handles(*view_registry.texture_handles);
    free_transient_handles(*view_registry.rw_texture_handles);
    free_transient_handles(*view_registry.typed_buffer_handles);
    free_transient_handles(*view_registry.rw_typed_buffer_handles);
    free_transient_handles(*view_registry.byte_buffer_handles);
    free_transient_handles(*view_registry.rw_byte_buffer_handles);

    view_registry.frame_index += 1;
}

//-------------------------------------------------- CREATE --------------------------------------------------  
rdg_create_texture_view_handle :: (view_registry: *RDGViewRegistry, image_view: *RHIImageView, transient: bool = false) -> RDGTextureViewHandle {
    return cast(RDGTextureViewHandle) rdg_create_view_handle(view_registry, *view_registry.texture_handles, RHI_TEXTURE_BINDING, transient, .TEXTURE, image_view, null, null);
}

rdg_create_rw_texture_view_handle :: (view_registry: *RDGViewRegistry, image_view: *RHIImageView, transient: bool = false) -> RDGRWTextureViewHandle {
    return cast(RDGRWTextureViewHandle) rdg_create_view_handle(view_registry, *view_registry.rw_texture_handles, RHI_RW_TEXTURE_BINDING, transient, .RW_TEXTURE, image_view, null, null);
}

rdg_create_typed_buffer_view_handle :: (view_registry: *RDGViewRegistry, buffer_view: *RHIBufferView, transient: bool = false) -> RDGTypedBufferViewHandle {
    return cast(RDGTypedBufferViewHandle) rdg_create_view_handle(view_registry, *view_registry.typed_buffer_handles, RHI_TYPED_BUFFER_BINDING, transient, .TYPED_BUFFER, null, buffer_view, null);
}

rdg_create_rw_typed_buffer_view_handle :: (view_registry: *RDGViewRegistry, buffer_view: *RHIBufferView, transient: bool = false) -> RDGRWTypedBufferViewHandle {
    return cast(RDGRWTypedBufferViewHandle) rdg_create_view_handle(view_registry, *view_registry.rw_typed_buffer_handles, RHI_RW_TYPED_BUFFER_BINDING, transient, .RW_TYPED_BUFFER, null, buffer_view, null);
}

rdg_create_byte_buffer_view_handle :: (view_registry: *RDGViewRegistry, buffer_info: RHIDescriptorBufferInfo, transient: bool = false) -> RDGByteBufferViewHandle {
    return cast(RDGByteBufferViewHandle) rdg_create_view_handle(view_registry, *view_registry.byte_buffer_handles, RHI_BYTE_BUFFER_BINDING, transient, .BYTE_BUFFER, null, null, *buffer_info);
}

rdg_create_rw_byte_buffer_view_handle :: (view_registry: *RDGViewRegistry, buffer_info: RHIDescriptorBufferInfo, transient: bool = false) -> RDGRWByteBufferViewHandle {
    return cast(RDGRWByteBufferViewHandle) rdg_create_view_handle(view_registry, *view_registry.rw_byte_buffer_handles, RHI_RW_BYTE_BUFFER_BINDING, transient, .RW_BYTE_BUFFER, null, null, *buffer_info);
}

rdg_create_structured_buffer_view_handle :: (view_registry: *RDGViewRegistry, buffer_info: RHIDescriptorBufferInfo, transient: bool = false) -> RDGStructuredBufferViewHandle {
    return cast(RDGStructuredBufferViewHandle) rdg_create_view_handle(view_registry, *view_registry.byte_buffer_handles, RHI_BYTE_BUFFER_BINDING, transient, .STRUCTURED_BUFFER, null, null, *buffer_info);
}

rdg_create_rw_structured_buffer_view_handle :: (view_registry: *RDGViewRegistry, buffer_info: RHIDescriptorBufferInfo, transient: bool = false) -> RDGRWStructuredBufferViewHandle {
    return cast(RDGRWStructuredBufferViewHandle) rdg_create_view_handle(view_registry, *view_registry.rw_byte_buffer_handles, RHI_RW_BYTE_BUFFER_BINDING, transient, .RW_STRUCTURED_BUFFER, null, null, *buffer_info);
}

//-------------------------------------------------- DESTROY --------------------------------------------------  

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGTextureViewHandle) {
    rdg_destroy_view_handle(view_registry, *view_registry.texture_handles, xx handle, RHI_TEXTURE_BINDING);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGRWTextureViewHandle) {
    rdg_destroy_view_handle(view_registry, *view_registry.rw_texture_handles, xx handle, RHI_RW_TEXTURE_BINDING);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGTypedBufferViewHandle) {
    rdg_destroy_view_handle(view_registry, *view_registry.typed_buffer_handles, xx handle, RHI_TYPED_BUFFER_BINDING);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGRWTypedBufferViewHandle) {
    rdg_destroy_view_handle(view_registry, *view_registry.rw_typed_buffer_handles, xx handle, RHI_RW_TYPED_BUFFER_BINDING);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGByteBufferViewHandle) {
    rdg_destroy_view_handle(view_registry, *view_registry.byte_buffer_handles, xx handle, RHI_BYTE_BUFFER_BINDING);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGRWByteBufferViewHandle) {
    rdg_destroy_view_handle(view_registry, *view_registry.rw_byte_buffer_handles, xx handle, RHI_RW_BYTE_BUFFER_BINDING);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGStructuredBufferViewHandle) {
    rdg_destroy_handle(view_registry, cast(RDGByteBufferViewHandle)handle);
}

rdg_destroy_handle :: (view_registry: *RDGViewRegistry, handle: RDGRWStructuredBufferViewHandle) {
    rdg_destroy_handle(view_registry, cast(RDGRWByteBufferViewHandle)handle);
}

rdg_create_view_handle :: (view_registry: *RDGViewRegistry, handle_manager: *HandleManager, binding: u32, transient: bool = false, descriptor_type: RHIDescriptorType, image_view: *RHIImageView, buffer_view: *RHIBufferView, buffer_info: *RHIDescriptorBufferInfo) -> RDGResourceViewHandle{
    handle := alloc_handle(handle_manager, transient);

    if handle == 0 then return handle;

    update := RHIDescriptorSetUpdate.{
        descriptor_type = descriptor_type,
        dst_binding = binding,
        dst_array_element = cast(u32) handle,
        descriptor_count = 1,
        image_view = image_view,
        buffer_view = buffer_view,
    };
    if buffer_info {
        update.buffer_info = << buffer_info;
    }

    rdg_add_view_handle_update(view_registry, update, transient);
    
    return handle;
}

rdg_update_view_handle :: (view_registry: *RDGViewRegistry, handle: u32, binding: u32, descriptor_type: RHIDescriptorType, image_view: *RHIImageView, buffer_view: *RHIBufferView, buffer_info: *RHIDescriptorBufferInfo) {
    update := RHIDescriptorSetUpdate.{
        descriptor_type = descriptor_type,
        dst_binding = binding,
        dst_array_element = cast(u32) handle,
        descriptor_count = 1,
        image_view = image_view,
        buffer_view = buffer_view,
    };
    if buffer_info {
        update.buffer_info = << buffer_info;
    }

    // update_view_handle will only ever be called for non-transient resources
    rdg_add_view_handle_update(view_registry, update, transient = false);
}

rdg_destroy_view_handle :: (view_registry: *RDGViewRegistry, manager: *HandleManager, handle: u32, binding: u32) {
    for frame : 0..RDG_NUM_FRAMES-1 {
        for *pending : view_registry.pending_updates[frame] {
            if pending.dst_binding == binding && pending.dst_array_element == handle {
                remove pending;
            }
        }
    }
    free_handle(manager, handle);
}

rdg_add_view_handle_update :: (view_registry: *RDGViewRegistry, update: RHIDescriptorSetUpdate, transient: bool = false) {
    for frame : 0..RDG_NUM_FRAMES-1 {
        // only update transient views for the current frame
        if transient && (frame != view_registry.frame_index % RDG_NUM_FRAMES) {
            continue;
        }

        replaced_existing := false;

        for *pending : view_registry.pending_updates[frame] {
            if pending.dst_binding == update.dst_binding && pending.dst_array_element == update.dst_array_element {
                << pending = update;
                replaced_existing = true;
            }
        }
        if !replaced_existing {
            array_add(*view_registry.pending_updates[frame], update);
        }
    }
}
