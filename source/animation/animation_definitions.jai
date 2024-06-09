Animation_Definition :: struct {
    frames: [] u32;

    frame_duration: float;
    name: string;

    should_loop: bool = true;
}

// Temporarily define some of our animations here until we make this data driven.

CHARACTER_WALK_DEFINITION :: Animation_Definition .{
    frames = .[1,2,1,0],
    frame_duration = 0.15,
    name = "walk"
};

CHARACTER_IDLE_DEFINITION :: Animation_Definition .{
    frames = .[1],
    frame_duration = 0.3,
    name = "idle"
};

CHARACTER_ATTACK_WIND_UP_DEFINITION :: Animation_Definition .{
    frames = .[10],
    frame_duration = 0.09,
    name = "attack_wind_up",
    should_loop = false,
};

CHARACTER_ATTACK_DEFINITION :: Animation_Definition .{
    frames = .[11, 12, 13, 14],
    frame_duration = 0.09,
    name = "attack",
    should_loop = false,
};