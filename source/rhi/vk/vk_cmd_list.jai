#scope_export

RHICmdPool :: VkCommandPool;
RHICmdList :: VkCommandBuffer;

create_cmd_pool :: (queue: RHIQueue) -> RHICmdPool {
    create_info := VkCommandPoolCreateInfo.{
        flags = .TRANSIENT_BIT,
        queueFamilyIndex = queue.queue_family_index,
    };

    result: VkCommandPool;
    vk_check_result(vkCreateCommandPool(device, *create_info, null, *result));
    return result;
}

destroy_cmd_pool :: (cmd_pool: RHICmdPool) {
    vkDestroyCommandPool(device, cmd_pool, null);
}

reset_cmd_pool :: (cmd_pool: RHICmdPool) {
    vkResetCommandPool(device, cmd_pool, 0);
}

allocate_cmd_list :: (cmd_pool: RHICmdPool) -> RHICmdList {
    result: VkCommandBuffer;

    alloc_info := VkCommandBufferAllocateInfo.{
        commandPool = cmd_pool,
        commandBufferCount = 1,
        level = .PRIMARY,
    };

    vkAllocateCommandBuffers(device, *alloc_info, *result);

    return result;
}

free_cmd_list :: (cmd_pool: RHICmdPool, cmd_list: RHICmdList) {
    vkFreeCommandBuffers(device, cmd_pool, 1, *cmd_list);
}