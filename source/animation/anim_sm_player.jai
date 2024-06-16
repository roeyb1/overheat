Player_Anim_State :: enum u8 {
    IDLE;
    WALK;
    ATTACK_WIND_UP;
    ATTACK;
}

EVENT_PLAYER_ATTACK: Event_ID = -1;
EVENT_ON_PLAYER_ANIM_STATE_CHANGED: Event_ID = -1;

/** A system that iterates over all anim_state_components and changes their value in accordance to transition rules defined here */
update_player_anim_state :: (world: *World) {
    for query : Query(Player, *Anim_State_Component, *Animation, Player_Commands, Velocity).{world = world} {
        velocities := query.velocity;
        anim_states := query.anim_state_component;
        anims := query.animation;
        player_commands := query.player_commands;

        for 0..query.count-1 {
            current_state := cast(Player_Anim_State) anim_states[it].state;

            // HACK: if the use_skill flag is set, set the local player to the attack state and then clear the flag. we definitely need better input handling...
            if player_commands[it].main_attack && get_component(world, query.entities[it], Local_Player) != null && current_state != .ATTACK {
                anim_states[it].state = xx Player_Anim_State.ATTACK_WIND_UP;
                transition_to_state(world, *anims[it], CHARACTER_ATTACK_WIND_UP_DEFINITION);
            }
            if current_state == {
                case .IDLE;
                    if !equals(length_squared(velocities[it]), 0) {
                        anim_states[it].state = xx Player_Anim_State.WALK;
                        transition_to_state(world, *anims[it], CHARACTER_WALK_DEFINITION);
                    }
                case .WALK;
                    if equals(length_squared(velocities[it]), 0) {
                        anim_states[it].state = xx Player_Anim_State.IDLE;
                        transition_to_state(world, *anims[it], CHARACTER_IDLE_DEFINITION);
                    }
                case .ATTACK_WIND_UP;
                    if anims[it].finished then {
                        anim_states[it].state = xx Player_Anim_State.ATTACK;
                        transition_to_state(world, *anims[it], CHARACTER_ATTACK_DEFINITION);
                    }
                case .ATTACK;
                    if anims[it].finished then {
                        if equals(length_squared(velocities[it]), 0) {
                            anim_states[it].state = xx Player_Anim_State.IDLE;
                            transition_to_state(world, *anims[it], CHARACTER_IDLE_DEFINITION);
                        } else {
                            anim_states[it].state = xx Player_Anim_State.WALK;
                            transition_to_state(world, *anims[it], CHARACTER_WALK_DEFINITION);
                        }
                    }
            }
        }
    }
} @System

on_player_anim_state_changed :: (world: *World) {
    for query : Query(Player, *Anim_State_Component, *Animation, Velocity).{world = world} {
        velocities := query.velocity;
        anim_states := query.anim_state_component;
        anims := query.animation;
        for 0..query.count-1 {
            current_state := cast(Player_Anim_State) anim_states[it].state;
            if current_state == .ATTACK {
                broadcast_event(world, EVENT_PLAYER_ATTACK);
            }
        }
    }
}

#scope_file

transition_to_state :: (world: *World, animation: *Animation, template: Animation_Definition){
    << animation = .{ template, 0, template.frame_duration, false };
    broadcast_event(world, EVENT_ON_PLAYER_ANIM_STATE_CHANGED);
}
