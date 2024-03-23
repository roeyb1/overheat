#scope_export

RHI_SCOPED_GPU_LABEL :: (cmd_list: *RHICmdList, name: string) #expand {
    rhi_cmd_debug_label_begin(cmd_list, name);
    `defer rhi_cmd_debug_label_end(cmd_list);
}