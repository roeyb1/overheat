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

Interuptor_Anim_Slot :: struct @Component {
    anim_list_index: Anim_List_Index; @Sync
    active: bool; @Sync
}


#load "player_animation_list.jai";