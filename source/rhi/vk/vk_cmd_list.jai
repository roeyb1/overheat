#scope_export

RHICmdPool :: struct {
    handle: VkCommandPool;
}

RHICmdList :: struct {
    handle: VkCommandBuffer;
}

rhi_cmd_pool_create :: (queue: RHIQueue) -> RHICmdPool {
    create_info := VkCommandPoolCreateInfo.{
        flags = .TRANSIENT_BIT,
        queueFamilyIndex = queue.queue_family_index,
    };

    result: VkCommandPool;
    vk_check_result(vkCreateCommandPool(device, *create_info, null, *result));
    return .{handle = result};
}

rhi_cmd_pool_destroy :: (cmd_pool: RHICmdPool) {
    vkDestroyCommandPool(device, cmd_pool.handle, null);
}

rhi_cmd_pool_reset :: (cmd_pool: RHICmdPool) {
    vkResetCommandPool(device, cmd_pool.handle, 0);
}

rhi_cmd_list_allocate :: (cmd_pool: RHICmdPool) -> RHICmdList {
    result: VkCommandBuffer;

    alloc_info := VkCommandBufferAllocateInfo.{
        commandPool = cmd_pool.handle,
        commandBufferCount = 1,
        level = .PRIMARY,
    };

    vkAllocateCommandBuffers(device, *alloc_info, *result);

    return .{handle = result};
}

rhi_cmd_list_free :: (cmd_pool: RHICmdPool, cmd_list: RHICmdList) {
    vkFreeCommandBuffers(device, cmd_pool.handle, 1, *cmd_list.handle);
}

rhi_cmd_list_begin :: (cmd_list: *RHICmdList) {
    begin_info := VkCommandBufferBeginInfo.{
        flags = .ONE_TIME_SUBMIT_BIT,
    };

    vkBeginCommandBuffer(cmd_list.handle, *begin_info);
}

rhi_cmd_list_end :: (cmd_list: *RHICmdList) {
    vkEndCommandBuffer(cmd_list.handle);
}

rhi_submit_single_time_commands :: (queue: *RHIQueue, cmd_list: *RHICmdList) {
    cmd_lists := *RHICmdList.[cmd_list];
    submit_info := RHISubmitInfo.{
        command_lists = cmd_lists,
    };
    rhi_queue_submit(queue, .[*submit_info]);
    rhi_queue_wait_idle(queue);
}


#load "vk_cmds.jai";