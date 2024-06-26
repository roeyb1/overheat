Directions :: enum u32 {
    DOWN      :: 0;
    LEFT      :: 1;
    RIGHT     :: 2;
    UP        :: 3;
}

Direction :: struct @Component {
    using #as value: Directions;
}

update_directions:: (q: Query) {
    velocities := query_get(q, Velocity);
    directions := query_get(q, Direction);

    for 0..q.count-1 {
        if velocities[it].y < 0 {
            directions[it].value = Directions.DOWN;
        } else if velocities[it].y > 0 {
            directions[it].value = Directions.UP;
        } else if velocities[it].x < 0 {
            directions[it].value = Directions.LEFT;
        } else if velocities[it].x > 0 {
            directions[it].value = Directions.RIGHT;
        } 
    }
} @System(PostUpdate) @Write(Direction) @Read(Velocity)