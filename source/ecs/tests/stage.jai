Component_A :: struct @Component {
    a: u32;
}

Component_B :: struct @Component {
    b: u32;
}

/** Test that adding a component to an entity moves it to a new archetype. Removing it moves it back to the same one. */
moving_archetypes :: (ctx: *TestContext) {
    s: Stage;

    e := add_entity(*s, .[#run component_type_id(Component_A)]);

    record := table_find_pointer(*s.entity_records, e.raw);
    test_assert_not_equals(record, null);

    archetype_id := record.archetype_id;

    archetype := *s.archetypes[record.archetype_id];

    test_expect_equals(archetype.id, record.archetype_id);

    add_component(*s, e, #run component_type_id(Component_B));

    test_expect_not_equals(record.archetype_id, archetype_id);

    remove_component(*s, e, #run component_type_id(Component_B));
    test_expect_equals(record.archetype_id, archetype_id);
} @UnitTest


deferred_entity_spawn :: (ctx: *TestContext) {
    w: World;
    s := *w.stage;
    ds := *w.deferred_stage;

    w.should_defer = true;

    e := spawn_entity(*w, Component_A);
    c := get_component(*w, e, Component_A);
    c.a = 10;

    // To keep entity ids consistent, we always add a new entity to the main stage too and use that entity id to identify the deferred entity
    test_expect_equals(s.entities.count, 1);
    archetype := find_archetype_for_entity(s, e);
    test_expect_equals(archetype.type_ids.count, 0);

    test_expect_equals(ds.entities.count, 1);

    w.should_defer = false;

    process_deferred_operations(*w);

    new_archetype := find_archetype_for_entity(s, e);
    test_expect_not_equals(new_archetype, archetype);
    test_expect_equals(new_archetype.type_ids.count, 1);

    moved_c := get_component(*w, e, Component_A);
    test_expect_equals(moved_c.a, 10);
} @UnitTest

deferred_component_add :: (ctx: *TestContext) {
    w: World;
    s := *w.stage;
    ds := *w.deferred_stage;

    e := spawn_entity(*w,);

    w.should_defer = true;

    c := add_component(*w, e, Component_A);
    c.a = 10;

    test_expect_equals(s.entities.count, 1);
    archetype := find_archetype_for_entity(s, e);
    test_expect_equals(archetype.type_ids.count, 0);

    w.should_defer = false;

    process_deferred_operations(*w);

    new_archetype := find_archetype_for_entity(s, e);
    test_expect_not_equals(new_archetype, archetype);
    test_expect_equals(new_archetype.type_ids.count, 1);

    moved_c := get_component(*w, e, Component_A);
    test_expect_equals(moved_c.a, 10);
} @UnitTest

deferred_component_remove :: (ctx: *TestContext) {
    w: World;
    s := *w.stage;
    ds := *w.deferred_stage;

    e := spawn_entity(*w, Component_A);

    w.should_defer = true;

    remove_component(*w, e, Component_A);

    archetype := find_archetype_for_entity(s, e);

    // archetype doesn't change until we process deferred.
    test_expect_equals(archetype.type_ids.count, 1);
    test_expect_not_equals(get_component(*w, e, Component_A), null);

    w.should_defer = false;

    process_deferred_operations(*w);

    new_archetype := find_archetype_for_entity(s, e);
    test_expect_not_equals(new_archetype, archetype);
    test_expect_equals(new_archetype.type_ids.count, 0);

    moved_c := get_component(*w, e, Component_A);
    test_expect_equals(moved_c, null);
} @UnitTest