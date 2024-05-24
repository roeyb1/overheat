update_player_state :: (world: *World) {
    for Query(Player,*Anim_State,*Animation).{world = world} {
        using it.anim_state;
        if current_state == {
            case .IDLE;
                vel := get_component(*g_world, it_index, Velocity);
                if (length(vel) != 0) {
                    current_state = .WALKING;
                    to_state(it.animation,WALK);
                }
                break;
            case .WALKING;
                vel := get_component(*g_world, it_index, Velocity);
                if (length(vel) == 0) {
                    current_state = .IDLE;
                    to_state(it.animation,IDLE);
                }
                break;
        }
    }
} @System

update_animation_index :: (world: *World) {
    for Query(*Animation,*Sprite,Player_Controller).{world = world} {
        using it.animation;
        time_till_switch -= g_delta_time;

        if time_till_switch <= 0.0 {
            if current_frame < animation_template.animation_frames.count-1 {
                current_frame += 1;
            }
            else current_frame = 0;
            time_till_switch = animation_template.frame_duration;
        }

        directional_modifier: u32;
        if(it.player_controller.move_velocity.y < 0){
            directional_modifier = 0;
        } else if (it.player_controller.move_velocity.y > 0) {
            directional_modifier = 3*it.sprite.sheet.width_in_sprites;
        } else if (it.player_controller.move_velocity.x < 0) {
            directional_modifier = 1*it.sprite.sheet.width_in_sprites;
        } else if (it.player_controller.move_velocity.x > 0) {
            directional_modifier = 2*it.sprite.sheet.width_in_sprites;
        } 

        it.sprite.index = animation_template.animation_frames[current_frame] + directional_modifier;
    }
} @System


to_state :: (animation: *Animation, template: Animation_Template){
    <<animation = .{template,0,template.frame_duration};
}
