Stabilize :: struct @Component {
    value: s64;
}

add_stabilize :: (world: *World, entity: Entity, value: s64) {
    add_component(world, entity, Stabilize);
    print("HEYA IM STABILIZE\n");
}