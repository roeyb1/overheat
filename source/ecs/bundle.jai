ecs_add_bundle :: (using world: *World, entity: Entity, bundle: $T) {
    assert(false);
}

ecs_add_bundle :: (using world: *World, entity: Entity, type: Type) {
    assert(false);
}

entity_spawn_bundle :: (using world: *World, bundle: $T) -> Entity {
    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);
        assert(has_note(ti, "Bundle"), "Attempted to use struct (%) as a bundle but it is not marked as such with a @Bundle note!", ti.name);

        sbprint(*sb, "TYPES :: Type.[");
        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "%, ", member_type_info.name);
                } else {
                    log_warning("Member (%) of bundle (%) does not have a @Component tag? It will not be added to the entity, was this intentional?", member_type_info.name, ti.name);
                }
            }
        }
        sbprint(*sb, "];");

        return builder_to_string(*sb);
    }

    entity := entity_spawn(world, ..TYPES, broadcast=false);

    #insert -> string {
        sb: String_Builder;

        ti :: cast(*Type_Info_Struct) type_info(T);

        for ti.members {
            // components can only be structs
            if it.type.type == .STRUCT {
                member_type_info := cast(*Type_Info_Struct) it.type;
                if has_note(member_type_info, "Component") {
                    sbprint(*sb, "ecs_get(world, entity, %).* = bundle.%;\n", member_type_info.name, it.name);
                }
            }
        }

        return builder_to_string(*sb);
    }

    for TYPES {
        event_broadcast(world, cid_pair(world, EcsOnAdd, cid_get(world, it)), entity);
    }

    return entity;
}

entity_spawn_bundle :: (using world: *World, type: Type) -> Entity {
    assert(false);
    return INVALID_ENTITY;
}