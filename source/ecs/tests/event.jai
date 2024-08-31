on_add :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    add_event_count = 0;

    e := entity_spawn(*w, Component_A);

    test_expect_equals(add_event_count, 1);

    remove_event_count = 0;
    entity_destroy(*w, e);
    test_expect_equals(remove_event_count, 1);

    e = entity_spawn(*w);
    ecs_add(*w, e, Component_A);

    test_expect_equals(add_event_count, 2);
    ecs_remove(*w, e, Component_A);

    test_expect_equals(remove_event_count, 2);
} @UnitTest

test_add_event :: (world: *World, entity: Entity) {
    add_event_count += 1;
} @Event(EcsOnAdd,Component_A)

test_add_event_should_not_fire :: (world: *World, entity: Entity) {
    add_event_count += 1;
} @Event(EcsOnAdd,Component_B)

test_remove_event :: (world: *World, entity: Entity) {
    remove_event_count += 1;
} @Event(EcsOnRemove,Component_A)

#scope_file

add_event_count := 0;
remove_event_count := 0;