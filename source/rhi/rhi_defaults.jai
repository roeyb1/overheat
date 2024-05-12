#scope_export

RHI_TEXTURE_BINDING :: 0;
RHI_RW_TEXTURE_BINDING :: 1;
RHI_TYPED_BUFFER_BINDING :: 2;
RHI_RW_TYPED_BUFFER_BINDING :: 3;
RHI_BYTE_BUFFER_BINDING :: 4;
RHI_RW_BYTE_BUFFER_BINDING :: 5;

rhi_bindless_descriptor_set_layout_binding :: (type: RHIDescriptorType, space: u32, stage_flags: RHIShaderStageFlags) -> RHIDescriptorSetLayoutBinding {
    binding := RHIDescriptorSetLayoutBinding.{
        descriptor_type = type,
        space = space,
        descriptor_count = 65536,
        stage_flags = stage_flags,
        binding_flags = .UPDATE_AFTER_BIND_BIT | .PARTIALLY_BOUND_BIT,
    };

    if type == {
        case .TEXTURE;
            binding.binding = RHI_TEXTURE_BINDING;
        case .RW_TEXTURE;
            binding.binding = RHI_RW_TEXTURE_BINDING;
        case .TYPED_BUFFER;
            binding.binding = RHI_TYPED_BUFFER_BINDING;
        case .RW_TYPED_BUFFER;
            binding.binding = RHI_RW_TYPED_BUFFER_BINDING;
        case .BYTE_BUFFER;
        case .STRUCTURED_BUFFER;
            binding.binding = RHI_BYTE_BUFFER_BINDING;
        case .RW_BYTE_BUFFER;
        case .RW_STRUCTURED_BUFFER;
            binding.binding = RHI_RW_BYTE_BUFFER_BINDING;
        case; assert(false);
    }

    return binding;
}

rhi_static_point_clamp_sampler :: (binding: u32, space: u32, stage_flags: RHIShaderStageFlags) -> RHIStaticSamplerDesc {
    desc := RHIStaticSamplerDesc.{
        binding = binding,
        space = space,
        stage_flags = stage_flags,
        mag_filter = .NEAREST,
        min_filter = .NEAREST,
        mipmap_mode = .NEAREST,
        address_mode_u = .CLAMP_TO_EDGE,
        address_mode_v = .CLAMP_TO_EDGE,
        address_mode_w = .CLAMP_TO_EDGE,
        mip_lod_bias = 0.,
        anisotropy_enable = false,
        max_anisotropy = 1.,
        compare_enable = false,
        compare_op = .ALWAYS,
        min_lod = 0.,
        max_lod = FLOAT32_MAX,
        border_color = .FLOAT_OPAQUE_BLACK,
        unnormalized_coordinates = false,
    };

    return desc;
}

rhi_static_anisotropic_repeat_sampler :: (binding: u32, space: u32, stage_flags: RHIShaderStageFlags) -> RHIStaticSamplerDesc {
    desc := RHIStaticSamplerDesc.{
        binding = binding,
        space = space,
        stage_flags = stage_flags,
        mag_filter = .LINEAR,
        min_filter = .LINEAR,
        mipmap_mode = .LINEAR,
        address_mode_u = .REPEAT,
        address_mode_v = .REPEAT,
        address_mode_w = .REPEAT,
        mip_lod_bias = 0.,
        anisotropy_enable = true,
        max_anisotropy = 16.,
        compare_enable = false,
        compare_op = .ALWAYS,
        min_lod = 0.,
        max_lod = FLOAT32_MAX,
        border_color = .FLOAT_OPAQUE_BLACK,
        unnormalized_coordinates = false,
    };

    return desc;
}

rhi_static_linear_clamp_sampler :: (binding: u32, space: u32, stage_flags: RHIShaderStageFlags) -> RHIStaticSamplerDesc {
    desc := RHIStaticSamplerDesc.{
        binding = binding,
        space = space,
        stage_flags = stage_flags,
        mag_filter = .LINEAR,
        min_filter = .LINEAR,
        mipmap_mode = .LINEAR,
        address_mode_u = .CLAMP_TO_EDGE,
        address_mode_v = .CLAMP_TO_EDGE,
        address_mode_w = .CLAMP_TO_EDGE,
        mip_lod_bias = 0.,
        anisotropy_enable = false,
        max_anisotropy = 1.,
        compare_enable = false,
        compare_op = .ALWAYS,
        min_lod = 0.,
        max_lod = FLOAT32_MAX,
        border_color = .FLOAT_OPAQUE_BLACK,
        unnormalized_coordinates = false,
    };

    return desc;
}

rhi_static_linear_repeat_sampler :: (binding: u32, space: u32, stage_flags: RHIShaderStageFlags) -> RHIStaticSamplerDesc {
    desc := RHIStaticSamplerDesc.{
        binding = binding,
        space = space,
        stage_flags = stage_flags,
        mag_filter = .LINEAR,
        min_filter = .LINEAR,
        mipmap_mode = .LINEAR,
        address_mode_u = .REPEAT,
        address_mode_v = .REPEAT,
        address_mode_w = .REPEAT,
        mip_lod_bias = 0.,
        anisotropy_enable = false,
        max_anisotropy = 1.,
        compare_enable = false,
        compare_op = .ALWAYS,
        min_lod = 0.,
        max_lod = FLOAT32_MAX,
        border_color = .FLOAT_OPAQUE_BLACK,
        unnormalized_coordinates = false,
    };

    return desc;
}
