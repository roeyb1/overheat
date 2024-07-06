Node_Field :: struct {
    field_id: u64; // component_type_id.unique_id

    // component data stored in a byte buffer. @todo this is pretty innefficient since each node field will have it's own unique storage... good enough for now though I suppose
    data: ByteBuffer;
}


Node_State :: struct {
    fields: [..] Node_Field;
}

State_Snapshot :: struct {
    state: Table(Node_ID, Node_State, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    // a list of all newly created entities and their component types
    // any synchronized state for those components is included in the state table
    new_nodes: Table(Node_ID, [..] u64, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    removed_nodes: [..] Node_ID;
}

State_Snapshot_Packet_Data :: struct {
    // we can't serialize tables yet, so we just transfer a list of pairs when serializing the state on the network

    State_Pair :: struct {
        node_id: Node_ID;
        state: Node_State;
    }

    pairs: [..] State_Pair;

    New_Pair :: struct {
        node_id: Node_ID;
        component_types: [..] u64;
    }

    newly_added: [..] New_Pair;
    removed: [..] Node_ID;

    sequence_number: s64;
}

State_Snapshot_Packet :: struct {
    PACKET_TYPE :: PacketType.SNAPSHOT;
    using data: State_Snapshot_Packet_Data;
}


// any nodes that were newly created in the last simulation iter
added_nodes: [..] Node_ID;
// any nodes that were destroyed in the last simulation iter
removed_nodes: [..] Node_ID;

generate_full_snapshot :: (world: *World, new_nodes: [] Node_ID) -> State_Snapshot {
    result: State_Snapshot;
    
    array_append(*result.removed_nodes, removed_nodes);

    for new_nodes {
        entity, found := table_find(*entity_node_id_table, it);
        assert(found, "The newly added node (%) doesn't exist in our entity_node_id_table. This is a bug!", it);

        component_types_view := get_component_types(world, entity);

        types: [..] u64;
        for component_types_view {
            array_add(*types, it.unique_id);
        }

        entry := table_add(*result.new_nodes, it, types);
    }

    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    state := find_or_add(*result.state, networking_ids[it].id);

                    field := array_add(*state.fields);
                    field.field_id = #run component_type_id(%1).unique_id;
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
        array_reset(*it.fields);
    }
    for snapshot.new_nodes {
        array_reset(*it);
    }
    deinit(*snapshot.state);
    deinit(*snapshot.new_nodes);
    array_reset(*snapshot.removed_nodes);
}

to_packet :: (snapshot: State_Snapshot) -> State_Snapshot_Packet {
    result: State_Snapshot_Packet;
    result.newly_added.allocator = temp;
    result.removed.allocator = temp;
    result.pairs.allocator = temp;

    array_append(*result.removed, snapshot.removed_nodes);

    for snapshot.state {
        pair := array_add(*result.pairs);
        pair.node_id = it_index;
        pair.state = it;
    }
    for snapshot.new_nodes {
        pair := array_add(*result.newly_added);
        pair.node_id = it_index;
        pair.component_types = it;
    }
    return result;
}

from_packet :: (packet: State_Snapshot_Packet) -> State_Snapshot {
    result: State_Snapshot;

    array_append(*result.removed_nodes, packet.removed);

    for packet.pairs {
        new_state := table_add(*result.state, it.node_id, .{});
        // deep copy the state and all the fields, they were allocated from temp buffers
        for field : it.state.fields {
            new_field := array_add(*new_state.fields);
            new_field.field_id = field.field_id;
            new_field.data = copy(*field.data);
        }
    }
    for packet.newly_added {
        new_entry := table_add(*result.new_nodes, it.node_id, it.component_types);
    }

    return result;
}