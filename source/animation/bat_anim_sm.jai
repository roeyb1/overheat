
Bat_Animation :: struct @Component {
    State :: enum u8 {
        UNINITIALIZED;
        IDLE;
        WALK;
        ATTACK_WIND_UP;
        ATTACK;
    }

    state: State = .UNINITIALIZED;

    defs :: Animation_Definition.[
        .{
        },
        .{
            frames = .[0, 1, 2, 3, 4, 5, 6, 7],
            frame_duration = 0.1,
            name = "idle",
            flags = .LOOP,
            directional_mode = .FLIP_X,
        },
        .{
            frames = .[30, 31, 32, 33, 34, 35, 36],
            frame_duration = 0.08,
            name = "walk",
            flags = .LOOP,
            directional_mode = .FLIP_X,
        },
    ];
}

update_bat_anim_state :: (q: Query) {
    velocities := query_get(q, Velocity);
    anim_states := query_get(q, Bat_Animation);
    anims := query_get(q, Sprite_Animator);

    for 0..q.count-1 {
        current_state := anim_states[it].state;

        if current_state == {
            case .UNINITIALIZED;
                    anim_states[it].state = .IDLE;
                    transition_to_state(q.world, *anims[it], anim_states[it]);
                    anims[it].time_till_switch *= random_get_zero_to_one();
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
            case;
                assert(false, "NYI");
        }
    }
} @System(OnUpdate) @Write(Bat_Animation,Sprite_Animator) @Read(Enemy,Velocity)

#scope_file

transition_to_state :: (world: *World, animator: *Sprite_Animator, anim_state: Bat_Animation){
    << animator = .{ anim_state.defs[anim_state.state], 0, anim_state.defs[anim_state.state].frame_duration, false };
}