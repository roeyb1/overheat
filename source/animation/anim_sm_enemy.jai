Enemy_Anim_State :: enum u8 {
    IDLE;
    WALK;
}

ENEMY_IDLE_DEFINITION :: Animation_Definition .{
    frames = .[0, 1, 2, 3],
    frame_duration = 0.3,
    name = "idle",
    flags = .LOOP,
};

ENEMY_WALK_DEFINITION :: Animation_Definition .{
    frames = .[4, 5, 6, 7, 8, 9],
    frame_duration = 0.15,
    name = "walk",
    flags = .LOOP,
};

update_enemy_anim_state :: (q: Query) {
    velocities := query_get(q, Velocity);
    anim_states := query_get(q, Anim_State_Component);
    anims := query_get(q, Animation);

    for 0..q.count-1 {
        current_state := cast(Enemy_Anim_State) anim_states[it].state;

        if current_state == {
            case .IDLE;
                if !equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = xx Enemy_Anim_State.WALK;
                    transition_to_state(q.world, *anims[it], ENEMY_WALK_DEFINITION);
                }
            case .WALK;
                if equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = xx Enemy_Anim_State.IDLE;
                    transition_to_state(q.world, *anims[it], ENEMY_IDLE_DEFINITION);
                }
        }
    }
} @System(OnUpdate) @Write(Anim_State_Component,Animation) @Read(Enemy,Velocity)


track_player :: (q: Query) {
    velocities := query_get(q, Velocity);
    move_speeds := query_get(q, Move_Speed);
    positions := query_get(q, Position);

    for 0..q.count-1 {
        velocities[it].value = unit_vector(get_component(q.world, g_local_player, Position) - positions[it]) * move_speeds[it].speed;
    }
} @System(PreUpdate) @Write(Velocity) @Read(Enemy,Move_Speed,Position)

#scope_file

transition_to_state :: (world: *World, animation: *Animation, template: Animation_Definition){
    << animation = .{ template, 0, template.frame_duration, false };
}