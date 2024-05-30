Directions :: enum u32 {
    Down      :: 0;
    Left      :: 1;
    Right     :: 2;
    Up        :: 3;
}

Direction :: struct{
    using #as value: Directions;
}

/** swaps the current indecies played on the spritesheet every frame in a loop, the directional modifier represents the direction the sprite faces and is the y index in the spritesheet */
update_directions:: (world: *World) {
    for Query(*Direction,Velocity).{world = world} {
        if(it.velocity.value.y < 0){
            it.direction.value = Directions.Down;
        } else if (it.velocity.value.y > 0) {
            it.direction.value = Directions.Up;
        } else if (it.velocity.value.x < 0) {
            it.direction.value = Directions.Left;
        } else if (it.velocity.value.x > 0) {
            it.direction.value = Directions.Right;
        } 
    }
} @System