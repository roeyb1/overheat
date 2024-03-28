#scope_export

RHISemaphore :: struct {
    handle: VkSemaphore;
}

rhi_semaphore_create :: (initial: u64, debug_name: string) -> RHISemaphore {
    type_create_info := VkSemaphoreTypeCreateInfo.{
        initialValue = initial,
        semaphoreType = .TIMELINE,
    };

    create_info := VkSemaphoreCreateInfo.{
        pNext = *type_create_info,
    };

    result: VkSemaphore;
    vk_check_result(vkCreateSemaphore(device, *create_info, null, *result));

    return .{handle = result};
}

rhi_semaphore_destroy :: (semaphore: RHISemaphore) {
    vkDestroySemaphore(device, semaphore.handle, null);
}

rhi_semaphore_wait :: (semaphore: RHISemaphore, wait_value: u64) {
    wait_info := VkSemaphoreWaitInfo.{
        flags = .ANY_BIT,
        semaphoreCount = 1,
        pSemaphores = *semaphore.handle,
        pValues = *wait_value,
    };

    vk_check_result(vkWaitSemaphores(device, *wait_info, U64_MAX));
}

rhi_semaphore_signal :: (semaphore: RHISemaphore, signal_value: u64) {
    signal_info := VkSemaphoreSignalInfo.{
        semaphore = semaphore.handle,
        value = signal_value,
    };

    vk_check_result(vkSignalSemaphore(device, *signal_info));
}