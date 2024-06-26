Animation :: struct @Component {
    definition: Animation_Definition;
    current_index: u32;
    time_till_switch: float;
    finished: bool = false;
}

/** A system that iterates over all animations and their corresponding sprites and switches the flip book index if the duration of the current frame has elapsed */
update_animation_index :: (q: Query) {
    anims := query_get(q, Animation);

    for 0..q.count-1 {
        anim_def := *anims[it].definition;
        anims[it].time_till_switch -= g_delta_time;

        if anims[it].time_till_switch <= 0.0 {
            should_loop := test_flag_bit(anim_def.flags, .LOOP);
            is_last_frame := anims[it].current_index == anim_def.frames.count-1;

            if should_loop && is_last_frame {
                anims[it].current_index = 0;
            } else if !is_last_frame {
                anims[it].current_index = cast(u32) (anims[it].current_index + 1);
                anims[it].time_till_switch = anim_def.frame_duration;
            } else {
                anims[it].finished = true;
            }
        }
    }
} @System(PreRender) @Write(Animation) @Read()


update_sprite_anim :: (q: Query) {
    anims := query_get(q, Animation);
    sprites := query_get(q, Sprite);
    directions := query_get_opt(q, Direction);
    velocities := query_get_opt(q, Velocity);

    for 0..q.count-1 {
        anim_def := *anims[it].definition;

        if directions {
            if anim_def.directional_mode == {
                case .UNIQUE_SPRITES;
                    direction_offset := cast(u32)directions[it].value * sprites[it].sheet.width_in_sprites;
                    sprites[it].index = anim_def.frames[anims[it].current_index] + direction_offset;
                case .FLIP_X;
                    if velocities {
                        sprites[it].flip = ifx velocities[it].x < 0 then .FLIP_X else .NONE;
                    }
                    sprites[it].index = anim_def.frames[anims[it].current_index];
            }
        } else {
            sprites[it].index = anim_def.frames[anims[it].current_index];
        }
    }
} @System(PreRender) @Write(Sprite) @Read(Animation) @OptionalRead(Direction,Velocity)
