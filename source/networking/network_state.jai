Node_State :: struct {
    // maps component type id to a byte buffer containing the serialized component data
    fields: Table(u64, ByteBuffer);
}

State_Snapshot :: struct {
    state: Table(Node_ID, Node_State, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    // a list of all newly created entities and their component types
    // any synchronized state for those components is included in the state table
    new_nodes: Table(Node_ID, [..] u64, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    // for any nodes that
    removed_fields: Table(Node_ID, [..] u64, given_hash_function=node_id_hash, given_compare_function=compare_node_id);
    added_fields: Table(Node_ID, [..] u64, given_hash_function=node_id_hash, given_compare_function=compare_node_id);

    removed_nodes: [..] Node_ID;

    time: float;
    tick: u32;
}

State_Snapshot_Packet_Data :: struct {
    // we can't serialize tables yet, so we just transfer a list of pairs when serializing the state on the network

    State_Pair :: struct {
        node_id: Node_ID;

        Node_Field :: struct {
            field_id: u64; // component_type_id.unique_id

            data: ByteBuffer;
        }

        fields: [..] Node_Field;
    }

    Field_Pair :: struct {
        node_id: Node_ID;

        field_ids: [..] u64;
    }

    state_pairs: [..] State_Pair;
    added_field_pairs: [..] Field_Pair;
    removed_field_pairs: [..] Field_Pair;

    New_Pair :: struct {
        node_id: Node_ID;
        component_types: [..] u64;
    }

    newly_added: [..] New_Pair;
    removed: [..] Node_ID;

    time: float;
    tick: u32;
}

State_Snapshot_Packet :: struct {
    PACKET_TYPE :: PacketType.SNAPSHOT;
    using data: State_Snapshot_Packet_Data;
}

Player_State_Snapshot_Packet :: struct {
    PACKET_TYPE :: PacketType.PLAYER_DELTA;

    using data: State_Snapshot_Packet_Data;

    input: Player_Commands;
}


// any nodes that were newly created in the last simulation iter
added_nodes: [..] Node_ID;
// any nodes that were destroyed in the last simulation iter
removed_nodes: [..] Node_ID;

generate_full_snapshot :: (world: *World) -> State_Snapshot {
    result: State_Snapshot;
    result.time = xx seconds_since_init();
    result.tick = g_current_tick;

    // always send over component id list for every entity in the world if it's a full snapshot
    for entity_node_id_table {
        component_types_view := get_component_types(world, it);

        types: [..] u64;
        for component_types_view {
            array_add(*types, it.unique_id);
        }

        entry := table_add(*result.new_nodes, it_index, types);
    }

    #insert -> string {
        INSERT_STRING :: #string DONE 
            for q : make_iter(world, Networking_ID, %1) {
                datas := query_get(q, %1);
                networking_ids := query_get(q, Networking_ID);

                for 0..q.count-1 {
                    state := find_or_add(*result.state, networking_ids[it].id);

                    field := find_or_add(*state.fields, #run component_type_id(%1).unique_id);
                    field.only_note = "Sync";

                    byte_buffer_write(field, *datas[it]);
                    field.cursor = 0;
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
        for * it.fields {
            free(it);
        }
        deinit(*it.fields);
    }
    for snapshot.added_fields {
        fields := it;
        for it {
            array_free(fields);
        }
    }
    deinit(*snapshot.added_fields);
    for snapshot.removed_fields {
        fields := it;
        for it {
            array_free(fields);
        }
    }
    deinit(*snapshot.removed_fields);
    for snapshot.new_nodes {
        array_reset(*it);
    }
    deinit(*snapshot.state);
    deinit(*snapshot.new_nodes);
    array_reset(*snapshot.removed_nodes);
}

to_packet :: (snapshot: State_Snapshot) -> State_Snapshot_Packet_Data {
    result: State_Snapshot_Packet_Data;
    result.newly_added.allocator = temp;
    result.removed.allocator = temp;
    result.state_pairs.allocator = temp;
    result.added_field_pairs.allocator = temp;
    result.removed_field_pairs.allocator = temp;
    result.time = snapshot.time;
    result.tick = snapshot.tick;

    array_append(*result.removed, snapshot.removed_nodes);

    for snapshot.state {
        pair := array_add(*result.state_pairs);
        pair.node_id = it_index;

        for * it.fields {
            field := array_add(*pair.fields);
            field.field_id = it_index;
            field.data = copy(it);
        }
    }
    for snapshot.new_nodes {
        pair := array_add(*result.newly_added);
        pair.node_id = it_index;
        pair.component_types = it;
    }

    for snapshot.added_fields {
        pair := array_add(*result.added_field_pairs);
        pair.node_id = it_index;

        array_copy(*pair.field_ids, it);
    }
    for snapshot.removed_fields {
        pair := array_add(*result.removed_field_pairs);
        pair.node_id = it_index;

        array_copy(*pair.field_ids, it);
    }
    result.time = xx seconds_since_init();
    return result;
}

from_packet :: (packet: State_Snapshot_Packet_Data) -> State_Snapshot {
    result: State_Snapshot;
    result.time = packet.time;
    result.tick = packet.tick;

    array_append(*result.removed_nodes, packet.removed);

    for packet.state_pairs {
        new_state := table_add(*result.state, it.node_id, .{});
        // deep copy the state and all the fields, they were allocated from temp buffers
        for it.fields {
            new_data := copy(*it.data);
            new_field_data := table_add(*new_state.fields, it.field_id, new_data);
        }
    }
    for packet.newly_added {
        new_entry := table_add(*result.new_nodes, it.node_id, it.component_types);
    }

    for packet.added_field_pairs {
        fields: [..] u64;
        array_copy(*fields, it.field_ids);
        new_entry := table_add(*result.added_fields, it.node_id, fields);
    }
    for packet.removed_field_pairs {
        fields: [..] u64;
        array_copy(*fields, it.field_ids);
        new_entry := table_add(*result.removed_fields, it.node_id, fields);
    }

    return result;
}