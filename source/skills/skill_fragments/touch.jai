Touch :: struct @Component {
    value: s64;
}


add_touch :: (world: *World, entity: Entity, value: s64,casting_entity: Entity) {

    add_component(world, entity, Touch,);
    print("HEYA IM Touch\n");
}

