/** A system that iterates over all anim_state_components and changes their value in accordance to transition rules defined here */
update_player_state :: (world: *World) {
    for query : Query(Player, *Anim_State_Component, *Animation,Velocity).{world = world} {
        velocities := query.velocity;
        anim_states := query.anim_state_component;
        anims := query.animation;

        for 0..query.count-1 {
            if anim_states[it].value == {
                case .IDLE;
                    if !equals(length_squared(velocities[it]), 0) {
                        anim_states[it].value = .WALK;
                        transition_to_state(*anims[it], CHARACTER_WALK_DEFINITION);
                    }
                    break;
                case .WALK;
                    if equals(length_squared(velocities[it]), 0) {
                        anim_states[it].value = .IDLE;
                        transition_to_state(*anims[it], CHARACTER_IDLE_DEFINITION);
                    }
                    break;
            }
        }
    }
}@System

/** A system that iterates over all animations and their corresponding sprites and switches the flip book index if the duration of the current frame has elapsed */
update_animation_index :: (world: *World) {
    for query : Query(*Animation, *Sprite, Direction).{world = world} {
        anims := query.animation;
        sprites := query.sprite;
        directions := query.direction;

        for 0..query.count-1 {
            anims[it].time_till_switch -= g_delta_time;

            if anims[it].time_till_switch <= 0.0 {
                anims[it].current_frame = cast(u32) ((anims[it].current_frame + 1) % anims[it].definition.frames.count);
                anims[it].time_till_switch = anims[it].definition.frame_duration;
            }

            directional_modifier: u32;
            directional_modifier = cast(u32)directions[it].value * sprites[it].sheet.width_in_sprites;
            sprites[it].index = anims[it].definition.frames[anims[it].current_frame] + directional_modifier;
        }
    }
} @System


transition_to_state :: (animation: *Animation, template: Animation_Definition){
    <<animation = .{template,0,template.frame_duration};
}
