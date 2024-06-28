Child_Of :: struct @Component {}

entity_set_parent :: (world: *World, child: Entity, parent: Entity) {
    // the last bits of the unique_id will be the entities index.
    // Entity index is re-used, but because all children are killed whenever the parent is destroyed, there's no risk here
    add_component(world, child, pair_ctid(Child_Of, cast(u32) parent.index));
}

spawn_child_entity :: (world: *World, parent: Entity, $component_types: ..Type) -> Entity {
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
    array_add(*ctids, pair_ctid(Child_Of, cast(u32) parent.index));

    return _spawn_entity(world, ctids);
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
