Animation :: struct {
    animation_definition: Animation_Definition;
    current_frame: u32;
    time_till_switch: float;
}

Animation_Definition :: struct {
    animation_frames: [] u32;
    frame_duration: float;
    name: string;
}

CHARACTER_WALK_TEMPLATE :: Animation_Definition .{
    animation_frames = .[1,2,1,0],
    frame_duration = 0.15,
    name = "walk"
};

CHARACTER_IDLE_TEMPLATE :: Animation_Definition .{
    animation_frames = .[1],
    frame_duration = 0.3,
    name = "idle"
};