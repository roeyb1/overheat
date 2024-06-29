Haste :: struct @Component {
    value: s64;
}

add_haste :: (world: *World, entity: Entity, value: s64, target_entity: Entity) {
    print("%\n",target_entity);
    modifier := spawn_child_entity(world, target_entity, Haste, Duration);
    add_component(world, modifier, Move_Speed_Modifier, .{multipliers = 10. });
    << get_component (world, modifier, Duration) = .{2};

    
    print("HEYA IM HASTE\n");
}