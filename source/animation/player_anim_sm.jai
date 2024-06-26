Player_Anim_State :: enum u8 {
    IDLE;
    WALK;
    ATTACK_WIND_UP;
    ATTACK;
}

Player_Anim_State_Component :: struct @Component {
    state: Player_Anim_State;

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
        .{
            frames = .[10],
            frame_duration = 0.09,
            name = "attack_wind_up",
            flags = .NONE,
            directional_mode = .UNIQUE_SPRITES,
        },
        .{
            frames = .[11, 12, 13, 14],
            frame_duration = 0.09,
            name = "attack",
            flags = .NONE,
            directional_mode = .UNIQUE_SPRITES,
        },
    ];
}

EVENT_PLAYER_ATTACK: Event_ID = -1;
EVENT_ON_PLAYER_ANIM_STATE_CHANGED: Event_ID = -1;

/** A system that iterates over all anim_state_components and changes their value in accordance to transition rules defined here */
update_player_anim_state :: (q: Query) {
    velocities := query_get(q, Velocity);
    anim_states := query_get(q, Player_Anim_State_Component);
    anims := query_get(q, Animation);
    player_commands := query_get(q, Player_Commands);

    for 0..q.count-1 {
        current_state := anim_states[it].state;

        if player_commands[it].main_attack && current_state != .ATTACK {
            anim_states[it].state = xx Player_Anim_State.ATTACK_WIND_UP;
            transition_to_state(q.world, *anims[it], anim_states[it]);
        }
        if current_state == {
            case .IDLE;
                if !equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = xx Player_Anim_State.WALK;
                    transition_to_state(q.world, *anims[it], anim_states[it]);
                }
            case .WALK;
                if equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = xx Player_Anim_State.IDLE;
                    transition_to_state(q.world, *anims[it], anim_states[it]);
                }
            case .ATTACK_WIND_UP;
                if anims[it].finished then {
                    anim_states[it].state = xx Player_Anim_State.ATTACK;
                    transition_to_state(q.world, *anims[it], anim_states[it]);
                }
            case .ATTACK;
                if anims[it].finished then {
                    if equals(length_squared(velocities[it]), 0) {
                        anim_states[it].state = Player_Anim_State.IDLE;
                        transition_to_state(q.world, *anims[it], anim_states[it]);
                    } else {
                        anim_states[it].state = Player_Anim_State.WALK;
                        transition_to_state(q.world, *anims[it], anim_states[it]);
                    }
                }
        }
    }
} @System(OnUpdate) @Write(Player_Anim_State_Component,Animation) @Read(Player,Player_Commands,Velocity)

on_player_anim_state_changed :: (world: *World) {
    for q : make_iter(world, Velocity, Player_Anim_State_Component, Animation) {
        velocities := query_get(q, Velocity);
        anim_states := query_get(q, Player_Anim_State_Component);
        anims := query_get(q, Animation);

        for 0..q.count-1 {
            current_state := cast(Player_Anim_State) anim_states[it].state;
            if current_state == .ATTACK {
                broadcast_event(q.world, EVENT_PLAYER_ATTACK);
            }
        }
    }
} @Event @Write(Player_Anim_State_Component,Animation) @Read(Player,Velocity)

#scope_file

transition_to_state :: (world: *World, animation: *Animation, anim_state: Player_Anim_State_Component){
    << animation = .{ anim_state.defs[anim_state.state], 0, anim_state.defs[anim_state.state].frame_duration, false };
    broadcast_event(world, EVENT_ON_PLAYER_ANIM_STATE_CHANGED);
}
