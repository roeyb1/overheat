on_add :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    event_count = 0;

    e := entity_spawn(*w, Component_A);

    test_expect_equals(event_count, 1);
} @UnitTest

test_event :: (world: *World, entity: Entity) {
    event_count += 1;
} @Event(EcsOnAdd,Component_A)

#scope_file

event_count: s64 = 0;
