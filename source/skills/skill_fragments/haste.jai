Haste :: struct @Component {
    power: float;
}

Haste_Bundle :: struct @Bundle {
    duration: Duration;
    effect_identifier: Effect_Identifier;
    multiplier: Multiplier;
    move_speed_modifier: Move_Speed_Modifier;
}

BASE_HASTE :: 0.01;

add_haste :: (world: *World, entity: Entity) {
    add_component(world, entity, Haste);
    if (get_component(world, entity, Dividends)) {
        array_add(*get_component(world, entity, Dividends).value, .Haste);
    }
}


power_up_haste :: (q: Query) {
    dividends := query_get(q, Dividends);
    shares: u64;
    powers := query_get(q, Power);
    hastes := query_get(q, Haste);

    for 0..q.count-1 {
        for dividends[it].value {
            if it == Skill_Fragment_Types.Haste {
                shares += 1;
            }
        }
        hastes[it].power += (powers[it].incoming / dividends[it].value.count) * shares;
        log("hello %",dividends[it].value.count);
    }
} @System(PreUpdate) @Write(Haste) @Read(Powering_Up,Dividends,Power)


haste_self :: (q: Query) {
    hastes := query_get(q, Haste);
    selfs := query_get(q, Self);
    for 0..q.count-1 {
        modifier := spawn_child_entity(q.world, selfs[it].value);
        output := BASE_HASTE * hastes[it].power + 1;
        add_components_from_bundle(q.world, modifier, Haste_Bundle.{
            duration = .{FIXED_TIMESTEP},
            effect_identifier = .{.HASTE},
            move_speed_modifier = .{multipliers = output}
        });
        log("hello %",hastes[it].power);
    }
} @System(OnUpdate) @Write(Haste) @Read(Charged_Spell,Self)

/*
add_haste :: (world: *World, entity: Entity, value: float, target_entity: Entity) {
    modifier := spawn_child_entity(world, target_entity, Haste, Duration, Name, Effect_Identifier, Multiplier);
    << get_component (world, modifier, Effect_Identifier) = .{.HASTE};
    << get_component (world, modifier, Name) = .{"haste"};
    << get_component (world, modifier, Duration) = .{5}; // @todo: configurable duration
    << get_component (world, modifier, Haste) = .{ value };
    add_component(world, modifier, Move_Speed_Modifier, .{multipliers = value});
}*/


/*
//apply strait to proj movespeed then remove the haste component
haste_projectile :: (q: Query) {
    projectiles := query_get(q, Projectile);
    movement_speeds := query_get(q, Move_Speed);
    velocities := query_get(q, Velocity);
    for 0..q.count-1 {
        velocities[it].value = projectiles[it].direction * movement_speeds[it].value;
    }
} @System(PreUpdate) @Write(Velocity) @Read(Projectile,Haste)

//spawn a child of the target_entity that will carry the buff then remove the haste tag
haste_self :: (q: Query) {

} @System(OnUpdate) @Write(Velocity) @Read(Self,Haste)*/