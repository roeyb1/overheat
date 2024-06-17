Directions :: enum u32 {
    Down      :: 0;
    Left      :: 1;
    Right     :: 2;
    Up        :: 3;
}

Direction :: struct{
    using #as value: Directions;
}

update_directions:: (world: *World) {
    for query : Query(*Direction, Velocity).{world = world} {
        velocities := query.velocity;
        directions := query.direction;
        for 0..query.count-1 {
            if velocities[it].y < 0 {
                directions[it].value = Directions.Down;
            } else if velocities[it].y > 0 {
                directions[it].value = Directions.Up;
            } else if velocities[it].x < 0 {
                directions[it].value = Directions.Left;
            } else if velocities[it].x > 0 {
                directions[it].value = Directions.Right;
            } 
        }
    }
} @System @PostUpdate