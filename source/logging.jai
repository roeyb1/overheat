#scope_export

log_initialize :: () {
    context.logger = logger;
}

log_warning :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0, section : *Log_Section = null) {
    new_flags := flags | .WARNING;
    log(format_string, ..args, loc, new_flags, user_flags, section);
} @PrintLike

log_verbose :: (format_string: string, args: .. Any, loc := #caller_location, flags := Log_Flags.NONE, user_flags : u32 = 0, section : *Log_Section = null) {
    new_flags := flags | .VERBOSE_ONLY;
    log(format_string, ..args, loc, new_flags, user_flags, section);
} @PrintLike

logger :: (message: string, data: *void, info: Log_Info) {
    if info.common_flags & .VERBOSE_ONLY && context.log_level < .VERBOSE {
        return;
    }
    if info.common_flags & .VERY_VERBOSE_ONLY && context.log_level < .VERY_VERBOSE {
        return;
    }

    now := current_time_consensus();
    
    calendar_local := to_calendar(now, .LOCAL);

    timestamp := tprint("[%/%/% - %:%:%] ", 
        calendar_local.year,
        calendar_local.month_starting_at_0 + 1,
        calendar_local.day_of_month_starting_at_0 + 1,
        calendar_local.hour,
        calendar_local.minute,
        calendar_local.second);
    write_string(timestamp);

    framecount := tprint("[%] ", g_frame_number % 1000);
    write_string(framecount);

    file_prefix := tprint("[%]: ", path_filename(info.location.fully_pathed_filename));
    write_string(file_prefix);

    level_prefix := ifx info.common_flags == 0 {
        "INFO: ";
    } else {
        tprint("%: ", info.common_flags);
    }

    write_string(level_prefix);

    write_string(message);

    if message[message.count-1] != #char "\n" then write_string("\n");
}