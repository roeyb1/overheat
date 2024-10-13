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
    anim_list_index: Anim_List_Indecies; @Sync
    active: bool; @Sync 
    runtime: float; @Sync 
}

modify_interuptor_anim_slot_from_focus :: (world: *World, parent: Entity, focus: Entity) {
    assert(ecs_get(world, focus , Focusing) != null);
    assert(ecs_get(world, parent, Interuptor_Anim_Slot) != null);
    
    anim_index := ecs_get(world, focus, Anim_List_Index).value;
    runtime := ecs_get(world, focus, Duration).value;
    interuptor_anim_slot := ecs_get(world,parent,Interuptor_Anim_Slot);

    interuptor_anim_slot.anim_list_index = anim_index;
    interuptor_anim_slot.runtime = runtime;
    interuptor_anim_slot.active = true;
}

interuptor_runtime_update :: (q: Query) {
    Anim_Slots := query_get(q, Interuptor_Anim_Slot);
    for 0..q.count-1 {
        if Anim_Slots[it].runtime >= 0 {
            Anim_Slots[it].runtime -= FIXED_TIMESTEP;
        }
    }
} @System(OnUpdate) @Write(Interuptor_Anim_Slot) @Read()

//this will run in pre update to stop the client from looping the first frame of the animation
reset_interuptor_after_anim :: (q: Query) {
    #if SERVER {
        Anim_Slots := query_get(q, Interuptor_Anim_Slot);
        for 0..q.count-1 {
            if Anim_Slots[it].active {
            Anim_Slots[it].active = false;
            }
        }
    }
} @System(PreUpdate) @Write(Interuptor_Anim_Slot) @Read()

#load "player_animation_list.jai";