#scope_export 

g_local_player: *Player;

movement_input: Vector2;

MOVE_SPEED :: 16;

// Update the local player controller, returns true if the player has made an input this frame
update_player_controller :: () -> bool {
    move_len := length(movement_input);
    // Normalize the input vector to prevent diagonal movement being faster than horizontal
    if move_len > 1 {
        movement_input = unit_vector(movement_input);
        move_len = 1.;
    }

    g_local_player.velocity = movement_input * g_local_player.stats_component.stats[StatType.MOVEMENT_SPEED].total;

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