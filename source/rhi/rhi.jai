#scope_export

RHIBackend :: enum {
    VULKAN;
    DX12;  // NYI
}

RHIQueueType :: enum {
    GRAPHICS;
    COMPUTE;
    TRANSFER;
}

RHIResourceState :: enum_flags {
    UNDEFINED                   :: 0;
    READ_RESOURCE               :: 1 << 0;
    READ_DEPTH_STENCIL          :: 1 << 1;
    READ_CONSTANT_BUFFER        :: 1 << 2;
    READ_VERTEX_BUFFER          :: 1 << 3;
    READ_INDEX_BUFFER           :: 1 << 4;
    READ_INDIRECT_BUFFER        :: 1 << 5;
    READ_TRANSFER               :: 1 << 6;
    WRITE_DEPTH_STENCIL         :: 1 << 7;
    WRITE_COLOR_ATTACHMENT      :: 1 << 8;
    WRITE_TRANSFER              :: 1 << 9;
    CLEAR_RESOURCE              :: 1 << 10;
    RW_RESOURCE                 :: 1 << 11;
    RW_RESOURCE_READ_ONLY       :: 1 << 12;
    RW_RESOURCE_WRITE_ONLY      :: 1 << 13;
    PRESENT                     :: 1 << 14;
}    

RHIPipelineStageFlags :: enum_flags {
    TOP_OF_PIPE_BIT             :: 0x00000001;
    DRAW_INDIRECT_BIT           :: 0x00000002;
    VERTEX_INPUT_BIT            :: 0x00000004;
    VERTEX_SHADER_BIT           :: 0x00000008;
    HULL_SHADER_BIT             :: 0x00000010;
    DOMAIN_SHADER_BIT           :: 0x00000020;
    GEOMETRY_SHADER_BIT         :: 0x00000040;
    PIXEL_SHADER_BIT            :: 0x00000080;
    EARLY_FRAGMENT_TESTS_BIT    :: 0x00000100;
    LATE_FRAGMENT_TESTS_BIT     :: 0x00000200;
    COLOR_ATTACHMENT_OUTPUT_BIT :: 0x00000400;
    COMPUTE_SHADER_BIT          :: 0x00000800;
    TRANSFER_BIT                :: 0x00001000;
    BOTTOM_OF_PIPE_BIT          :: 0x00002000;
    HOST_BIT                    :: 0x00004000;
    CLEAR_BIT                   :: 0x00050000;
}

RHISampleCount :: enum u32 {
    _1  :: 0x01;
    _2  :: 0x02;
    _4  :: 0x04;
    _8  :: 0x08;
    _16 :: 0x10;
    _32 :: 0x20;
    _64 :: 0x40;
}

RHIImageType :: enum u32 {
    _1D :: 0;
    _2D :: 1;
    _3D :: 2;
    CUBE :: 3;
    _1D_ARRAY :: 4;
    _2D_ARRAY :: 5;
    CUBE_ARRAY :: 6;
}

RHIImageViewType :: enum {
    _1D :: 0;
    _2D :: 1;
    _3D :: 2;
    CUBE :: 3;
    _1D_ARRAY :: 4;
    _2D_ARRAY :: 5;
    CUBE_ARRAY :: 6;
}

RHIClearColorValue :: union {
    _float32: [4] float;
    int32:    [4] s32;
    uint32:   [4] u32;
}

RHIClearDepthStencilValue :: struct {
    depth:   float;
    stencil: u32;
}

RHIClearValue :: union {
    color: RHIClearColorValue;
    depth_stencil: RHIClearDepthStencilValue;
}

RHIPresentMode :: enum {
    V_SYNC;
    IMMEDIATE;
}

Extent2D :: struct {
    width: u32;
    height: u32;
}

Extent3D :: struct {
    // using Extent2D?
    width: u32;
    height: u32;
    depth: u32;
}

Offset2D :: struct {
    x: s32;
    y: s32;
}

Offset3D :: struct {
    x: s32;
    y: s32;
    z: s32;
}

RHIImageUsageFlags :: enum_flags u32 {
    TRANSFER_SRC_BIT                :: 1 << 0;
    TRANSFER_DST_BIT                :: 1 << 1;
    TEXTURE_BIT                     :: 1 << 2;
    RW_TEXTURE_BIT                  :: 1 << 3;
    COLOR_ATTACHMENT_BIT            :: 1 << 4;
    DEPTH_STENCIL_ATTACHMENT_BIT    :: 1 << 5;
    CLEAR_BIT                       :: 1 << 6;
}

RHIImageCreateFlags :: enum_flags u32 {
    MUTABLE_FORMAT_BIT          :: 0x08;
    CUBE_COMPATIBLE_BIT         :: 0x10;
    _2D_ARRAY_COMPATIBLE_BIT    :: 0x20;
}

RHIImageFlags :: enum_flags {
    MUTABLE_FORMAT_BIT :: 0x00000008;
    CUBE_COMPATIBLE_BIT :: 0x00000010;
    _2D_ARRAY_COMPATIBLE_BIT :: 0x00000020;
}

RHIFormat :: enum u32 {
    UNDEFINED                                      :: 0;
    R4G4_UNORM_PACK8                               :: 1;
    R4G4B4A4_UNORM_PACK16                          :: 2;
    B4G4R4A4_UNORM_PACK16                          :: 3;
    R5G6B5_UNORM_PACK16                            :: 4;
    B5G6R5_UNORM_PACK16                            :: 5;
    R5G5B5A1_UNORM_PACK16                          :: 6;
    B5G5R5A1_UNORM_PACK16                          :: 7;
    A1R5G5B5_UNORM_PACK16                          :: 8;
    R8_UNORM                                       :: 9;
    R8_SNORM                                       :: 10;
    R8_USCALED                                     :: 11;
    R8_SSCALED                                     :: 12;
    R8_UINT                                        :: 13;
    R8_SINT                                        :: 14;
    R8_SRGB                                        :: 15;
    R8G8_UNORM                                     :: 16;
    R8G8_SNORM                                     :: 17;
    R8G8_USCALED                                   :: 18;
    R8G8_SSCALED                                   :: 19;
    R8G8_UINT                                      :: 20;
    R8G8_SINT                                      :: 21;
    R8G8_SRGB                                      :: 22;
    R8G8B8_UNORM                                   :: 23;
    R8G8B8_SNORM                                   :: 24;
    R8G8B8_USCALED                                 :: 25;
    R8G8B8_SSCALED                                 :: 26;
    R8G8B8_UINT                                    :: 27;
    R8G8B8_SINT                                    :: 28;
    R8G8B8_SRGB                                    :: 29;
    B8G8R8_UNORM                                   :: 30;
    B8G8R8_SNORM                                   :: 31;
    B8G8R8_USCALED                                 :: 32;
    B8G8R8_SSCALED                                 :: 33;
    B8G8R8_UINT                                    :: 34;
    B8G8R8_SINT                                    :: 35;
    B8G8R8_SRGB                                    :: 36;
    R8G8B8A8_UNORM                                 :: 37;
    R8G8B8A8_SNORM                                 :: 38;
    R8G8B8A8_USCALED                               :: 39;
    R8G8B8A8_SSCALED                               :: 40;
    R8G8B8A8_UINT                                  :: 41;
    R8G8B8A8_SINT                                  :: 42;
    R8G8B8A8_SRGB                                  :: 43;
    B8G8R8A8_UNORM                                 :: 44;
    B8G8R8A8_SNORM                                 :: 45;
    B8G8R8A8_USCALED                               :: 46;
    B8G8R8A8_SSCALED                               :: 47;
    B8G8R8A8_UINT                                  :: 48;
    B8G8R8A8_SINT                                  :: 49;
    B8G8R8A8_SRGB                                  :: 50;
    A8B8G8R8_UNORM_PACK32                          :: 51;
    A8B8G8R8_SNORM_PACK32                          :: 52;
    A8B8G8R8_USCALED_PACK32                        :: 53;
    A8B8G8R8_SSCALED_PACK32                        :: 54;
    A8B8G8R8_UINT_PACK32                           :: 55;
    A8B8G8R8_SINT_PACK32                           :: 56;
    A8B8G8R8_SRGB_PACK32                           :: 57;
    A2R10G10B10_UNORM_PACK32                       :: 58;
    A2R10G10B10_SNORM_PACK32                       :: 59;
    A2R10G10B10_USCALED_PACK32                     :: 60;
    A2R10G10B10_SSCALED_PACK32                     :: 61;
    A2R10G10B10_UINT_PACK32                        :: 62;
    A2R10G10B10_SINT_PACK32                        :: 63;
    A2B10G10R10_UNORM_PACK32                       :: 64;
    A2B10G10R10_SNORM_PACK32                       :: 65;
    A2B10G10R10_USCALED_PACK32                     :: 66;
    A2B10G10R10_SSCALED_PACK32                     :: 67;
    A2B10G10R10_UINT_PACK32                        :: 68;
    A2B10G10R10_SINT_PACK32                        :: 69;
    R16_UNORM                                      :: 70;
    R16_SNORM                                      :: 71;
    R16_USCALED                                    :: 72;
    R16_SSCALED                                    :: 73;
    R16_UINT                                       :: 74;
    R16_SINT                                       :: 75;
    R16_SFLOAT                                     :: 76;
    R16G16_UNORM                                   :: 77;
    R16G16_SNORM                                   :: 78;
    R16G16_USCALED                                 :: 79;
    R16G16_SSCALED                                 :: 80;
    R16G16_UINT                                    :: 81;
    R16G16_SINT                                    :: 82;
    R16G16_SFLOAT                                  :: 83;
    R16G16B16_UNORM                                :: 84;
    R16G16B16_SNORM                                :: 85;
    R16G16B16_USCALED                              :: 86;
    R16G16B16_SSCALED                              :: 87;
    R16G16B16_UINT                                 :: 88;
    R16G16B16_SINT                                 :: 89;
    R16G16B16_SFLOAT                               :: 90;
    R16G16B16A16_UNORM                             :: 91;
    R16G16B16A16_SNORM                             :: 92;
    R16G16B16A16_USCALED                           :: 93;
    R16G16B16A16_SSCALED                           :: 94;
    R16G16B16A16_UINT                              :: 95;
    R16G16B16A16_SINT                              :: 96;
    R16G16B16A16_SFLOAT                            :: 97;
    R32_UINT                                       :: 98;
    R32_SINT                                       :: 99;
    R32_SFLOAT                                     :: 100;
    R32G32_UINT                                    :: 101;
    R32G32_SINT                                    :: 102;
    R32G32_SFLOAT                                  :: 103;
    R32G32B32_UINT                                 :: 104;
    R32G32B32_SINT                                 :: 105;
    R32G32B32_SFLOAT                               :: 106;
    R32G32B32A32_UINT                              :: 107;
    R32G32B32A32_SINT                              :: 108;
    R32G32B32A32_SFLOAT                            :: 109;
    R64_UINT                                       :: 110;
    R64_SINT                                       :: 111;
    R64_SFLOAT                                     :: 112;
    R64G64_UINT                                    :: 113;
    R64G64_SINT                                    :: 114;
    R64G64_SFLOAT                                  :: 115;
    R64G64B64_UINT                                 :: 116;
    R64G64B64_SINT                                 :: 117;
    R64G64B64_SFLOAT                               :: 118;
    R64G64B64A64_UINT                              :: 119;
    R64G64B64A64_SINT                              :: 120;
    R64G64B64A64_SFLOAT                            :: 121;
    B10G11R11_UFLOAT_PACK32                        :: 122;
    E5B9G9R9_UFLOAT_PACK32                         :: 123;
    D16_UNORM                                      :: 124;
    X8_D24_UNORM_PACK32                            :: 125;
    D32_SFLOAT                                     :: 126;
    S8_UINT                                        :: 127;
    D16_UNORM_S8_UINT                              :: 128;
    D24_UNORM_S8_UINT                              :: 129;
    D32_SFLOAT_S8_UINT                             :: 130;
    BC1_RGB_UNORM_BLOCK                            :: 131;
    BC1_RGB_SRGB_BLOCK                             :: 132;
    BC1_RGBA_UNORM_BLOCK                           :: 133;
    BC1_RGBA_SRGB_BLOCK                            :: 134;
    BC2_UNORM_BLOCK                                :: 135;
    BC2_SRGB_BLOCK                                 :: 136;
    BC3_UNORM_BLOCK                                :: 137;
    BC3_SRGB_BLOCK                                 :: 138;
    BC4_UNORM_BLOCK                                :: 139;
    BC4_SNORM_BLOCK                                :: 140;
    BC5_UNORM_BLOCK                                :: 141;
    BC5_SNORM_BLOCK                                :: 142;
    BC6H_UFLOAT_BLOCK                              :: 143;
    BC6H_SFLOAT_BLOCK                              :: 144;
    BC7_UNORM_BLOCK                                :: 145;
    BC7_SRGB_BLOCK                                 :: 146;
}

RHIBufferUsageFlags :: enum_flags {
    TRANSFER_SRC_BIT            :: 1 << 0;
    TRANSFER_DST_BIT            :: 1 << 1;
    TYPED_BUFFER_BIT            :: 1 << 2;
    RW_TYPED_BUFFER_BIT         :: 1 << 3;
    CONSTANT_BUFFER_BIT         :: 1 << 4;
    BYTE_BUFFER_BIT             :: 1 << 5;
    RW_BYTE_BUFFER_BIT          :: 1 << 6;
    STRUCTURED_BUFFER_BIT       :: 1 << 7;
    RW_STRUCTURED_BUFFER_BIT    :: 1 << 8;
    INDEX_BUFFER_BIT            :: 1 << 9;
    VERTEX_BUFFER_BIT           :: 1 << 10;
    INDIRECT_BUFFER_BIT         :: 1 << 11;
    CLEAR_BIT                   :: 1 << 12;
    SHADER_DEVICE_ADDRESS_BIT   :: 1 << 13;
}

RHIComponentSwizzle :: enum {
    IDENTITY :: 0;
    ZERO :: 1;
    ONE :: 2;
    R :: 3;
    G :: 4;
    B :: 5;
    A :: 6;
}

RHIComponentMapping :: struct {
    r: RHIComponentSwizzle;
    g: RHIComponentSwizzle;
    b: RHIComponentSwizzle;
    a: RHIComponentSwizzle;
}

RHIImageCreateInfo :: struct {
    extent: Extent2D = .{1, 1};
    depth: u32 = 1;
    layers: u32 = 1;
    levels: u32 = 1;
    samples: RHISampleCount = ._1;
    image_type: RHIImageType = ._2D;
    format: RHIFormat;
    usage_flags: RHIImageUsageFlags = 0;
    create_flags: RHIImageCreateFlags = 0;
    clear_value: RHIClearValue;
}

RHIImageViewCreateInfo :: struct {
    image: *RHIImage;
    view_type: RHIImageViewType = ._2D;
    format: RHIFormat = .UNDEFINED;
    components: RHIComponentMapping;
    base_mip_level: u32 = 0;
    level_count: u32 = 0;
    base_array_layer: u32 = 0;
    layer_count: u32 = 0;
}

RHIImageSubresourceRange :: struct {
    base_mip_level: u32 = 0;
    level_count: u32 = 0;
    base_array_layer: u32 = 0;
    layer_count: u32 = 0;
}

RHIImageCopy :: struct {
    src_mip_level: u32;
    src_base_layer: u32;
    src_layer_count: u32;
    src_offset: Offset3D;

    dst_mip_level: u32;
    dst_base_layer: u32;
    dst_layer_count: u32;
    dst_offset: Offset3D;

    extent: Extent3D;
}

RHIBarrierFlags :: enum_flags {
    QUEUE_OWNERSHIP_RELEASE :: 1 << 0;
    QUEUE_OWNERSHIP_ACQUIRE :: 1 << 1;
    FIRST_ACCESS_IN_SUBMISSION :: 1 << 2;
    BARRIER_BEGIN :: 1 << 3;
    BARRIER_END :: 1 << 4;
}

RHIBarrier :: struct {
    image: *RHIImage;
    buffer: *RHIBuffer;
    stages_before: RHIPipelineStageFlags;
    stages_after: RHIPipelineStageFlags;
    state_before: RHIResourceState;
    state_after: RHIResourceState;
    src_queue: *RHIQueue;
    dst_queue: *RHIQueue;
    image_subresource_range: RHIImageSubresourceRange;
    flags: RHIBarrierFlags;
}

RHIBufferCreateFlags :: enum_flags {

}

RHIBufferCreateInfo :: struct {
    size: u64;
    create_flags: RHIBufferCreateFlags = 0;
    usage_flags: RHIBufferUsageFlags = 0;
}

RHIBufferViewCreateInfo :: struct {
    buffer: *RHIBuffer;
    format: RHIFormat;
    offset: u64;
    range: u64;
}

RHIDescriptorType :: enum {
    SAMPLER;
    TEXTURE;
    RW_TEXTURE;
    TYPED_BUFFER;
    RW_TYPED_BUFFER;
    CONSTANT_BUFFER;
    BYTE_BUFFER;
    RW_BYTE_BUFFER;
    STRUCTURED_BUFFER;
    RW_STRUCTURED_BUFFER;
    OFFSET_CONSTANT_BUFFER;
}

RHIDescriptorBindingFlags :: enum_flags {
    UPDATE_AFTER_BIND_BIT :: 1 << 0;
    UPDATE_UNUSED_WHILE_PENDING_BIT :: 1 << 1;
    PARTIALLY_BOUND_BIT :: 1 << 2;
}

RHIDescriptorSetUpdate :: struct {
    dst_binding: u32;
    dst_array_element: u32;
    descriptor_count: u32;
    descriptor_type: RHIDescriptorType;
    samplers: [] *RHISampler;
    image_views: [] *RHIImageView;
    buffer_views: [] *RHIBufferView;
    buffer_infos: [] *RHIDescriptorBufferInfo;
    sampler: *RHISampler;
    image_view: *RHIImageView;
    buffer_view: *RHIBufferView;
    buffer_info: RHIDescriptorBufferInfo;
}

RHIDescriptorSetLayoutBinding :: struct {
    descriptor_type: RHIDescriptorType;
    binding: u32;
    space: u32;
    descriptor_count: u32;
    stage_flags: RHIShaderStageFlags;
    binding_flags: RHIDescriptorBindingFlags;
}

RHIDescriptorBufferInfo :: struct {
    buffer: *RHIBuffer;
    offset: u64;
    range: u64;
    structure_byte_stride: u64;
}

RHIShaderStageFlags :: enum_flags {
    VERTEX_BIT      :: 0x00000001;
    HULL_BIT        :: 0x00000002;
    DOMAIN_BIT      :: 0x00000004;
    GEOMETRY_BIT    :: 0x00000008;
    PIXEL_BIT       :: 0x00000010;
    COMPUTE_BIT     :: 0x00000020;
    ALL_STAGES      :: VERTEX_BIT | HULL_BIT | DOMAIN_BIT | GEOMETRY_BIT | PIXEL_BIT | COMPUTE_BIT;
};

RHIMemoryPropertyFlags :: enum_flags {
    DEVICE_LOCAL_BIT    :: 0x01;
    HOST_VISIBLE_BIT    :: 0x02;
    HOST_COHERENT_BIT   :: 0x04;
    HOST_CACHED_BIT     :: 0x08;
}

RHIShaderStageCreateInfo :: struct {
    path: string;
}

RHIVertexInputRate :: enum {
    VERTEX;
    INSTANCE;
}

RHIVertexInputBindingDesc :: struct {
    binding: u32;
    stride: u32;
    input_rate: RHIVertexInputRate;
}

RHIVertexInputAttributeDesc :: struct {
    name: string;
    location: u32;
    binding: u32;
    format: RHIFormat;
    offset: u32;
}

RHIVertexInputState :: struct {
    MAX_VERTEX_BINDING_DESCRIPTIONS     :: 8;
    MAX_VERTEX_ATTRIBUTE_DESCRIPTIONS   :: 8;

    vertex_binding_count: u32 = 0;
    vertex_binding_descs: [MAX_VERTEX_BINDING_DESCRIPTIONS] RHIVertexInputBindingDesc;
    vertex_attribute_count: u32 = 0;
    vertex_attribute_descs: [MAX_VERTEX_ATTRIBUTE_DESCRIPTIONS] RHIVertexInputAttributeDesc;
}

RHIPrimitiveTopology :: enum {
    POINT_LIST                      :: 0;
    LINE_LIST                       :: 1;
    LINE_STRIP                      :: 2;
    TRIANGLE_LIST                   :: 3;
    TRIANGLE_STRIP                  :: 4;
    TRIANGLE_FAN                    :: 5;
    LINE_LIST_WITH_ADJACENCY        :: 6;
    LINE_STRIP_WITH_ADJACENCY       :: 7;
    TRIANGLE_LIST_WITH_ADJACENCY    :: 8;
    TRIANGLE_STRIP_WITH_ADJACENCY   :: 9;
    PATCH_LIST                      :: 10;
}

RHIInputAssemblyState :: struct {
    primitive_topology: RHIPrimitiveTopology = .TRIANGLE_LIST;
    primitive_restart_enabled: u32 = RHI_FALSE;
}

RHITessellationState :: struct {
    patch_control_points: u32 = 0;
}

RHIViewport :: struct {
    x: float32;
    y: float32;
    width: float32;
    height: float32;
    min_depth: float32;
    max_depth: float32;
}

RHIRect :: struct {
    offset: Offset2D;
    extent: Extent2D;
}

RHIViewportState :: struct {
    MAX_VIEWPORTS :: 1;

    viewport_count: u32 = 1;
    viewports: [MAX_VIEWPORTS] RHIViewport = .[ .{0., 0., 1. , 1., 0., 1.}];
    scissors: [MAX_VIEWPORTS] RHIRect = .[ .{ .{0, 0}, .{0, 0}} ];
}

RHIPolygonMode :: enum {
    FILL  :: 0;
    LINE  :: 1;
    POINT :: 2;
}

RHICullModeFlags :: enum_flags {
    NONE            :: 0;
    FRONT_BIT       :: 1;
    BACK_BIT        :: 2;
    FRONT_AND_BACK  :: FRONT_BIT | BACK_BIT;
}

RHIFrontFace :: enum {
    COUNTER_CLOCKWISE :: 0;
    CLOCKWISE :: 1;
}

RHI_FALSE :: 0;
RHI_TRUE :: 1;

RHIRasterizationState :: struct {
    depth_clamp_enable: u32 = RHI_FALSE;
    rasterizer_discard_enable: u32 = RHI_FALSE;
    polygon_mode: RHIPolygonMode = .FILL;
    cull_mode: RHICullModeFlags = .NONE;
    front_face: RHIFrontFace = .COUNTER_CLOCKWISE;
    depth_bias_enable: u32 = RHI_FALSE;
    depth_bias_constant_factor: float32 = 1.;
    depth_bias_clamp: float32 = 0.;
    depth_bias_slope_factor: float32 = 1.;
    line_width: float32 = 1.;
}

RHIMultisampleState :: struct {
    rasterization_samples: RHISampleCount = ._1;
    sample_shading_enable: u32 = RHI_FALSE;
    min_sample_shading: float32 = 0.;
    sample_mask: u32 = 0xFFFFFFFF;
    alpha_to_coverage_enable: u32 = RHI_FALSE;
    alpha_to_one_enable: u32 = RHI_FALSE;
}

RHICompareOp :: enum {
    NEVER;
    LESS;
    EQUAL;
    LESS_OR_EQUAL;
    GREATER;
    NOT_EQUAL;
    GREATER_OR_EQUAL;
    ALWAYS;
}

RHIStencilOp :: enum {
    KEEP;
    ZERO;
    REPLACE;
    INCREMENT_AND_CLAMP;
    DECREMENT_AND_CLAMP;
    INVERT;
    INCREMENT_AND_WRAP;
    DECREMENT_AND_WRAP;
}

RHIStencilOpState :: struct {
    fail_op: RHIStencilOp;
    pass_op: RHIStencilOp;
    depth_fail_op: RHIStencilOp;
    compare_op: RHICompareOp;
    compare_mask: u32;
    write_mask: u32;
    reference: u32;
}

RHIDepthStencilState :: struct {
    depth_test_enable: u32 = RHI_FALSE;
    depth_write_enable: u32 = RHI_FALSE;
    depth_compare_op: RHICompareOp = .ALWAYS;
    depth_bounds_test_enable: u32 = RHI_FALSE;
    stencil_test_enable: u32 = RHI_FALSE;
    front: RHIStencilOpState;
    back: RHIStencilOpState;
    min_depth_bounds: float32 = 0.;
    max_depth_bounds: float32 = 1.;
}

RHILogicOp :: enum {
    CLEAR           :: 0;
    AND             :: 1;
    AND_REVERSE     :: 2;
    COPY            :: 3;
    AND_INVERTED    :: 4;
    NO_OP           :: 5;
    XOR             :: 6;
    OR              :: 7;
    NOR             :: 8;
    EQUIVALENT      :: 9;
    INVERT          :: 10;
    OR_REVERSE      :: 11;
    COPY_INVERTED   :: 12;
    OR_INVERTED     :: 13;
    NAND            :: 14;
    SET             :: 15;
}

RHIBlendFactor :: enum {
    ZERO :: 0;
    ONE :: 1;
    SRC_COLOR :: 2;
    ONE_MINUS_SRC_COLOR :: 3;
    DST_COLOR :: 4;
    ONE_MINUS_DST_COLOR :: 5;
    SRC_ALPHA :: 6;
    ONE_MINUS_SRC_ALPHA :: 7;
    DST_ALPHA :: 8;
    ONE_MINUS_DST_ALPHA :: 9;
    CONSTANT_COLOR :: 10;
    ONE_MINUS_CONSTANT_COLOR :: 11;
    CONSTANT_ALPHA :: 12;
    ONE_MINUS_CONSTANT_ALPHA :: 13;
    SRC_ALPHA_SATURATE :: 14;
    SRC1_COLOR :: 15;
    ONE_MINUS_SRC1_COLOR :: 16;
    SRC1_ALPHA :: 17;
    ONE_MINUS_SRC1_ALPHA :: 18;
}

RHIBlendOp :: enum {
    ADD :: 0;
    SUBTRACT :: 1;
    REVERSE_SUBTRACT :: 2;
    MIN :: 3;
    MAX :: 4;
}

RHIColorComponentFlags :: enum_flags {
    R_BIT :: 0x01;
    G_BIT :: 0x02;
    B_BIT :: 0x08;
    A_BIT :: 0x04;
    ALL_BITS :: R_BIT | G_BIT | B_BIT | A_BIT;
}

RHIPipelineColorBlendAttachmentState :: struct {
    blend_enable: bool = false;
    src_color_blend_factor: RHIBlendFactor = .ZERO;
    dst_color_blend_factor: RHIBlendFactor = .ZERO;
    color_blend_op: RHIBlendOp = .ADD;
    src_alpha_blend_factor: RHIBlendFactor = .ZERO;
    dst_alpha_blend_factor: RHIBlendFactor = .ZERO;
    alpha_blend_op: RHIBlendOp = .ADD;
    color_write_mask: RHIColorComponentFlags = .ALL_BITS;
}

RHIBlendState :: struct {
    logic_op_enable: u32 = RHI_FALSE;
    logic_op: RHILogicOp = .COPY;
    attachment_count: u32 = 0;
    attachments: [8] RHIPipelineColorBlendAttachmentState;
    blend_constants: [4] float;
}

RHIDynamicStateFlags :: enum_flags {
    VIEWPORT_BIT                :: 1 << 0;
    SCISSOR_BIT                 :: 1 << 1;
    LINE_WIDTH_BIT              :: 1 << 2;
    DEPTH_BIAS_BIT              :: 1 << 3;
    BLEND_CONSTANTS_BIT         :: 1 << 4;
    DEPTH_BOUNDS_BIT            :: 1 << 5;
    STENCIL_COMPARE_MASK_BIT    :: 1 << 6;
    STENCIL_WRITE_MASK_BIT      :: 1 << 7;
    STENCIL_REFERENCE_BIT       :: 1 << 8;
}

RHIAttachmentFormats :: struct {
    color_attachment_count: u32 = 0;
    color_attachment_formats: [8] RHIFormat;
    depth_stencil_format: RHIFormat;
}

RHIDescriptorSetLayoutDecl :: struct {
    layout: *RHIDescriptorSetLayout;
    used_bindings: [] RHIDescriptorSetLayoutBinding;
}

RHIFilter :: enum {
    NEAREST :: 0;
    LINEAR  :: 1;
}

RHISamplerMipmapMode :: enum {
    NEAREST :: 0;
    LINEAR  :: 1;
}

RHISamplerAddressMode :: enum {
    REPEAT                  :: 0;
    MIRRORED_REPEAT         :: 1;
    CLAMP_TO_EDGE           :: 2;
    CLAMP_TO_BORDER         :: 3;
    MIRROR_CLAMP_TO_EDGE    :: 4;
}

RHIBorderColor:: enum {
    FLOAT_TRANSPARENT_BLACK :: 0;
    INT_TRANSPARENT_BLACK   :: 1;
    FLOAT_OPAQUE_BLACK      :: 2;
    INT_OPAQUE_BLACK        :: 3;
    FLOAT_OPAQUE_WHITE      :: 4;
    INT_OPAQUE_WHITE        :: 5;
}

RHIStaticSamplerDesc :: struct {
    binding: u32;
    space: u32;
    stage_flags: RHIShaderStageFlags;
    mag_filter: RHIFilter;
    min_filter: RHIFilter;

    mipmap_mode: RHISamplerMipmapMode;
    address_mode_u: RHISamplerAddressMode;
    address_mode_v: RHISamplerAddressMode;
    address_mode_w: RHISamplerAddressMode;
    
    mip_lod_bias: float32;
    anisotropy_enable: bool;
    max_anisotropy: float32;
    compare_enable: bool;
    compare_op: RHICompareOp;
    min_lod: float32;
    max_lod: float32;
    border_color: RHIBorderColor;
    unnormalized_coordinates: bool;
}

RHIPipelineLayoutCreateInfo :: struct {
    descriptor_set_layout_count: u32;
    descriptor_set_layout_decls: [4] RHIDescriptorSetLayoutDecl;
    push_const_range: u32;
    push_const_stage_flags: RHIShaderStageFlags;
    static_sampler_set: u32;
    static_sampler_descs: [] RHIStaticSamplerDesc;
}

RHIAttachmentLoadOp :: enum {
    LOAD;
    CLEAR;
    DONT_CARE;
}

RHIAttachmentStoreOp :: enum {
    STORE;
    DONT_CARE;
}

RHIColorAttachmentDesc :: struct {
    image_view: *RHIImageView;
    load_op: RHIAttachmentLoadOp;
    store_op: RHIAttachmentStoreOp;
    clear_value: RHIClearColorValue;
}

RHIDepthStencilAttachmentDesc :: struct {
    image_view: *RHIImageView;
    load_op: RHIAttachmentLoadOp;
    store_op: RHIAttachmentStoreOp;
    stencil_load_op: RHIAttachmentLoadOp;
    stencil_store_op: RHIAttachmentStoreOp;
    clear_value: RHIClearDepthStencilValue;
    read_only: bool;
}

rhi_is_stencil_format :: inline (format: RHIFormat) -> bool {
    if format == {
        case .S8_UINT;           #through;
        case .D16_UNORM_S8_UINT; #through;
        case .D24_UNORM_S8_UINT; #through;
        case .D32_SFLOAT_S8_UINT;
            return true;
        case;
            return false;
    }
}

rhi_is_depth_format :: inline (format: RHIFormat) -> bool {
    if format == {
        case .D16_UNORM;            #through;
        case .D32_SFLOAT;           #through;
        case .D16_UNORM_S8_UINT;    #through;
        case .D24_UNORM_S8_UINT;    #through;
        case .D32_SFLOAT_S8_UINT;    #through;
        case .X8_D24_UNORM_PACK32;
            return true;
        case;
            return false;
    }
}

rhi_usage_flags :: (state: RHIResourceState, is_image: bool) -> u32 {
    flags: u32 = 0;

    if ((state & .READ_RESOURCE) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.TEXTURE_BIT else cast (u32)(RHIBufferUsageFlags.TYPED_BUFFER_BIT | RHIBufferUsageFlags.BYTE_BUFFER_BIT | RHIBufferUsageFlags.STRUCTURED_BUFFER_BIT);
	}

	if ((state & .READ_DEPTH_STENCIL) != 0) {
		assert(is_image);
		flags |= cast (u32) RHIImageUsageFlags.DEPTH_STENCIL_ATTACHMENT_BIT;
	}

	if ((state & .READ_CONSTANT_BUFFER) != 0) {
		assert(!is_image);
		flags |= cast (u32) RHIBufferUsageFlags.CONSTANT_BUFFER_BIT;
	}

	if ((state & .READ_VERTEX_BUFFER) != 0) {
		assert(!is_image);
		flags |= cast (u32) RHIBufferUsageFlags.VERTEX_BUFFER_BIT;
	}

	if ((state & .READ_INDEX_BUFFER) != 0) {
		assert(!is_image);
		flags |= cast (u32) RHIBufferUsageFlags.INDEX_BUFFER_BIT;
	}

	if ((state & .READ_INDIRECT_BUFFER) != 0) {
		assert(!is_image);
		flags |= cast (u32) RHIBufferUsageFlags.INDIRECT_BUFFER_BIT;
	}

	if ((state & .READ_TRANSFER) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.TRANSFER_SRC_BIT else cast (u32) RHIBufferUsageFlags.TRANSFER_SRC_BIT;
	}

	if ((state & .WRITE_DEPTH_STENCIL) != 0) {
		assert(is_image);
		flags |= cast (u32) RHIImageUsageFlags.DEPTH_STENCIL_ATTACHMENT_BIT;
	}

	if ((state & .WRITE_COLOR_ATTACHMENT) != 0) {
		assert(is_image);
		flags |= cast (u32) RHIImageUsageFlags.COLOR_ATTACHMENT_BIT;
	}

	if ((state & .WRITE_TRANSFER) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.TRANSFER_DST_BIT else cast (u32) RHIBufferUsageFlags.TRANSFER_DST_BIT;
	}

	if ((state & .CLEAR_RESOURCE) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.CLEAR_BIT else cast (u32) RHIBufferUsageFlags.CLEAR_BIT;
	}

	if ((state & .RW_RESOURCE) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.RW_TEXTURE_BIT else cast (u32)(RHIBufferUsageFlags.RW_TYPED_BUFFER_BIT | RHIBufferUsageFlags.RW_BYTE_BUFFER_BIT | RHIBufferUsageFlags.RW_STRUCTURED_BUFFER_BIT);
	}

	if ((state & .RW_RESOURCE_READ_ONLY) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.RW_TEXTURE_BIT else cast (u32)(RHIBufferUsageFlags.RW_TYPED_BUFFER_BIT | RHIBufferUsageFlags.RW_BYTE_BUFFER_BIT | RHIBufferUsageFlags.RW_STRUCTURED_BUFFER_BIT);
	}

	if ((state & .RW_RESOURCE_WRITE_ONLY) != 0) {
		flags |= ifx is_image then cast (u32) RHIImageUsageFlags.RW_TEXTURE_BIT else cast (u32)(RHIBufferUsageFlags.RW_TYPED_BUFFER_BIT | RHIBufferUsageFlags.RW_BYTE_BUFFER_BIT | RHIBufferUsageFlags.RW_STRUCTURED_BUFFER_BIT);
	}

	if ((state & .PRESENT) != 0) {
		assert(is_image);
		flags |= 0;
	}

    return flags;
}

#load "pipeline_builder.jai";
#load "rhi_defaults.jai";
#load "rhi_debug.jai";
#load "linear_gpu_allocator.jai";

RHI_BACKEND :: RHIBackend.VULKAN;
#if RHI_BACKEND == .VULKAN {
    #load "vk/vk_rhi.jai";
} else {
    assert(false); // unrecognized RHI
}
