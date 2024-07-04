Child_Of :: struct @Component {
    parent: Entity;
}

entity_set_parent :: (world: *World, child: Entity, parent: Entity) {
    // the last bits of the unique_id will be the entities index.
    // Entity index is re-used, but because all children are killed whenever the parent is destroyed, there's no risk here
    child_of := cast(*Child_Of) add_component(world, child, pair_ctid(Child_Of, cast(u32) parent.index));

    child_of_c := add_component(world, child, Child_Of);
    child_of_c.parent = parent;
}

get_parent :: (world: *World, child: Entity) -> Entity {
    child_of := get_component(world, child, Child_Of);
    return child_of.parent;
}

spawn_child_entity :: (world: *World, parent: Entity, $component_types: ..Type) -> Entity {
    #insert -> string {
        sb: String_Builder;
        sbprint(*sb, "archetype :: Component_Type_ID.[#run component_type_id(Child_Of),");
        for component_types {
            sbprint(*sb, "#run component_type_id(%),", it);
        }
        sbprint(*sb, "];");
        return builder_to_string(*sb);
    }
    ctids: [..] Component_Type_ID;
    ctids.allocator = temp;
    array_copy(*ctids, archetype);
    array_add(*ctids, pair_ctid(Child_Of, cast(u32) parent.index));

    child := spawn_entity_with_ctids(world, ctids);

    child_of := get_component(world, child, Child_Of);
    child_of.parent = parent;

    return child;
}

make_children_iter :: (world: *World, entity: Entity, $component_types: ..Type) -> ECS_Iter {
    return make_pair_iter(world, Child_Of, cast(u32) entity.index, ..component_types);
}

pair_ctid :: ($type: Type, value: u32) -> Component_Type_ID {
    type_ctid :: #run component_type_id(type);
    
    result: Component_Type_ID = type_ctid;
    result.unique_id = ((cast(u64) type_ctid.unique_id) << 32) | (cast(u64) value);
    return result;
}

make_pair_iter :: (world: *World, $type: Type, value: u32, $component_types: ..Type) -> ECS_Iter {
    #insert -> string {
        sb: String_Builder;
        sbprint(*sb, "archetype :: Component_Type_ID.[");
        for component_types {
            sbprint(*sb, "#run component_type_id(%),", it);
        }
        sbprint(*sb, "];");
        return builder_to_string(*sb);
    }

    ctids: [..] Component_Type_ID;
    ctids.allocator = temp;
    array_copy(*ctids, archetype);
    array_add(*ctids, pair_ctid(type, value));
    quick_sort(ctids, (x) => x.unique_id);

    iter: ECS_Iter;
    iter.world = world;
    iter.archetype = ctids;
    iter.archetype_ids = find_or_create_cached_archetypes_for_ctids(*world.stage, iter.archetype);

    return iter;
}
