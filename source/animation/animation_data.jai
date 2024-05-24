Animation :: struct {
    animation_template: Animation_Template;
    current_frame: u32;
    time_till_switch: float;
}

Animation_Template :: struct {
    animation_frames: [] u32;
    frame_duration: float;
    name: string;
}

WALK :: Animation_Template .{
    animation_frames = .[1,2,1,0],
    frame_duration = 0.15,
    name = "walk"
};

IDLE :: Animation_Template .{
    animation_frames = .[1],
    frame_duration = 0.3,
    name = "idle"
};