#scope_export

rdg_import_image :: (rg: *RenderGraph, image: *RHIImage, name: string, resource_state_data: *RDGResourceStateData = null) -> RDGResourceHandle {
    image_desc := *image.desc;

    res_desc := RDGResourceDescription.{
        debug_name = name,
        usage_flags = cast(u32) image.desc.usage_flags,
        width = image_desc.extent.width,
        height = image_desc.extent.height,
        depth = image_desc.depth,
        layers = image_desc.layers,
        levels = image_desc.levels,
        samples = image_desc.samples,
        image_type = image_desc.image_type,
        format = image_desc.format,
        clear_value = image_desc.clear_value,
        subresource_count = image_desc.layers * image_desc.levels,
        subresource_usage_offset = xx rg.subresource_usages.count,
        external_state_data = resource_state_data,
        is_concurrent = false,
        is_external = true,
        is_image = true,
    };

    assert(res_desc.width != 0 && res_desc.height != 0 && res_desc.layers != 0 && res_desc.levels != 0);

    array_add(*rg.resource_descs, res_desc);

    for 0..res_desc.subresource_count-1 {
        unused := array_add(*rg.subresource_usages);
    }

    frame_resources := *rg.per_frame_resources[rg.frame_number % RDG_NUM_FRAMES];
    array_resize(*frame_resources.resources, rg.resource_descs.count);
    frame_resources.resources[frame_resources.resources.count - 1].image = image;
    frame_resources.resources[frame_resources.resources.count - 1].is_external = true;

    rhi_debug_set_object_name(image, name);

    return cast (RDGResourceHandle) rg.resource_descs.count;
}

rdg_create_image :: (rg: *RenderGraph, desc: RDGImageDescription) -> RDGResourceHandle {
    resource_desc := RDGResourceDescription.{
        debug_name = desc.debug_name,
        usage_flags = cast(u32) desc.usage_flags,
        width = desc.width,
        height = desc.height,
        depth = desc.depth,
        layers = desc.layers,
        levels = desc.levels,
        samples = desc.samples,
        image_type = desc.image_type,
        format = desc.format,
        clear_value = desc.clear_value,
        subresource_count = desc.layers * desc.levels,
        subresource_usage_offset = xx rg.subresource_usages.count,
        is_concurrent = false,
        is_image = true,
    };

    assert(resource_desc.width != 0 && resource_desc.height != 0 && resource_desc.layers != 0 && resource_desc.levels != 0);

    array_add(*rg.resource_descs, resource_desc);
    for 0..resource_desc.subresource_count-1 {
        unused := array_add(*rg.subresource_usages);
    }

    return cast(RDGResourceHandle) rg.resource_descs.count;
}

rdg_create_image_view :: (rg: *RenderGraph, image_handle: RDGResourceHandle, name: string) -> RDGResourceViewHandle {
    resource_desc := *rg.resource_descs[image_handle - 1];
    assert(resource_desc.is_image);

    desc := RDGImageViewDescription.{
        debug_name = name,
        image_handle = image_handle,
        subresource_range = .{0, resource_desc.levels, 0, resource_desc.layers},
        view_type = cast(RHIImageViewType) resource_desc.image_type,
        format = resource_desc.format,
        components = .{}
    };

    view_desc := RDGResourceViewDescription.{
        debug_name = desc.debug_name,
        resource_handle = desc.image_handle,
        view_type = desc.view_type,
        format = ifx desc.format == .UNDEFINED then resource_desc.format else desc.format,
        components = desc.components,
        subresource_range = desc.subresource_range,
        is_image = true,
    };

    array_add(*rg.view_descs, view_desc);

    if view_desc.format != resource_desc.format {
        resource_desc.image_flags |= .MUTABLE_FORMAT_BIT;
    }
    if view_desc.view_type == .CUBE || view_desc.view_type == .CUBE_ARRAY {
        resource_desc.image_flags |= .CUBE_COMPATIBLE_BIT;
    }
    if resource_desc.image_type == ._3D && view_desc.view_type == ._2D_ARRAY {
        resource_desc.image_flags |= ._2D_ARRAY_COMPATIBLE_BIT;
    }

    return cast (RDGResourceViewHandle) rg.view_descs.count;
}

rdg_get_image :: (view_handle: RDGResourceViewHandle) -> *RHIImage {
    rg := g_render_graph;
    frame_resources := *rg.per_frame_resources[rg.frame_number % RDG_NUM_FRAMES];

    return frame_resources.resources[rg.view_descs[view_handle - 1].resource_handle - 1].image;
}

rdg_get_image_view :: (view_handle: RDGResourceViewHandle) -> *RHIImageView {
    rg := g_render_graph;
    frame_resources := *rg.per_frame_resources[rg.frame_number % RDG_NUM_FRAMES];

    return frame_resources.views[view_handle - 1].image_view;
}