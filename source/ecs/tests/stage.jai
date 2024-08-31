Component_A :: struct @Component {
    a: u32;
}

Component_B :: struct @Component {
    b: u32;
}

Component_C :: struct @Component {
    b: u32;
}

/** Test that adding a component to an entity moves it to a new archetype. Removing it moves it back to the same one. */
moving_archetypes :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    s := *w.stage;

    e := entity_spawn(*w, Component_A);

    record := table_find_pointer(*s.entity_records, e.raw);
    test_assert_not_equals(record, null);

    archetype_id := record.archetype_id;

    archetype := *s.archetypes[record.archetype_id];

    test_expect_equals(archetype.id, record.archetype_id);

    ecs_add(*w, e, Component_B);

    test_expect_not_equals(record.archetype_id, archetype_id);

    ecs_remove(*w, e, Component_B);
    test_expect_equals(record.archetype_id, archetype_id);
} @UnitTest


deferred_entity_spawn :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    s := *w.stage;
    ds := *w.deferred_stage;

    w.is_deferring = true;

    e := entity_spawn(*w, Component_A);
    c := ecs_get(*w, e, Component_A);
    c.a = 10;

    // To keep entity ids consistent, we always add a new entity to the main stage too and use that entity id to identify the deferred entity
    test_expect_true(entity_is_alive(s, e));
    archetype := entity_archetype_get(s, e);
    test_expect_equals(archetype.type_ids.count, 0);

    test_expect_true(entity_is_alive(ds, e));

    w.is_deferring = false;

    process_deferred_operations(*w);

    new_archetype := entity_archetype_get(s, e);
    test_expect_not_equals(new_archetype, archetype);
    test_expect_equals(new_archetype.type_ids.count, 1);

    moved_c := ecs_get(*w, e, Component_A);
    test_expect_equals(moved_c.a, 10);
} @UnitTest

deferred_component_add :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    s := *w.stage;
    ds := *w.deferred_stage;

    e := entity_spawn(*w);

    w.is_deferring = true;

    c := ecs_add(*w, e, Component_A);
    c.a = 10;

    test_expect_true(entity_is_alive(s, e));
    archetype := entity_archetype_get(s, e);
    test_expect_equals(archetype.type_ids.count, 0);

    w.is_deferring = false;

    process_deferred_operations(*w);

    new_archetype := entity_archetype_get(s, e);
    test_expect_not_equals(new_archetype, archetype);
    test_expect_equals(new_archetype.type_ids.count, 1);

    moved_c := ecs_get(*w, e, Component_A);
    test_expect_equals(moved_c.a, 10);
} @UnitTest

deferred_component_remove :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    s := *w.stage;
    ds := *w.deferred_stage;

    e := entity_spawn(*w, Component_A);

    w.is_deferring = true;

    ecs_remove(*w, e, Component_A);

    archetype := entity_archetype_get(s, e);

    // archetype doesn't change until we process deferred.
    test_expect_equals(archetype.type_ids.count, 1);
    test_expect_not_equals(ecs_get(*w, e, Component_A), null);

    w.is_deferring = false;

    process_deferred_operations(*w);

    new_archetype := entity_archetype_get(s, e);
    test_expect_not_equals(new_archetype, archetype);
    test_expect_equals(new_archetype.type_ids.count, 0);

    moved_c := ecs_get(*w, e, Component_A);
    test_expect_equals(moved_c, null);
} @UnitTest