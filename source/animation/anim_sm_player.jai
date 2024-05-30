/** A system that iterates over all anim_state_components and changes their value in accordance to transition rules defined here */
update_player_state :: (world: *World) {
    for Query(Player, *Anim_State_Component, *Animation,Velocity).{world = world} {
        if it.anim_state_component.value == {
            case .CHARACTER_IDLE_DEFINITION;
                if (length_squared(it.velocity.value) != 0) {
                    it.anim_state_component.value = .CHARACTER_WALK_DEFINITION;
                    transition_to_state(it.animation,CHARACTER_WALK_DEFINITION);
                }
                break;
            case .CHARACTER_WALK_DEFINITION;
                if (length_squared(it.velocity.value) == 0) {
                    it.anim_state_component.value = .CHARACTER_IDLE_DEFINITION;
                    transition_to_state(it.animation, CHARACTER_IDLE_DEFINITION);
                }
                break;
        }
    }
}@System

/** A system that iterates over all animations and their corresponding sprites and switches the flip book index if the duration of the current frame has elapsed */
update_animation_index :: (world: *World) {
    for Query(*Animation, *Sprite,Direction).{world = world} {
        it.animation.time_till_switch -= g_delta_time;

        if it.animation.time_till_switch <= 0.0 {
            it.animation.current_frame = cast(u32) ((it.animation.current_frame + 1) % it.animation.definition.frames.count);
            it.animation.time_till_switch = it.animation.definition.frame_duration;
        }

        directional_modifier: u32;
        directional_modifier = cast(u32)it.direction.value * it.sprite.sheet.width_in_sprites;
        it.sprite.index = it.animation.definition.frames[it.animation.current_frame] + directional_modifier;
    }
} @System


transition_to_state :: (animation: *Animation, template: Animation_Definition){
    <<animation = .{template,0,template.frame_duration};
}
