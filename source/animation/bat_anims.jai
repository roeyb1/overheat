Bat_Anim_State :: enum u8 {
    IDLE;
    WALK;
    ATTACK_WIND_UP;
    ATTACK;
}

Bat_Anim_State_Component :: struct @Component {
    state: Bat_Anim_State;
}

BAT_IDLE_DEFINITION :: Animation_Definition .{
    frames = .[0, 1, 2, 3, 4, 5, 6, 7],
    frame_duration = 0.3,
    name = "idle",
    flags = .LOOP,
    directional_mode = .FLIP_X,
};

BAT_WALK_DEFINITION :: Animation_Definition .{
    frames = .[30, 31, 32, 33, 34, 35, 36],
    frame_duration = 0.08,
    name = "walk",
    flags = .LOOP,
    directional_mode = .FLIP_X,
};

update_enemy_anim_state :: (q: Query) {
    velocities := query_get(q, Velocity);
    anim_states := query_get(q, Bat_Anim_State_Component);
    anims := query_get(q, Animation);

    for 0..q.count-1 {
        current_state := anim_states[it].state;

        if current_state == {
            case .IDLE;
                if !equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = xx Bat_Anim_State.WALK;
                    transition_to_state(q.world, *anims[it], BAT_WALK_DEFINITION);
                }
            case .WALK;
                if equals(length_squared(velocities[it]), 0) {
                    anim_states[it].state = xx Bat_Anim_State.IDLE;
                    transition_to_state(q.world, *anims[it], BAT_IDLE_DEFINITION);
                }
        }
    }
} @System(OnUpdate) @Write(Bat_Anim_State_Component,Animation) @Read(Enemy,Velocity)

#scope_file

transition_to_state :: (world: *World, animation: *Animation, template: Animation_Definition){
    << animation = .{ template, 0, template.frame_duration, false };
}