Anim_Flags :: enum_flags u32 {
    NONE                        :: 0;
    LOOP                        :: 1 << 0;
    DIRECTIONAL_INDEXING        :: 1 << 1;
}

Anim_Direction_Mode :: enum {
    /** Animation is not directional. */
    IGNORE;
    /** Animation has individual rows for each cardinal direction */
    UNIQUE_SPRITES;
    /** Animation only flips X for left/right facing */
    FLIP_X;
}

Animation_Definition :: struct {
    frames: [] u32;

    frame_duration: float;
    name: string;

    flags: Anim_Flags;

    directional_mode: Anim_Direction_Mode;
}

// Temporarily define some of our animations here until we make this data driven.

CHARACTER_WALK_DEFINITION :: Animation_Definition .{
    frames = .[1,2,1,0],
    frame_duration = 0.15,
    name = "walk",
    flags = .LOOP,
    directional_mode = .UNIQUE_SPRITES,
};

CHARACTER_IDLE_DEFINITION :: Animation_Definition .{
    frames = .[1],
    frame_duration = 0.3,
    name = "idle",
    flags = .LOOP,
    directional_mode = .UNIQUE_SPRITES,
};

CHARACTER_ATTACK_WIND_UP_DEFINITION :: Animation_Definition .{
    frames = .[10],
    frame_duration = 0.09,
    name = "attack_wind_up",
    flags = .NONE,
    directional_mode = .UNIQUE_SPRITES,
};

CHARACTER_ATTACK_DEFINITION :: Animation_Definition .{
    frames = .[11, 12, 13, 14],
    frame_duration = 0.09,
    name = "attack",
    flags = .NONE,
    directional_mode = .UNIQUE_SPRITES,
};