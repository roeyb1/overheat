scoped_timer :: (out_val: *float64) #expand {
    start := seconds_since_init();
    `defer (<<out_val) = seconds_since_init() - start;
}

scoped_smooth_timer :: (out_val: *float64, weighting: float64) #expand {
    start := seconds_since_init();

    `defer {
        end := seconds_since_init();
        << out_val = weighting * (end - start) + (1. - weighting) * (<<out_val);
    }
}

scoped_timer_log :: (loc := #caller_location) #expand {
    start := seconds_since_init();
    `defer {
        duration := seconds_since_init() - start;
        log("Scoped timer at %:%:% took % seconds.", path_filename(loc.fully_pathed_filename), loc.line_number, loc.character_number, duration);
    }
}