Self :: struct @Component {
    direction: Vector2;
}

add_self :: (world: *World, entity: Entity, value: s64, casting_entity: Entity) {

    add_component(world, entity, Self);
}

