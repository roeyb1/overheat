#scope_export

RHIImage :: struct {
    handle: VkImage;
    desc: ImageDescription;
}

rhi_create_image :: (vk: VkImage, desc: ImageDescription) -> RHIImage {
    return .{handle = vk, desc = desc};
}

RHISemaphore :: VkSemaphore;

create_semaphore :: (initial: u64) -> RHISemaphore {
    type_create_info := VkSemaphoreTypeCreateInfo.{
        initialValue = initial,
        semaphoreType = .TIMELINE,
    };

    create_info := VkSemaphoreCreateInfo.{
        pNext = *type_create_info,
    };

    result: VkSemaphore;
    vk_check_result(vkCreateSemaphore(device, *create_info, null, *result));
    return result;
}

destroy_semaphore :: (semaphore: RHISemaphore) {
    vkDestroySemaphore(device, semaphore, null);
}