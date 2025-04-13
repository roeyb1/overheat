#scope_export

logger_data: Logger_Data;

log_initialize :: (log_file_name: string) {
    if log_file_name {
        log_directory :: "saved/logs";
        make_directory_if_it_does_not_exist(log_directory, recursive=true);

        // Move the older log file, if it exists
        file_path := tprint("%/%.txt", log_directory, log_file_name);
        file_move(file_path, tprint("%-old.txt", path_strip_extension(file_path)));

        logger_data.file = file_open(file_path, for_writing=true, keep_existing_content=false, log_errors=true);
        assert(is_valid(logger_data.file));
    }

    init_context_logger(*context);
}

/** Initialize the passed in context with the logger data. Callable from c calls so it can initialize the context before pushing any. */
init_context_logger :: (ctx: *#Context) #c_call {
    ctx.logger = logger;
    ctx.logger_data = *logger_data;
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

    log_sb: String_Builder;
    log_sb.allocator = temp;

    now := current_time_consensus();
    
    calendar_local := to_calendar(now, .LOCAL);

    sbprint(*log_sb, "[%/%/% - %:%:%] ", 
        calendar_local.year,
        calendar_local.month_starting_at_0 + 1,
        calendar_local.day_of_month_starting_at_0 + 1,
        calendar_local.hour,
        calendar_local.minute,
        calendar_local.second);

    sbprint(*log_sb, "[%] ", g_current_tick % 1000);

    sbprint(*log_sb, "[%]: ", path_filename(info.location.fully_pathed_filename));

    if info.common_flags == 0 {
        sbprint(*log_sb, "INFO: ");
    } else {
        sbprint(*log_sb, "%: ", info.common_flags);
    }

    sbprint(*log_sb, message);

    // if the message came from a source which doesn't add newline, insert one now:
    if message[message.count-1] != #char "\n" then sbprint(*log_sb, "\n");

    write_builder(*log_sb, do_reset=false);

    // log to file, if there is a log file bound:
    logger_data := cast(*Logger_Data)data;
    if is_valid(logger_data.file) {
        file_write(*logger_data.file, *log_sb, do_reset=false);
    }
}

#scope_file

Logger_Data :: struct {
    file: File;
}