Self :: struct @Component {
    value: Entity;
}

add_self:: (world: *World, entity: Entity, caster: Entity) {
    << add_component(world, entity, Self) = .{caster};
}