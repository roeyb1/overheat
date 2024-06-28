Child_Of :: struct @Component {}

child_of_id :: (parent: Entity) -> Component_Type_ID {
    child_of_ctid :: #run component_type_id(Child_Of);

    result: Component_Type_ID = child_of_ctid;
    // the last bits of the unique_id will be the entities index.
    // Entity index is re-used, but because all children are killed whenever the parent is destroyed, there's no risk here
    result.unique_id = ((cast(u64) child_of_ctid.unique_id) << 32) | (cast(u64) (cast(u32) parent.index));
    return result;
}

set_parent :: (world: *World, child: Entity, parent: Entity) {
    add_component(world, child, child_of_id(parent));
}

make_children_iter :: (world: *World, parent: Entity, $component_types: ..Type) -> ECS_Iter {
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
    array_add(*ctids, child_of_id(parent));
    quick_sort(ctids, (x) => x.unique_id);

    iter: ECS_Iter;
    iter.world = world;
    iter.archetype = ctids;
    iter.archetype_ids = find_or_create_cached_archetypes_for_ctids(*world.stage, iter.archetype);

    return iter;
}
