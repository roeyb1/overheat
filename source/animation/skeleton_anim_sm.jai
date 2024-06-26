Skeleton_Animation :: struct @Component {
    State :: enum u8 {
        IDLE;
        WALK;
    }

    state: State;

    defs :: Animation_Definition.[
        .{
            frames = .[0, 1, 2, 3],
            frame_duration = 0.3,
            name = "idle",
            flags = .LOOP,
            directional_mode = .UNIQUE_SPRITES,
        },
        .{
            frames = .[4, 5, 6, 7, 8, 9],
            frame_duration = 0.15,
            name = "walk",
            flags = .LOOP,
            directional_mode = .UNIQUE_SPRITES,
        },
    ];
}

update_skeleton_anim_state :: (q: Query) {
    velocities := query_get(q, Velocity);
    anim_states := query_get(q, Skeleton_Animation);
    anims := query_get(q, Sprite_Animator);

    for 0..q.count-1 {
        current_state := anim_states[it].state;

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
        }
    }
} @System(OnUpdate) @Write(Skeleton_Animation,Sprite_Animator) @Read(Enemy,Velocity)


#scope_file

transition_to_state :: (world: *World, animator: *Sprite_Animator, anim_state: Skeleton_Animation){
    << animator = .{ anim_state.defs[anim_state.state], 0, anim_state.defs[anim_state.state].frame_duration, false };
}