#scope_export 

g_local_player: *Player;

movement_input: Vector2;

Player :: struct {
    #as using entity: *Entity;

    networking_id: u64;

    sprite: Sprite;

    /** Stores all player attributes. Health, speed, etc. */
    attribs: Attribute_Component;
}

init_player :: (networking_id: u64, position: Vector2) -> *Player {
    player := make_entity(*g_world, Player, tprint("Player_%",networking_id));
    player.networking_id = networking_id;
    player.position = position;

    sprite := ifx g_client.local_client_id == networking_id {
        g_local_player_sprite;
    } else {
        g_player_sprite;
    }

    player.sprite = Sprite.{sprite, .{1.5, 1.5}, 0, 1};


    // Initialize the default base player attributes:
    player.attribs.base[Attribute.MAX_HEALTH] = 100.;
    player.attribs.base[Attribute.HEALTH] = 100.;
    player.attribs.base[Attribute.SPEED] = 10.;

    return player;
}

// Update the local player controller, returns true if the player has made an input this frame
update_player_controller :: () -> bool {
    move_len := length(movement_input);
    // Normalize the input vector to prevent diagonal movement being faster than horizontal
    if move_len > 1 {
        movement_input = unit_vector(movement_input);
        move_len = 1.;
    }

    g_local_player.velocity = movement_input * get_current_attribute_value(.SPEED, *g_local_player.attribs);

    movement_input = .{0, 0};
    
    return move_len != 0;
}

MovePlayerUp :: (key_state: Key_Current_State) {
    movement_input.y += 1;
} @RegisterInputAction

MovePlayerDown :: (key_state: Key_Current_State) {
    movement_input.y -= 1;
} @RegisterInputAction

MovePlayerLeft :: (key_state: Key_Current_State) {
    movement_input.x -= 1;
} @RegisterInputAction

MovePlayerRight :: (key_state: Key_Current_State) {
    movement_input.x += 1;
} @RegisterInputAction

#import "Math";
#import "Input";