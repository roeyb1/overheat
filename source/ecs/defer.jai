Deferred_ECS_Op_Type :: enum {
    DESTROY;

    // nyi
    ADD;
    SET;
    MOVE;
}

Deferred_ECS_Operation :: struct {
    type: Deferred_ECS_Op_Type;
    entity: Entity;
}

process_deferred_operations :: (world: *World) {
    assert(world.should_defer == false);

    for world.deferred_ops {
        if it.type == {
            case .DESTROY;
                destroy_entity(world, it.entity);
            case;
                assert(false, "Not yet implemented");
        }
    }
    world.deferred_ops.count = 0;
}