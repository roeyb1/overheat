/** changes a players state in accordance with transition paths unique to each state. those state will define what animation indecies the player sprite sheet will cycle through*/
update_player_state :: (world: *World) {
    for Query(Player,*Anim_State_Component,*Animation,Velocity).{world = world} {
        if it.anim_state_component.value == {
            case .CHARACTER_IDLE_TEMPLATE;
                if (length_squared(it.velocity.value) != 0) {
                    it.anim_state_component.value = .CHARACTER_WALK_TEMPLATEING;
                    transition_to_state(it.animation,CHARACTER_WALK_TEMPLATE);
                }
                break;
            case .CHARACTER_WALK_TEMPLATEING;
                if (length_squared(it.velocity.value) == 0) {
                    it.anim_state_component.value = .CHARACTER_IDLE_TEMPLATE;
                    transition_to_state(it.animation,CHARACTER_IDLE_TEMPLATE);
                }
                break;
        }
    }
}@System

/** swaps the current indecies played on the spritesheet every frame in a loop, the directional modifier represents the direction the sprite faces and is the y index in the spritesheet */
update_animation_index :: (world: *World) {
    for Query(*Animation,*Sprite,Direction).{world = world} {
        it.animation.time_till_switch -= g_delta_time;

        if it.animation.time_till_switch <= 0.0 {
            it.animation.current_frame = cast(u32) ((it.animation.current_frame + 1) % it.animation.animation_definition.animation_frames.count);
            it.animation.time_till_switch = it.animation.animation_definition.frame_duration;
        }

        directional_modifier: u32;
        directional_modifier = cast(u32)it.direction.value * it.sprite.sheet.width_in_sprites;
        it.sprite.index = it.animation.animation_definition.animation_frames[it.animation.current_frame] + directional_modifier;
    }
} @System

/** called when a state is to be called, initialises it bases on the animation definition and sets it's index to 0 in the loop*/
transition_to_state :: (animation: *Animation, template: Animation_Definition){
    <<animation = .{template,0,template.frame_duration};
}
