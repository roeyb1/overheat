//not positive this file belongs here, should also be standarised unit of measurement as it is quite aribtrary to scale a sprite and a hitbox atm
Size :: struct @Component {
    multiplier: float; //value that defines how much a sprite will grow based on power
    value: float;
}

#if SERVER {
    scale_sprite_size :: (q: Query) {
        sprites := query_get(q, Sprite);
        sizes := query_get(q, Size);
        for 0..q.count-1 {
            size := sizes[it].value;
            sprites[it].scale = .{size,size};
        }
    } @System(OnUpdate) @Write(Sprite) @Read(Size)

    //TODO we need an actual scale modifier this is very arbitrary
    calculate_size :: (q: Query) {
        powers := query_get(q, Power);
        sizes := query_get(q, Size);
        for 0..q.count-1 {
            if powers[it].total > 0 {
                sizes[it].value = log(sizes[it].multiplier * powers[it].total);
            }
            if powers[it].total < 1{
                sizes[it].value = 0;
            }
        }
    } @System(OnUpdate) @Write(Size) @Read(Power)
}