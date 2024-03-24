#scope_export

RHILinearGPUAllocator :: struct {
    buffer: *RHIBuffer;
    
    buffer_size: s64;
    current_offset: s64;
    mapped_ptr: *void;
}

rhi_linear_allocator_init :: (buffer: *RHIBuffer) -> RHILinearGPUAllocator {
    allocator: RHILinearGPUAllocator;
    allocator.buffer = buffer;
    allocator.mapped_ptr = rhi_buffer_map(buffer);
    allocator.buffer_size = xx buffer.desc.size;
    allocator.current_offset = 0;
    return allocator;
}

rhi_linear_allocator_destroy :: (allocator: *RHILinearGPUAllocator) {
    rhi_buffer_unmap(allocator.buffer);
}

rhi_allocate :: (allocator: *RHILinearGPUAllocator, alignment: s64, size: s64) -> (mapped_ptr: *void, offset: s64) {
    assert(size > 0);

    // align the starting offset forward until it aligns with the requried alignment
    aligned_offset := align_forward(allocator.current_offset, alignment);
    // new current offset after the allocation
    new_offset := align_forward(allocator.current_offset + size, alignment);

    if new_offset > allocator.buffer_size {
        // buffer ran out of memory!
        log_error("Linear GPU buffer out of memory! %", << allocator.buffer);
        return null, 0;
    }

    allocator.current_offset = new_offset;
    
    return allocator.mapped_ptr + aligned_offset, aligned_offset;

}

rhi_reset :: (allocator: *RHILinearGPUAllocator) {
    allocator.current_offset = 0;
}

rhi_upload_struct :: (allocator: *RHILinearGPUAllocator, descriptor_type: RHIDescriptorType, data: $T) -> s64 {
    size: s64 = size_of(T);
    
    mapped_ptr, allocation_offset := rhi_allocate(allocator, rhi_get_buffer_alignment(descriptor_type, size), size);
    if mapped_ptr != null {
        memcpy(mapped_ptr, *data, size);
        return allocation_offset;
    }

    assert(false);
    return -1;
}