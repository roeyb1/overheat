Player_Animation :: struct @Component {
    State :: enum u8 {
        IDLE;
        WALK;
        INTERUPTOR;
    }

    state: State;

    defs :: Animation_Definition.[
        .{
            frames = .[1],
            frame_duration = 0.3,
            name = "idle",
            flags = .LOOP,
            directional_mode = .UNIQUE_SPRITES,
        },
        .{
            frames = .[1,2,1,0],
            frame_duration = 0.15,
            name = "walk",
            flags = .LOOP,
            directional_mode = .UNIQUE_SPRITES,
        },
    ];
}

/** A system that iterates over all anim_state_components and changes their value in accordance to transition rules defined here */
update_player_anim_state :: (q: Query) {
    velocities := query_get(q, Velocity);
    anim_states := query_get(q, Player_Animation);
    anims := query_get(q, Sprite_Animator);
    player_commands := query_get(q, Player_Commands);

    for 0..q.count-1 {
        current_state := anim_states[it].state;

        anim_info := get_component(q.world, q.entities[it], Interuptor_Anim_Slot);
        if anim_info.active {
            anim_info.active = false;

            anim_states[it].state = .INTERUPTOR;
            play_animation(q.world, *anims[it], ANIMATION_LIST[anim_info.anim_list_index]);
        }
        
        if current_state == {
            case .IDLE;
                if !equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = .WALK;
                    transition_to_state(q.world, *anims[it], anim_states[it]);
                }
            case .WALK;
                if equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = .IDLE;
                    transition_to_state(q.world, *anims[it], anim_states[it]);
                }
            case .INTERUPTOR;
                if anim_info.runtime <= 0 then {
                    if equals(length_squared(velocities[it]), 0) {
                        anim_states[it].state = .IDLE;
                        transition_to_state(q.world, *anims[it], anim_states[it]);
                    } else {
                        anim_states[it].state = .WALK;
                        transition_to_state(q.world, *anims[it], anim_states[it]);
                    }
                }
        }
        
    }
} @System(PreRender) @Write(Player_Animation,Sprite_Animator) @Read(Player,Player_Commands,Velocity)

#scope_file

transition_to_state :: (world: *World, animator: *Sprite_Animator, anim_state: Player_Animation){
    << animator = .{ anim_state.defs[anim_state.state], 0, anim_state.defs[anim_state.state].frame_duration, false };
}

play_animation :: (world: *World, animator: *Sprite_Animator, anim_definition: Animation_Definition){
    << animator = .{ anim_definition, 0, anim_definition.frame_duration, false };
}
