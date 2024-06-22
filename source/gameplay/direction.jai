Directions :: enum u32 {
    Down      :: 0;
    Left      :: 1;
    Right     :: 2;
    Up        :: 3;
}

Direction :: struct @Component {
    using #as value: Directions;
}

update_directions:: (q: Query) {
    velocities := query_get(q, Velocity);
    directions := query_get(q, Direction);

    for 0..q.count-1 {
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
} @System(PostUpdate) @Write(Direction) @Read(Velocity)