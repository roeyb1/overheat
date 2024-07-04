Haste :: struct @Component {
    speed_multiplier: float;
}

add_haste :: (world: *World, entity: Entity, value: float, target_entity: Entity) {
    modifier := spawn_child_entity(world, target_entity, Haste, Duration, Name, Effect_Identifier, Multiplier);
    << get_component (world, modifier, Effect_Identifier) = .{.HASTE};
    << get_component (world, modifier, Name) = .{"haste"};
    << get_component (world, modifier, Duration) = .{5}; // @todo: configurable duration
    << get_component (world, modifier, Haste) = .{ value };
    add_component(world, modifier, Move_Speed_Modifier, .{multipliers = value});
}