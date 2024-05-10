#scope_export

TestContext :: struct {
    success: bool = true;
}

UnitTest :: struct {
    name: string;
    func: #type (ctx: *TestContext);
}

g_unit_tests: [..] UnitTest;

execute_unit_tests :: () -> bool {
    register_unit_tests();

    push_allocator(temp);

    print("[----] Executing % unit tests.\n", g_unit_tests.count);

    failures := 0;
    for g_unit_tests {
        ctx: TestContext;
        it.func(*ctx);

        if ctx.success {
            print("[ OK ] % passed.\n", it.name);
        } else {
            print("[FAIL] % failed.\n", it.name);
            failures += 1;
        }
    }

    if failures > 0 {
        print("[FAIL] ");
    } else {
        print("[PASS] ");
    }
    print("Test execution completed with % failures\n", failures);

    reset_temporary_storage();

    return failures == 0;
}

test_expect_equals :: (expected: $Tx, actual: $Ty, loc := #caller_location) #expand {
    if expected != actual {
        print("\t\t%:%:% failure. \n\t\tExpected %\n \t\tActual %\n", path_filename(loc.fully_pathed_filename), loc.line_number, loc.character_number, expected, actual);
        `ctx.success = false;
    }
}

test_expect_not_equals :: (expected: $Tx, actual: $Ty, loc := #caller_location) #expand {
    if expected == actual {
        print("\t\t%:%:% failure. \n\t\tExpected %\n \t\tActual %\n", path_filename(loc.fully_pathed_filename), loc.line_number, loc.character_number, expected, actual);
        `ctx.success = false;
    }
}

test_assert_equals :: (expected: $Tx, actual: $Ty, loc := #caller_location) #expand {
    if expected != actual {
        print("\t\t%:%:% failure. \n\t\tExpected %\n \t\tActual %\n", path_filename(loc.fully_pathed_filename), loc.line_number, loc.character_number, expected, actual);
        `ctx.success = false;
        `return;
    }
}

test_assert_not_equals :: (expected: $Tx, actual: $Ty, loc := #caller_location) #expand {
    if expected == actual {
        print("\t\t%:%:% failure. \n\t\tExpected %\n \t\tActual %\n", path_filename(loc.fully_pathed_filename), loc.line_number, loc.character_number, expected, actual);
        `ctx.success = false;
        `return;
    }
}
