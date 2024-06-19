Animation :: struct @Component {
    definition: Animation_Definition;
    current_frame: u32;
    time_till_switch: float;
    finished: bool = false;
}

Anim_State_Component :: struct @Component {
    state: u8;
}

/** A system that iterates over all animations and their corresponding sprites and switches the flip book index if the duration of the current frame has elapsed */
update_sprite_for_anim :: (world: *World) {
    for query : Query(*Animation, *Sprite, Direction).{world = world} {
        anims := query.animation;
        sprites := query.sprite;
        directions := query.direction;

        for 0..query.count-1 {
            anim_def := *anims[it].definition;
            anims[it].time_till_switch -= g_delta_time;

            if anims[it].time_till_switch <= 0.0 {
                // if the current animation should not 
                should_loop := anim_def.should_loop;
                is_last_frame := anims[it].current_frame == anim_def.frames.count-1;

                if should_loop && is_last_frame {
                    anims[it].current_frame = 0;
                } else if !is_last_frame {
                    anims[it].current_frame = cast(u32) (anims[it].current_frame + 1);
                    anims[it].time_till_switch = anim_def.frame_duration;
                } else {
                    anims[it].finished = true;
                }
            }

            directional_modifier: u32;
            directional_modifier = cast(u32)directions[it].value * sprites[it].sheet.width_in_sprites;
            sprites[it].index = anim_def.frames[anims[it].current_frame] + directional_modifier;
        }
    }
} @System @PreRender
