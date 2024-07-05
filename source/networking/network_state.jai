
Node_Field :: struct {
    field_id: Component_Type_ID;

    // component data stored in a byte buffer. @todo this is pretty innefficient since each node field will have it's own unique storage... good enough for now though I suppose
    data: ByteBuffer;
}


Node_State :: struct {
    fields: [..] Node_Field;
}

State_Snapshot :: struct {
    state: Table(Node_ID, Node_State, given_hash_function=node_id_hash, given_compare_function=compare_node_id);
}


generate_full_snapshot :: (world: *World) -> State_Snapshot {
    result: State_Snapshot;

    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    state := find_or_add(*result.state, networking_ids[it].id);

                    field := array_add(*state.fields);
                    field.field_id = #run component_type_id(%1);
                    field.data.only_note = "Sync";

                    byte_buffer_write(*field.data, *datas[it]);
                    field.data.cursor = 0;
                }
            }
        DONE

        sb: String_Builder;

        for ALL_COMPONENT_TYPES {
            has_sync_fields := false;
            ti := cast(*Type_Info_Struct) it;
            for * member : ti.members {
                if has_note(member, "Sync") {
                    has_sync_fields = true;
                    break;
                }
            }

            if !has_sync_fields then continue;

            sbprint(*sb, INSERT_STRING, it);
        }

        return builder_to_string(*sb);
    }

    return result;
}

free :: (snapshot: *State_Snapshot) {
    for snapshot.state {
        for field : it.fields {
            free(*field.data);
        }
    }
}