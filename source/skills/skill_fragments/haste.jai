Haste :: struct @Component {
    value: s64;
}

add_haste :: (world: *World, entity: Entity, value: s64, target_entity: Entity) {
    print("%\n",target_entity);
    modifier := spawn_child_entity(world, target_entity, Haste, Duration, Name, Effect_Identifier, Multiplier);
    << get_component (world, modifier, Effect_Identifier) = .{.HASTE};
    << get_component (world, modifier, Name) = .{"stalin"};
    << get_component (world, modifier, Duration) = .{5};
    add_component(world, modifier, Move_Speed_Modifier, .{multipliers = 10.});
    print("HEYA IM HASTE\n");
}