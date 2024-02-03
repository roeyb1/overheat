#scope_export 

Player :: struct {
    position: Vector2;
    velocity: Vector2;
}

g_local_player: Player;

movement_input: Vector2;

MOVE_SPEED :: 500;

update_player_controller :: () {
    // Normalize the input vector to prevent diagonal movement being faster than horizontal
    if length(movement_input) > 1 {
        movement_input = unit_vector(movement_input);
    }

    g_local_player.velocity = movement_input * MOVE_SPEED;

    movement_input = .{0, 0};
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