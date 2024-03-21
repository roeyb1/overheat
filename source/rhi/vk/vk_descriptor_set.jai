#scope_export

RHIDescriptorSetLayout :: struct {
    handle: VkDescriptorSetLayout;
    type_counts: [VkDescriptorType.INPUT_ATTACHMENT - VkDescriptorType.SAMPLER + 1] u32;
}

RHIDescriptorSet :: struct {
    handle: VkDescriptorSet;
    dynamic_buffer_count: u32;
}

RHIDescriptorPool :: struct {
    handle: VkDescriptorPool;
    descriptor_set_layout: *RHIDescriptorSetLayout;
    pool_size: u32;
    allocated_count: u32;
}

rhi_translate :: (descriptor_type: RHIDescriptorType) -> VkDescriptorType {
    if descriptor_type == {
        case .SAMPLER;
            return .SAMPLER;
        case .TEXTURE;
            return .SAMPLED_IMAGE;
        case .RW_TEXTURE;
            return .STORAGE_IMAGE;
        case .TYPED_BUFFER;
            return .UNIFORM_TEXEL_BUFFER;
        case .RW_TYPED_BUFFER;
            return .STORAGE_TEXEL_BUFFER;
        case .CONSTANT_BUFFER;
            return .UNIFORM_BUFFER;

        case .BYTE_BUFFER; #through;
        case .RW_BYTE_BUFFER; #through;
        case .STRUCTURED_BUFFER; #through;
        case .RW_STRUCTURED_BUFFER;
            return .STORAGE_BUFFER;

        case .OFFSET_CONSTANT_BUFFER;
            return .UNIFORM_BUFFER_DYNAMIC;
        case;
            assert(false);
            return 0;
    }
}

rhi_translate :: (binding_flags: RHIDescriptorBindingFlags) -> VkDescriptorBindingFlags {
    result: VkDescriptorBindingFlags = 0;

    if test_flag_bit(binding_flags, .UPDATE_AFTER_BIND_BIT) {
        result |= .UPDATE_AFTER_BIND_BIT;
    }
    if test_flag_bit(binding_flags, .UPDATE_UNUSED_WHILE_PENDING_BIT) {
        result |= .UPDATE_UNUSED_WHILE_PENDING_BIT;
    }
    if test_flag_bit(binding_flags, .PARTIALLY_BOUND_BIT) {
        result |= .PARTIALLY_BOUND_BIT;
    }

    return result;
}

rhi_descriptor_set_layout_create :: (bindings: [] RHIDescriptorSetLayoutBinding) -> RHIDescriptorSetLayout {
    push_allocator(temp);
    vk_bindings: [..] VkDescriptorSetLayoutBinding;
    vk_binding_flags: [..] VkDescriptorBindingFlags;

    array_resize(*vk_bindings, bindings.count);
    array_resize(*vk_binding_flags, bindings.count);

    
    for *binding : bindings {
        descriptor_type := rhi_translate(binding.descriptor_type);

        vk_bindings[it_index] = VkDescriptorSetLayoutBinding.{
            binding = binding.binding,
            descriptorType = descriptor_type,
            descriptorCount = xx binding.descriptor_count,
            stageFlags = rhi_translate(binding.stage_flags),
            pImmutableSamplers = null,
        };
        vk_binding_flags[it_index] = rhi_translate(binding.binding_flags);
    }

    result: RHIDescriptorSetLayout;

    for 0..bindings.count-1 {
        assert(bindings[it].descriptor_type < result.type_counts.count);
        result.type_counts[bindings[it].descriptor_type] += bindings[it].descriptor_count;
    }


    flags_create_info := VkDescriptorSetLayoutBindingFlagsCreateInfo.{
        bindingCount = xx vk_bindings.count,
        pBindingFlags = vk_binding_flags.data,
    };

    create_info := VkDescriptorSetLayoutCreateInfo.{
        flags = .UPDATE_AFTER_BIND_POOL_BIT,
        bindingCount = xx vk_bindings.count,
        pBindings = vk_bindings.data,
    };

    vk_check_result(vkCreateDescriptorSetLayout(device, *create_info, null, *result.handle));
    return result;
}

rhi_descriptor_set_layout_destroy :: (layout: RHIDescriptorSetLayout) {
    vkDestroyDescriptorSetLayout(device, layout.handle, null);
}

rhi_descriptor_pool_create :: (max_sets: u32, layout: *RHIDescriptorSetLayout) -> RHIDescriptorPool {
    pool_sizes: [(VkDescriptorType.INPUT_ATTACHMENT - VkDescriptorType.SAMPLER) + 1] VkDescriptorPoolSize;
    pool_size_count: u32;

    for 0..pool_sizes.count-1{
        pool_sizes[pool_size_count].type = cast(VkDescriptorType) it;
        pool_sizes[pool_size_count].descriptorCount = layout.type_counts[it] * max_sets;
        pool_size_count += 1;
    }

    assert(pool_size_count > 0);

    create_info := VkDescriptorPoolCreateInfo.{
        flags = .UPDATE_AFTER_BIND_BIT,
        maxSets = max_sets,
        poolSizeCount = pool_size_count,
        pPoolSizes = pool_sizes.data,
    };

    result := RHIDescriptorPool.{
        descriptor_set_layout = layout,
        pool_size = max_sets,
        allocated_count = 0,
    };

    vk_check_result(vkCreateDescriptorPool(device, *create_info, null, *result.handle));
    return result;
}

rhi_descriptor_pool_destroy :: (pool: RHIDescriptorPool) {
    vkDestroyDescriptorPool(device, pool.handle, null);
}

rhi_descriptor_pool_reset :: (pool: *RHIDescriptorPool) {
    vk_check_result(vkResetDescriptorPool(device, pool.handle, 0));
    pool.allocated_count = 0;
}

rhi_descriptor_set_allocate :: (pool: *RHIDescriptorPool, count: u32, out_descriptor_sets: [] RHIDescriptorSet) {
    assert(pool.allocated_count + count <= pool.pool_size);
    assert(out_descriptor_sets.count == count);

    layout := pool.descriptor_set_layout;

    dynamic_buffer_count := layout.type_counts[VkDescriptorType.UNIFORM_BUFFER_DYNAMIC];

    batch_size :: 8;
    iterations := (count + (batch_size - 1)) / batch_size;

    for 0..iterations-1 {
        handle_count := min(batch_size, count - it * batch_size);
        layout_handles: [batch_size] VkDescriptorSetLayout;
        for j : 0..handle_count-1 {
            layout_handles[j] = layout.handle;
        }

        alloc_info := VkDescriptorSetAllocateInfo.{
            descriptorPool = pool.handle,
            descriptorSetCount = xx handle_count,
            pSetLayouts = layout_handles.data,
        };

        set_handles: [batch_size] VkDescriptorSet;

        vk_check_result(vkAllocateDescriptorSets(device, *alloc_info, set_handles.data));

        for j : 0..handle_count-1 {
            out_descriptor_sets[it * batch_size + j] = RHIDescriptorSet.{
                handle = set_handles[j],
                dynamic_buffer_count = dynamic_buffer_count,
            };

            pool.allocated_count += 1;
        }
    }
}

rhi_descriptor_set_update :: (set: RHIDescriptorSet, updates: [] RHIDescriptorSetUpdate) {
    push_allocator(temp);

    batch_size :: 16;
    iterations := (updates.count + (batch_size -1)) / batch_size;

    for 0..iterations-1 {
        count := min(batch_size, updates.count - it * batch_size);

        image_infos: [..] VkDescriptorImageInfo;
        buffer_infos: [..] VkDescriptorBufferInfo;
        texel_buffer_views: [..] VkBufferView;

        image_infos_to_reserve := 0;
        buffer_infos_to_reserve := 0;
        texel_buffer_views_to_reserve := 0;

        for j : 0..count-1 {
            update := *updates[it * batch_size + j];
            if update.descriptor_type == {
                case .SAMPLER; #through;
                case .TEXTURE; #through;
                case .RW_TEXTURE;
                    image_infos_to_reserve += update.descriptor_count;
                case .TYPED_BUFFER; #through;
                case .RW_TYPED_BUFFER;
                    texel_buffer_views_to_reserve += update.descriptor_count;
                case .CONSTANT_BUFFER; #through;
                case .BYTE_BUFFER; #through;
                case .RW_BYTE_BUFFER; #through;
                case .STRUCTURED_BUFFER; #through;
                case .RW_STRUCTURED_BUFFER;
                    buffer_infos_to_reserve += update.descriptor_count;
                case .OFFSET_CONSTANT_BUFFER;
                    buffer_infos_to_reserve += 1;
                case;
                    assert(false);
            }
        }

        array_reserve(*image_infos, image_infos_to_reserve);
        array_reserve(*buffer_infos, buffer_infos_to_reserve);
        array_reserve(*texel_buffer_views, texel_buffer_views_to_reserve);

        writes: [batch_size] VkWriteDescriptorSet;
        for j : 0..count-1 {
            update := *updates[it * batch_size + j];
            
            write := *writes[j];
            write.dstSet = set.handle;
            write.dstBinding = update.dst_binding;
            write.dstArrayElement = update.dst_array_element;
            write.descriptorCount = update.descriptor_count;

            if update.descriptor_type == {
                case .SAMPLER;
                    for k : 0..update.descriptor_count-1 {
                        sampler := ifx update.samplers.count > 0 then update.samplers[k] else update.sampler;
                        array_add(*image_infos, VkDescriptorImageInfo.{sampler.handle, VK_NULL_HANDLE, .UNDEFINED});
                    }
                    write.descriptorType = .SAMPLER;
                    write.pImageInfo = image_infos.data + (image_infos.count - update.descriptor_count);
                case .TEXTURE;
                    for k : 0..update.descriptor_count-1 {
                        image_view := ifx update.image_views.count > 0 then update.image_views[k] else update.image_view;
                        format := image_view.desc.format;
                        layout: VkImageLayout = ifx rhi_is_depth_format(format) || rhi_is_stencil_format(format) then .DEPTH_STENCIL_READ_ONLY_OPTIMAL else .SHADER_READ_ONLY_OPTIMAL;
                        array_add(*image_infos, VkDescriptorImageInfo.{VK_NULL_HANDLE, image_view.handle, layout});
                    }
                    write.descriptorType = .SAMPLED_IMAGE;
                    write.pImageInfo = image_infos.data + (image_infos.count - update.descriptor_count);
                case .RW_TEXTURE;
                    for k : 0..update.descriptor_count-1 {
                        image_view := ifx update.image_views.count > 0 then update.image_views[k] else update.image_view;
                        array_add(*image_infos, VkDescriptorImageInfo.{VK_NULL_HANDLE, image_view.handle, .GENERAL});
                    }
                    write.descriptorType = .STORAGE_IMAGE;
                    write.pImageInfo = image_infos.data + (image_infos.count - update.descriptor_count);
                case .TYPED_BUFFER;
                    for k : 0..update.descriptor_count-1 {
                        buffer_view := ifx update.buffer_views.count > 0 then update.buffer_views[k] else update.buffer_view;
                        array_add(*texel_buffer_views, buffer_view.handle);
                    }
                    write.descriptorType = .UNIFORM_TEXEL_BUFFER;
                    write.pTexelBufferView = texel_buffer_views.data + (texel_buffer_views.count - update.descriptor_count);
                case .RW_TYPED_BUFFER;
                    for k : 0..update.descriptor_count-1 {
                        buffer_view := ifx update.buffer_views.count > 0 then update.buffer_views[k] else update.buffer_view;
                        array_add(*texel_buffer_views, buffer_view.handle);
                    }
                    write.descriptorType = .STORAGE_TEXEL_BUFFER;
                    write.pTexelBufferView = texel_buffer_views.data + (texel_buffer_views.count - update.descriptor_count);
                case .CONSTANT_BUFFER;
                    for k : 0..update.descriptor_count-1 {
                        buffer_info := ifx update.buffer_infos.count > 0 then update.buffer_infos[k] else *update.buffer_info;
                        array_add(*buffer_infos, VkDescriptorBufferInfo.{buffer_info.buffer.handle, buffer_info.offset, buffer_info.range});
                    }
                    write.descriptorType = .UNIFORM_BUFFER;
                    write.pBufferInfo = buffer_infos.data + (buffer_infos.count - update.descriptor_count);
                case .BYTE_BUFFER; #through;
                case .RW_BYTE_BUFFER; #through;
                case .STRUCTURED_BUFFER; #through;
                case .RW_STRUCTURED_BUFFER;
                    for k : 0..update.descriptor_count-1 {
                        buffer_info := ifx update.buffer_infos.count > 0 then update.buffer_infos[k] else *update.buffer_info;
                        array_add(*buffer_infos, VkDescriptorBufferInfo.{buffer_info.buffer.handle, buffer_info.offset, buffer_info.range});
                    }
                    write.descriptorType = .STORAGE_BUFFER;
                    write.pBufferInfo = buffer_infos.data + (buffer_infos.count - update.descriptor_count);
                case .OFFSET_CONSTANT_BUFFER;
                    buffer_info := ifx update.buffer_infos.count > 0 then update.buffer_infos[0] else *update.buffer_info;
                    array_add(*buffer_infos, VkDescriptorBufferInfo.{buffer_info.buffer.handle, buffer_info.offset, buffer_info.range});
                    write.descriptorType = .UNIFORM_BUFFER_DYNAMIC;
                    write.pBufferInfo = buffer_infos.data + (buffer_infos.count - 1);
                case;
                    assert(false);
            }
        }

        vkUpdateDescriptorSets(device, xx count, writes.data, 0, null);
    }
}