Anim_Flags :: enum_flags u32 {
    NONE                        :: 0;
    LOOP                        :: 1 << 0;
    /** Indicates if the animation has individual rows for each cardinal direction */
    DIRECTIONAL_INDEXING   :: 1 << 1;
}

Animation_Definition :: struct {
    frames: [] u32;

    frame_duration: float;
    name: string;

    flags: Anim_Flags;

    flip: Flip_Flags;
}

// Temporarily define some of our animations here until we make this data driven.

CHARACTER_WALK_DEFINITION :: Animation_Definition .{
    frames = .[1,2,1,0],
    frame_duration = 0.15,
    name = "walk",
    flags = .LOOP | .DIRECTIONAL_INDEXING,
};

CHARACTER_IDLE_DEFINITION :: Animation_Definition .{
    frames = .[1],
    frame_duration = 0.3,
    name = "idle",
    flags = .LOOP | .DIRECTIONAL_INDEXING,
};

CHARACTER_ATTACK_WIND_UP_DEFINITION :: Animation_Definition .{
    frames = .[10],
    frame_duration = 0.09,
    name = "attack_wind_up",
    flags = .DIRECTIONAL_INDEXING,
};

CHARACTER_ATTACK_DEFINITION :: Animation_Definition .{
    frames = .[11, 12, 13, 14],
    frame_duration = 0.09,
    name = "attack",
    flags = .DIRECTIONAL_INDEXING,
};