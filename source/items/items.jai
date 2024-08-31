Inventory :: struct @Pair { }
ContainedBy :: struct @Pair { }

Item :: struct @Tag { }
Equipped :: struct @Tag { }

// Equipment types:
Wand :: struct @Tag { }
Sword :: struct @Tag { }

Helmet :: struct @Tag { }
Boots :: struct @Tag { }
Gloves :: struct @Tag { }
Chestpiece :: struct @Tag { }

Ring :: struct @Tag { }
Belt :: struct @Tag { }

print_equipment :: (world: *World, entity: Entity) {
    inventory := ecs_get_target(world, entity, Inventory);
    assert(entity_is_valid(world, inventory));

    print("%'s equipment:\n", ecs_get(world, entity, Name).name);
    for q : iter_make_pair(world, ContainedBy, inventory, Item, Equipped, Name) {
        names := query_get(q, Name);
        for 0..q.count-1 {
            print("\t-%\n", names[it].name);
        }
    }
}

print_inventory :: (world: *World, entity: Entity) {
    inventory := ecs_get_target(world, entity, Inventory);
    assert(entity_is_valid(world, inventory));

    print("%'s inventory: \n", ecs_get(world, entity, Name).name);
    for q : iter_make_pair(world, ContainedBy, inventory, Item, Name) {
        names := query_get(q, Name);
        for 0..q.count-1 {
            print("\t- %\n", names[it].name);
        }
    }
}