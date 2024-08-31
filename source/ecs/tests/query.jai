basic_query :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    e := entity_spawn(*w, Component_A);

    arch_count := 0;
    iter_count := 0;
    for q : iter_make(*w, Component_A) {
        test_expect_not_equals(query_get(q, Component_A).data, null);
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }
    test_expect_equals(arch_count, 1);
    test_expect_equals(iter_count, 1);

    entity_spawn(*w, Component_B);
    entity_spawn(*w, Component_A, Component_B);

    arch_count = 0;
    iter_count = 0;
    for q : iter_make(*w, Component_A) {
        test_expect_not_equals(query_get(q, Component_A).data, null);
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }
    test_expect_equals(arch_count, 2);
    test_expect_equals(iter_count, 2);

    arch_count = 0;
    iter_count = 0;
    for q : iter_make(*w, Component_B) {
        test_expect_not_equals(query_get(q, Component_B).data, null);
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }
    test_expect_equals(arch_count, 2);
    test_expect_equals(iter_count, 2);

    arch_count = 0;
    iter_count = 0;
    for q : iter_make(*w, Component_A, Component_B) {
        test_expect_not_equals(query_get(q, Component_A).data, null);
        test_expect_not_equals(query_get(q, Component_B).data, null);
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }
    test_expect_equals(arch_count, 1);
    test_expect_equals(iter_count, 1);
} @UnitTest

Test_Pair :: struct @Pair { }

pair_query :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    e := entity_spawn(*w);
    e2 := entity_spawn(*w);

    ecs_add_pair(*w, e, Test_Pair, e2);

    iter_count := 0;
    for q : iter_make_pair(*w, Test_Pair, e2) {
        iter_count += 1;
    }
    test_expect_equals(iter_count, 1);

    iter_count = 0;
    for q : iter_make_pair(*w, Test_Pair, e) {
        iter_count += 1;
    }
    test_expect_equals(iter_count, 0);

    // add a new test_pair but with a different relation target
    ecs_add_pair(*w, e2, Test_Pair, e);

    // this uses EcsWildcard so it will match any (Test_Pair, *)
    iter_count = 0;
    arch_count := 0;
    for q : iter_make_uncached(*w, cid_pair(*w, Test_Pair, Ecs_Wildcard)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }
    test_expect_equals(arch_count, 2);
    test_expect_equals(iter_count, 2);
} @UnitTest

term_query_and :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    entity_spawn(*w, Component_A, Component_B);
    entity_spawn(*w, Component_A);
    entity_spawn(*w, Component_B);

    iter_count := 0;
    arch_count := 0;
    for q : iter_make(*w, ecs_iter_term(*w, Component_A, .AND), ecs_iter_term(*w, Component_B, .AND)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }

    test_expect_equals(arch_count, 1);
    test_expect_equals(iter_count, 1);
} @UnitTest

term_query_or :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    entity_spawn(*w, Component_A, Component_B);
    entity_spawn(*w, Component_A);
    entity_spawn(*w, Component_B);

    iter_count := 0;
    arch_count := 0;
    for q : iter_make(*w, ecs_iter_term(*w, Component_A, .OR), ecs_iter_term(*w, Component_B, .OR)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }

    test_expect_equals(arch_count, 3);
    test_expect_equals(iter_count, 3);
} @UnitTest

term_query_not :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    entity_spawn(*w, Component_A, Component_B);
    entity_spawn(*w, Component_A);
    entity_spawn(*w, Component_B);

    iter_count := 0;
    arch_count := 0;
    for q : iter_make(*w,
                        ecs_iter_term(*w, Component_A),
                        ecs_iter_term(*w, Component_B, .NOT)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }

    test_expect_equals(arch_count, 1);
    test_expect_equals(iter_count, 1);
} @UnitTest

term_query_and_plus_or :: (ctx: *TestContext) {
    w: World;

    ecs_world_init(*w);

    entity_spawn(*w, Component_A, Component_B);
    entity_spawn(*w, Component_A, Component_C);
    entity_spawn(*w, Component_A);
    entity_spawn(*w, Component_B);
    entity_spawn(*w, Component_C);

    iter_count := 0;
    arch_count := 0;
    // A && (B || C)
    for q : iter_make(*w,
                        ecs_iter_term(*w, Component_A), 
                        ecs_iter_term(*w, Component_B, .OR),
                        ecs_iter_term(*w, Component_C, .OR)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }

    test_expect_equals(arch_count, 2);
    test_expect_equals(iter_count, 2);

    iter_count = 0;
    arch_count = 0;
    // (A || B) && C
    for q : iter_make(*w,
                        ecs_iter_term(*w, Component_A, .OR),
                        ecs_iter_term(*w, Component_B, .OR),
                        ecs_iter_term(*w, Component_C)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }

    test_expect_equals(arch_count, 1);
    test_expect_equals(iter_count, 1);

    iter_count = 0;
    arch_count = 0;
    // (A || B || C)
    for q : iter_make(*w,
                        ecs_iter_term(*w, Component_A, .OR),
                        ecs_iter_term(*w, Component_B, .OR),
                        ecs_iter_term(*w, Component_C, .OR)) {
        arch_count += 1;
        for 0..q.count-1 {
            iter_count += 1;
        }
    }

    test_expect_equals(arch_count, 5);
    test_expect_equals(iter_count, 5);
} @UnitTest