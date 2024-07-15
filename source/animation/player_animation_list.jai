//we should have a better way of accessing this info
Anim_List_Indecies :: enum {
    WIND_UP;
    ATTACK;
    BOW_WIND_UP;
    BOW_ATTACK;
}

Anim_List_Index :: struct @Component { 
    value : Anim_List_Indecies; @Sync
}

ANIMATION_LIST :: Animation_Definition.[Windup,Attack,Bow_Windup,Bow_Attack];

Windup :: Animation_Definition .{
    frames = .[10],
    frame_duration = 0.09,
    name = "attack_wind_up",
    flags = .NONE,
    directional_mode = .UNIQUE_SPRITES,
};

Attack :: Animation_Definition .{
    frames = .[11, 12, 13, 14],
    frame_duration = 0.09,
    name = "attack",
    flags = .NONE,
    directional_mode = .UNIQUE_SPRITES,
};

Bow_Windup :: Animation_Definition .{
    frames = .[15,16,17,18],
    frame_duration = 0.09,
    name = "bow_wind_up",
    flags = .NONE,
    directional_mode = .UNIQUE_SPRITES,
};

Bow_Attack :: Animation_Definition .{
    frames = .[13,14,14,14],
    frame_duration = 0.09,
    name = "bow_attack",
    flags = .NONE,
    directional_mode = .UNIQUE_SPRITES,
};