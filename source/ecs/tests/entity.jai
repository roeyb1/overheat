/** Tests some operators on entity structs. */
entity_index_operators :: (ctx: *TestContext) {
    default_entity: Entity;
    test_expect_equals(default_entity, INVALID_ENTITY);

    e: Entity;
    e.index = 1;
    e.generation = 2;

    e_copy := e;

    test_expect_equals(e, e_copy);
} @UnitTest

/** Ensures that entity ids are distributed incrementally and are all unique. */
entity_index_unique :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    ENTITY_COUNT :: 10000;

    entities: [..] Entity;
    entities.allocator = temp;

    array_reserve(*entities, ENTITY_COUNT);

    for 0..ENTITY_COUNT-1 {
        array_add(*entities, entity_spawn(*w));
    }

    // indices are distributed incrementally, and we should only be in the first gen.
    for 1..ENTITY_COUNT-1 {
        test_expect_true(entities[it-1].index < entities[it].index);
        test_expect_equals(entities[it].generation, 0);
    }
} @UnitTest

/** Ensures that when entities are destroyed, we reuse their indices and increment the generation counter */
entity_index_reuse :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    ENTITY_COUNT :: 10000;

    entities: [..] Entity;
    entities.allocator = temp;
    array_reserve(*entities, ENTITY_COUNT);

    for 0..ENTITY_COUNT-1 {
        array_add(*entities, entity_spawn(*w));
    }

    for 0..ENTITY_COUNT-1 {
        entity_destroy(*w, entities[it]);
        test_expect_false(entity_is_valid(w, entities[it]));
    }

    new_entities: [..] Entity;
    new_entities.allocator = temp;
    array_reserve(*new_entities, ENTITY_COUNT);

    for 0..ENTITY_COUNT-1 {
        array_add(*new_entities, entity_spawn(*w));
    }
    
    for 0..ENTITY_COUNT-1 {
        // entity indices are pushed to a stack, LIFO so they get reused in inverse order.
        test_expect_equals(entities[ENTITY_COUNT - 1 - it].index, new_entities[it].index);
        test_expect_equals(entities[it].generation, 0);
        test_expect_equals(new_entities[it].generation, 1);
    }
} @UnitTest

entity_index_range :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);
    entity_set_range(*w, 10000, 0);

    e := entity_spawn(*w);
    test_expect_true(e.index >= 10000);

} @UnitTest

#import "Basic";